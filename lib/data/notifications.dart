/// Thin platform wrapper around `flutter_local_notifications` for the
/// reminders feature (U1/U2/U12): init + tap callback, the platform
/// notification permission (Android 13+ runtime permission / iOS
/// authorization), and a cancel-all-then-reschedule sync of planned reminders.
///
/// Everything *about* reminders (what is due, when, with which text) is
/// decided by `reminder_scheduler.dart`; this file only talks to the plugin.
/// Scheduling uses **inexact** alarms (no SCHEDULE_EXACT_ALARM permission or
/// Play policy review — observed delivery windows are minutes, which is fine
/// for reminders) and **absolute UTC instants** (`tz.UTC`), so no
/// timezone-lookup plugin is needed: a DST shift is at most an hour off until
/// the next launch/resume resync.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/reminders.dart';

/// One notification ready to hand to the plugin. [channelName] is the
/// localized, user-visible Android channel title (resolved by the scheduler,
/// which owns l10n); [fireAtLocal] is a device-local wall-clock instant.
typedef PlannedNotification = ({
  ReminderKind kind,
  String channelName,
  String title,
  String body,
  DateTime fireAtLocal,
  String payload,
});

/// What the scheduler needs from the platform layer — a seam so scheduler
/// tests can assert the planned set without touching the plugin.
abstract class ReminderSink {
  Future<void> syncPlanned(List<PlannedNotification> planned);
}

class ReminderNotifications implements ReminderSink {
  ReminderNotifications({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  AndroidFlutterLocalNotificationsPlugin? get _android {
    try {
      return _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
    } catch (_) {
      // `FlutterLocalNotificationsPlatform.instance` is a `late` field that
      // only plugin registration initializes — accessing it under
      // `flutter test` (or an unsupported platform) throws LateInitialization
      // instead of returning null.
      return null;
    }
  }

  IOSFlutterLocalNotificationsPlugin? get _ios {
    try {
      return _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
    } catch (_) {
      // Same LateInitialization caveat as [_android].
      return null;
    }
  }

  /// Initializes the plugin and registers the notification-tap handler.
  /// Must run *after* the first frame (platform-channel calls before it can
  /// hang forever on some devices — see the pre-warm note in `main.dart`).
  Future<void> init({required void Function(String payload) onTap}) async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        // Small icon must be a monochrome silhouette: Android discards the RGB
        // channels and tints every opaque pixel, so the launcher icon would
        // show up as a plain white square in the status bar.
        android: AndroidInitializationSettings('ic_stat_gauge'),
        // Permission-request flags off: iOS authorization is asked lazily via
        // [requestPermission] when the user first enables a reminder category,
        // never at startup (same rule as Android 13+).
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) onTap(payload);
      },
    );
    _initialized = true;
  }

  /// Requests the platform notification permission (Android 13+
  /// POST_NOTIFICATIONS runtime permission / iOS alert+badge+sound
  /// authorization). Called when the user first enables a reminder category —
  /// never at startup. Returns whether notifications are permitted afterwards.
  Future<bool> requestPermission() async {
    final android = _android;
    if (android != null) {
      return await android.requestNotificationsPermission() ?? true;
    }
    final ios = _ios;
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          true;
    }
    return true; // no runtime gate on this platform
  }

  /// Whether notifications are currently permitted (null-safe: unknown reads
  /// as true so the UI doesn't warn spuriously).
  Future<bool> areEnabled() async {
    final android = _android;
    if (android != null) {
      return await android.areNotificationsEnabled() ?? true;
    }
    final ios = _ios;
    if (ios != null) {
      return (await ios.checkPermissions())?.isEnabled ?? true;
    }
    return true;
  }

  /// The payload of the notification that cold-started the app, if any.
  Future<String?> launchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return details.notificationResponse?.payload;
  }

  /// iOS keeps only the 64 soonest pending notification requests and silently
  /// drops the rest, so every sync schedules the soonest 64 — on all platforms,
  /// for identical behavior. Anything beyond that horizon is picked up by a
  /// later launch/resume resync long before it is due.
  static const _maxPending = 64;

  /// Replaces every scheduled reminder with [planned]. Cancel-all is safe and
  /// idempotent: the app owns no other notifications, and the scheduler
  /// recomputes the full set from the database on every sync.
  @override
  Future<void> syncPlanned(List<PlannedNotification> planned) async {
    if (!_initialized) return;
    await _plugin.cancelAll();
    // The plugin throws on past dates; anything that slipped this close is
    // already visible in the in-app due chips.
    final cutoff = DateTime.now().add(const Duration(minutes: 1));
    final upcoming =
        planned.where((n) => n.fireAtLocal.isAfter(cutoff)).toList()
          ..sort((a, b) => a.fireAtLocal.compareTo(b.fireAtLocal));
    // Per-item isolation (#98): cancelAll already ran, so a single plugin
    // throw must not abandon the tail of the set unscheduled — skip the bad
    // entry, schedule the rest, report the first failure once.
    var id = 1;
    Object? firstError;
    StackTrace? firstStack;
    for (final n in upcoming.take(_maxPending)) {
      try {
        await _plugin.zonedSchedule(
          id: id++,
          title: n.title,
          body: n.body,
          scheduledDate: tz.TZDateTime.from(n.fireAtLocal.toUtc(), tz.UTC),
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId(n.kind),
              n.channelName,
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
            ),
            // No channels on iOS; the thread identifier groups reminders of
            // the same kind in Notification Center instead.
            iOS: DarwinNotificationDetails(
              threadIdentifier: _channelId(n.kind),
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: n.payload,
        );
      } catch (e, s) {
        firstError ??= e;
        firstStack ??= s;
      }
    }
    if (firstError != null) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: firstError,
          stack: firstStack,
          library: 'reminders',
          context: ErrorSummary('scheduling reminder notifications'),
        ),
      );
    }
  }

  static String _channelId(ReminderKind kind) => switch (kind) {
    ReminderKind.testing => 'reminders_testing',
    ReminderKind.dosing => 'reminders_dosing',
    ReminderKind.maintenance => 'reminders_maintenance',
  };

  /// Fixed id of the one-shot reagent-timer chime (#90), far outside the
  /// 1..[_maxPending] range the reminder sync issues. The sync's `cancelAll`
  /// would clear a pending chime anyway — acceptable, because resyncs run on
  /// launch/resume, exactly when the foreground timer takes over again.
  static const _timerChimeId = 9001;

  /// Schedules a single notification at [fireAt] — the iOS stand-in for the
  /// Hanna reagent-timer beep (#90): iOS suspends Dart timers when the phone
  /// locks or the app backgrounds, so without this the beep meant to reach a
  /// user across the room would only sound on unlock, after the reaction
  /// window was missed. Plays the platform's default notification sound (the
  /// in-app beep asset isn't visible to the iOS notification center).
  Future<void> scheduleTimerChime({
    required DateTime fireAt,
    required String channelName,
    required String title,
    required String body,
  }) async {
    if (!_initialized) return;
    if (!fireAt.isAfter(DateTime.now())) return;
    await _plugin.zonedSchedule(
      id: _timerChimeId,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(fireAt.toUtc(), tz.UTC),
      notificationDetails: NotificationDetails(
        // Android never schedules a chime (the in-app timer keeps running in
        // the background there), but the channel keeps the call total should
        // that change. [channelName] is localized by the caller, same
        // division of labor as [PlannedNotification.channelName].
        android: AndroidNotificationDetails(
          'hanna_timer',
          channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(threadIdentifier: 'hanna_timer'),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Cancels a pending chime — the app is foreground again, the in-app beep
  /// owns the expiry.
  Future<void> cancelTimerChime() async {
    if (!_initialized) return;
    await _plugin.cancel(id: _timerChimeId);
  }
}
