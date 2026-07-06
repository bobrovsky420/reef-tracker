/// Thin platform wrapper around `flutter_local_notifications` for the
/// reminders feature (U1/U2/U12): init + tap callback, the Android runtime
/// permission, and a cancel-all-then-reschedule sync of planned reminders.
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

  /// Initializes the plugin and registers the notification-tap handler.
  /// Must run *after* the first frame (platform-channel calls before it can
  /// hang forever on some devices — see the pre-warm note in `main.dart`).
  Future<void> init({required void Function(String payload) onTap}) async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) onTap(payload);
      },
    );
    _initialized = true;
  }

  /// Requests the Android 13+ POST_NOTIFICATIONS runtime permission. Called
  /// when the user first enables a reminder category — never at startup.
  /// Returns whether notifications are permitted afterwards.
  Future<bool> requestPermission() async {
    final android = _android;
    if (android == null) return true; // no runtime gate on this platform
    return await android.requestNotificationsPermission() ?? true;
  }

  /// Whether notifications are currently permitted (null-safe: unknown reads
  /// as true so the UI doesn't warn spuriously).
  Future<bool> areEnabled() async =>
      await _android?.areNotificationsEnabled() ?? true;

  /// The payload of the notification that cold-started the app, if any.
  Future<String?> launchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return details.notificationResponse?.payload;
  }

  /// Replaces every scheduled reminder with [planned]. Cancel-all is safe and
  /// idempotent: the app owns no other notifications, and the scheduler
  /// recomputes the full set from the database on every sync.
  @override
  Future<void> syncPlanned(List<PlannedNotification> planned) async {
    if (!_initialized) return;
    await _plugin.cancelAll();
    final cutoff = DateTime.now().add(const Duration(minutes: 1));
    var id = 1;
    for (final n in planned) {
      // The plugin throws on past dates; anything that slipped this close is
      // already visible in the in-app due chips.
      if (!n.fireAtLocal.isAfter(cutoff)) continue;
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
