/// Background reminder scheduler (U1/U2/U12): reads the whole database
/// (cross-tank — deliberately *not* the active-tank-scoped UI providers),
/// computes every due event in the next [kReminderHorizonDays] via the pure
/// domain math, coalesces them into one notification per (tank, kind, day),
/// and hands the set to the platform wrapper.
///
/// Self-healing by design: every launch/resume — and, debounced, every write
/// to a reminder-relevant table — recomputes the full set from scratch, so a
/// missed edge costs at most one stale notification until the next resync.
/// The honest trade-off of app-scheduled local notifications: a user who
/// doesn't open the app for 14+ days stops getting reminders (the in-app due
/// chips catch up instantly).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../domain/parameter_catalog.dart';
import '../domain/reminders.dart';
import '../domain/ro.dart';
import '../domain/supplement_catalog.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_helpers.dart';
import 'database.dart';
import 'notifications.dart';
import 'settings.dart';

/// How far ahead notifications are scheduled. Bounded so the OS alarm list
/// (and iOS's 64-pending limit, if that platform ever ships) stays small.
const kReminderHorizonDays = 14;

/// Hard cap on the planned set after coalescing.
const kMaxPlannedNotifications = 50;

class ReminderScheduler {
  ReminderScheduler(this._db, this._sink);

  final AppDatabase _db;
  final ReminderSink _sink;

  StreamSubscription<void>? _tableEvents;
  Timer? _debounce;
  bool _syncing = false;
  bool _dirty = false;

  /// Starts the debounced auto-resync on any write that can change what is
  /// due: readings (testing anchors), the action logs (maintenance anchors),
  /// dosing entries, cadence/schedule/tank edits, and settings (the master
  /// switches, reminder time, and locale all live there).
  void start() {
    _tableEvents ??= _db
        .tableUpdates(
          TableUpdateQuery.onAllTables([
            _db.tanks,
            _db.trackedParameters,
            _db.readings,
            _db.waterChanges,
            _db.carbonChanges,
            _db.equipmentCleanings,
            _db.dosingEntries,
            _db.maintenanceSchedules,
            _db.roStages,
            _db.roStageReplacements,
            _db.settings,
          ]),
        )
        .listen((_) {
          _debounce?.cancel();
          _debounce = Timer(
            const Duration(seconds: 2),
            () => unawaited(resync()),
          );
        });
  }

  void dispose() {
    _debounce?.cancel();
    unawaited(_tableEvents?.cancel());
    _tableEvents = null;
  }

  /// Recomputes and reschedules everything. Single-flight: a call landing
  /// during a sync marks it dirty and the running sync loops once more, so
  /// the final state always reflects the latest data.
  Future<void> resync() async {
    if (_syncing) {
      _dirty = true;
      return;
    }
    _syncing = true;
    try {
      do {
        _dirty = false;
        await _sink.syncPlanned(await plan(now: DateTime.now()));
      } while (_dirty);
    } catch (e, s) {
      // Reminders must never disrupt the app; the next resync retries.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: e,
          stack: s,
          library: 'reminders',
          context: ErrorSummary('rescheduling reminder notifications'),
        ),
      );
    } finally {
      _syncing = false;
    }
  }

  /// Computes the full planned set for the horizon starting at [now].
  /// Exposed for tests (which fake the sink and call this directly).
  Future<List<PlannedNotification>> plan({required DateTime now}) async {
    final settings = AppSettings(_db);
    final testingOn = await settings.readRemindersTesting();
    final dosingOn = await settings.readRemindersDosing();
    final maintenanceOn = await settings.readRemindersMaintenance();
    if (!testingOn && !dosingOn && !maintenanceOn) return const [];

    final l = await _localizations();
    final reminderTime = await settings.readReminderTime();
    final until = now.add(const Duration(days: kReminderHorizonDays));
    final tanks = await _db.getTanks(); // visible only — soft-deleted excluded
    final multiTank = tanks.length > 1;

    // Elastic dues fire on their due day at the configured reminder time; a
    // fire moment already in the past (overdue, or due today before the
    // reminder time) is not notified after the fact — the due chips carry it.
    DateTime? fireAtFor(DateTime? due) {
      if (due == null) return null;
      final fireAt = DateTime(
        due.year,
        due.month,
        due.day,
        reminderTime.hour,
        reminderTime.minute,
      );
      if (fireAt.isBefore(now) || fireAt.isAfter(until)) return null;
      return fireAt;
    }

    // The microelements switch (U17) silences micro-element test reminders
    // the way the RO switch silences RO ones — hidden features must not keep
    // notifying. Core-parameter reminders are unaffected.
    final microOn = await settings.readMicroEnabled();

    final items = <ReminderItem>[];
    for (final tank in tanks) {
      if (testingOn) {
        final params = await _db.getTrackedParameters(tank.id);
        final latest = await _db.latestReadingTimesPerParam(tank.id);
        for (final p in params) {
          if (!p.enabled || p.testCadenceDays == null) continue;
          if (!microOn && !isCoreParam(p.paramKey)) continue;
          final fireAt = fireAtFor(
            nextElasticDue(
              lastDone: latest[p.paramKey],
              cadenceDays: p.testCadenceDays,
              now: now,
            ),
          );
          if (fireAt == null) continue;
          items.add((
            tankId: tank.id,
            kind: ReminderKind.testing,
            fireAt: fireAt,
            label: l.paramName(p.paramKey),
          ));
        }
      }
      if (maintenanceOn) {
        final schedules = await _db.getMaintenanceSchedules(tank.id);
        final lastActions = await _db.latestActionTimes(tank.id);
        for (final s in schedules) {
          if (!s.remindEnabled) continue;
          final typed = MaintenanceActionType.fromName(s.actionType);
          final fireAt = fireAtFor(
            nextMaintenanceDue(
              lastDone: typed != null ? lastActions[typed] : s.lastDoneAt,
              cadenceDays: s.cadenceDays,
              cadenceUnit: s.cadenceUnit,
              weekdays: s.weekdays,
              monthDay: s.monthDay,
              scheduledAt: s.scheduledAt,
              now: now,
            ),
          );
          if (fireAt == null) continue;
          final label = typed != null ? _actionName(l, typed) : (s.title ?? '');
          if (label.isEmpty) continue;
          items.add((
            tankId: tank.id,
            kind: ReminderKind.maintenance,
            fireAt: fireAt,
            label: label,
          ));
        }
      }
    }
    if (maintenanceOn && await settings.readRoUnitEnabled()) {
      // The shared RO unit (U16) — device-scoped, so outside the tank loop
      // and carrying no tankId; the Settings feature switch silences it
      // wholesale. A stage with no logged replacement has no
      // computable due date and is silently skipped (the overview screen
      // prompts for it instead — never a guessed reminder).
      final stages = await _db.getRoStages();
      if (stages.isNotEmpty) {
        final lastReplaced = await _db.latestRoReplacementTimes();
        for (final s in stages) {
          if (!s.enabled || !s.remindEnabled) continue;
          final fireAt = fireAtFor(
            roStageDue(
              lastReplacedAt: lastReplaced[s.id],
              lifespanDays: s.lifespanDays,
              now: now,
            ),
          );
          if (fireAt == null) continue;
          final label = _roStageName(l, s);
          if (label.isEmpty) continue;
          items.add((
            tankId: null,
            kind: ReminderKind.maintenance,
            fireAt: fireAt,
            label: label,
          ));
        }
      }
    }
    if (dosingOn) {
      final visibleTanks = {for (final t in tanks) t.id};
      for (final d in await _db.getAllDosingEntries()) {
        if (d.state != DosingState.active.name ||
            !d.remindEnabled ||
            !visibleTanks.contains(d.tankId)) {
          continue;
        }
        for (final occurrence in doseOccurrences(
          frequency: d.frequency,
          intervalDays: d.intervalDays,
          weekdays: d.weekdays,
          doseTime: d.doseTime,
          startedAt: d.startedAt ?? d.createdAt,
          from: now,
          until: until,
        )) {
          items.add((
            tankId: d.tankId,
            kind: ReminderKind.dosing,
            fireAt: occurrence,
            label: d.product,
          ));
        }
      }
    }

    final tankNames = {for (final t in tanks) t.id: t.name};
    return [
      for (final p in coalesceReminders(items).take(kMaxPlannedNotifications))
        (
          kind: p.kind,
          channelName: _channelName(l, p.kind),
          // Device-scoped (null-tank) reminders — the RO unit — get their own
          // title and never a tank name: they belong to no aquarium.
          title: p.tankId == null
              ? l.notifRoTitle
              : multiTank
              ? l.notifTitleWithTank(
                  _title(l, p.kind),
                  tankNames[p.tankId] ?? '',
                )
              : _title(l, p.kind),
          body: p.labels.join(', '),
          fireAtLocal: p.fireAt,
          payload: jsonEncode({
            'tankId': p.tankId,
            'route': p.tankId == null ? '/ro' : _routeFor(p.kind),
          }),
        ),
    ];
  }

  /// Notification strings are rendered at schedule time, so they follow the
  /// app's stored language (or the system locale) through the normal l10n
  /// pipeline — no BuildContext exists back here.
  Future<AppLocalizations> _localizations() async {
    final code = AppSettings.decodeLocaleCode(await _db.getSetting(kLocaleKey));
    final locale = code == kDefaultLocaleCode
        ? PlatformDispatcher.instance.locale
        : Locale(code);
    try {
      return lookupAppLocalizations(locale);
    } catch (_) {
      return lookupAppLocalizations(const Locale('en'));
    }
  }

  static String _title(AppLocalizations l, ReminderKind kind) => switch (kind) {
    ReminderKind.testing => l.notifTestingTitle,
    ReminderKind.dosing => l.notifDosingTitle,
    ReminderKind.maintenance => l.notifMaintenanceTitle,
  };

  static String _channelName(AppLocalizations l, ReminderKind kind) =>
      switch (kind) {
        ReminderKind.testing => l.notifChannelTesting,
        ReminderKind.dosing => l.notifChannelDosing,
        ReminderKind.maintenance => l.notifChannelMaintenance,
      };

  static String _actionName(AppLocalizations l, MaintenanceActionType type) =>
      switch (type) {
        MaintenanceActionType.waterChange => l.waterChange,
        MaintenanceActionType.carbonChange => l.carbonChange,
        MaintenanceActionType.equipmentCleaning => l.equipmentCleaning,
      };

  static String _roStageName(AppLocalizations l, RoStage s) =>
      l.roStageName(s.stageType, s.title);

  static String _routeFor(ReminderKind kind) => switch (kind) {
    ReminderKind.testing => '/add-reading',
    ReminderKind.dosing => '/?tab=dosing',
    ReminderKind.maintenance => '/?tab=actions',
  };
}

/// Handles a reminder-notification tap: activates the target tank (if it
/// still exists) so the destination screen shows the right data, then
/// navigates. Malformed payloads are ignored.
Future<void> handleReminderPayload(
  AppDatabase db,
  String payload,
  void Function(String route) go,
) async {
  Object? decoded;
  try {
    decoded = jsonDecode(payload);
  } on FormatException {
    return;
  }
  if (decoded is! Map<String, dynamic>) return;
  final tankId = decoded['tankId'];
  final route = decoded['route'];
  if (tankId is int) {
    final tanks = await db.getTanks();
    if (tanks.any((t) => t.id == tankId) &&
        await db.getActiveTankId() != tankId) {
      await db.setActiveTank(tankId);
    }
  }
  if (route is String && route.startsWith('/')) go(route);
}
