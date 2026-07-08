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
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
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
    var id = 1;
    for (final n in upcoming.take(_maxPending)) {
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
          // No channels on iOS; the thread identifier groups reminders of the
          // same kind in Notification Center instead.
          iOS: DarwinNotificationDetails(threadIdentifier: _channelId(n.kind)),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: n.payload,
      );
    }
  }

  static String _channelId(ReminderKind kind) => switch (kind) {
    ReminderKind.testing => 'reminders_testing',
    ReminderKind.dosing => 'reminders_dosing',
    ReminderKind.maintenance => 'reminders_maintenance',
  };
}
