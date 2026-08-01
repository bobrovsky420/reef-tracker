// Tests for the plugin-facing sync in `data/notifications.dart` (U1/U2/U12):
// cancel-all-then-reschedule, the past-date guard, and the 64-item pending cap
// (iOS silently drops requests beyond the soonest 64, so the sync sorts and
// truncates on every platform).
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/notifications.dart';
import 'package:reeftracker/domain/reminders.dart';
import 'package:timezone/timezone.dart';

/// `FlutterLocalNotificationsPlugin` is a singleton with a private
/// constructor, so the fake `implements` it; [noSuchMethod] absorbs the many
/// members the sync path never touches.
class _FakePlugin implements FlutterLocalNotificationsPlugin {
  final scheduled = <({int id, String? title, TZDateTime date})>[];
  int cancelAllCalls = 0;

  /// 1-based `zonedSchedule` call indices that throw (#98).
  final throwOnCalls = <int>{};
  int _scheduleCalls = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async => true;

  @override
  Future<void> cancelAll() async {
    cancelAllCalls++;
    scheduled.clear();
  }

  @override
  Future<void> zonedSchedule({
    required int id,
    required TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    String? title,
    String? body,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    _scheduleCalls++;
    if (throwOnCalls.contains(_scheduleCalls)) {
      throw StateError('plugin refused entry $_scheduleCalls');
    }
    scheduled.add((id: id, title: title, date: scheduledDate));
  }
}

PlannedNotification _planned(String title, DateTime at) => (
  kind: ReminderKind.testing,
  channelName: 'channel',
  title: title,
  body: '',
  fireAtLocal: at,
  payload: 'payload',
);

void main() {
  test('syncPlanned keeps the soonest 64 and skips past dates', () async {
    final plugin = _FakePlugin();
    final sink = ReminderNotifications(plugin: plugin);
    await sink.init(onTap: (_) {});

    final now = DateTime.now();
    // 70 upcoming reminders handed over in reverse order, plus one already
    // past: the sync must drop the past one, sort by fire time, and truncate
    // to the 64 soonest.
    final planned = <PlannedNotification>[
      for (var i = 70; i >= 1; i--) _planned('r$i', now.add(Duration(days: i))),
      _planned('past', now.subtract(const Duration(hours: 1))),
    ];
    await sink.syncPlanned(planned);

    expect(plugin.cancelAllCalls, 1);
    expect(plugin.scheduled, hasLength(64));
    expect(plugin.scheduled.first.title, 'r1');
    expect(plugin.scheduled.last.title, 'r64');
    final dates = plugin.scheduled.map((s) => s.date).toList();
    for (var i = 1; i < dates.length; i++) {
      expect(dates[i].isAfter(dates[i - 1]), isTrue);
    }
  });

  test('syncPlanned skips throwing entries, schedules the rest, '
      'reports once (#98)', () async {
    final plugin = _FakePlugin()..throwOnCalls.addAll({2, 5});
    final sink = ReminderNotifications(plugin: plugin);
    await sink.init(onTap: (_) {});

    // cancelAll has already run when the loop starts, so before the per-item
    // isolation one throw wiped the whole set: everything cancelled, the
    // tail never scheduled.
    final reported = <FlutterErrorDetails>[];
    final prior = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = prior);

    final now = DateTime.now();
    await sink.syncPlanned([
      for (var i = 1; i <= 6; i++) _planned('r$i', now.add(Duration(days: i))),
    ]);

    expect(plugin.scheduled.map((s) => s.title), ['r1', 'r3', 'r4', 'r6']);
    expect(reported, hasLength(1));
  });

  test('syncPlanned is a no-op before init', () async {
    final plugin = _FakePlugin();
    final sink = ReminderNotifications(plugin: plugin);
    await sink.syncPlanned([
      _planned('r1', DateTime.now().add(const Duration(days: 1))),
    ]);
    expect(plugin.cancelAllCalls, 0);
    expect(plugin.scheduled, isEmpty);
  });
}
