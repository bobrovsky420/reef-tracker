/// Normalized read-side maintenance events and their presentation adapters.
///
/// Persistence keeps its existing tables and IDs. Consumers receive one model
/// for sorting, titles, icons, summaries, marker metadata and supported
/// actions. Adding another event record means adding one adapter to the
/// registry rather than branching in every history or chart.
library;

import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../domain/supplement_catalog.dart';
import '../../domain/units.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../dosing/dosing_presentation.dart';

enum MaintenanceEventKind {
  waterChange,
  carbonChange,
  equipmentCleaning,
  dosingPlan,
  manualDose,
}

enum MaintenanceMarkerKind { waterChange, carbonChange, equipmentCleaning }

class MaintenanceEventActions {
  const MaintenanceEventActions({this.edit, this.delete, this.undo});

  final Future<void> Function()? edit;
  final Future<void> Function()? delete;
  final Future<void> Function()? undo;

  bool get canEdit => edit != null;
  bool get canDelete => delete != null;
  bool get canUndo => undo != null;

  MaintenanceEventActions withEdit(Future<void> Function()? value) =>
      MaintenanceEventActions(edit: value, delete: delete, undo: undo);
}

/// Existing repository commands adapted once for normalized consumers.
/// Action-log rows retain their established one-tap undo behavior. Dosing
/// history deletions remain confirmed and irreversible, so their undo
/// metadata is intentionally null.
MaintenanceEventActions maintenancePersistenceActions(
  AppDatabase db,
  Object record,
) => switch (record) {
  final WaterChange change => MaintenanceEventActions(
    delete: () => db.deleteWaterChange(change.id),
    undo: () => db.insertWaterChange(
      tankId: change.tankId,
      changedAt: change.changedAt,
      amountLiters: change.amountLiters,
      note: change.note,
    ),
  ),
  final CarbonChange change => MaintenanceEventActions(
    delete: () => db.deleteCarbonChange(change.id),
    undo: () => db.insertCarbonChange(
      tankId: change.tankId,
      changedAt: change.changedAt,
      grams: change.grams,
      note: change.note,
    ),
  ),
  final EquipmentCleaning cleaning => MaintenanceEventActions(
    delete: () => db.deleteEquipmentCleaning(cleaning.id),
    undo: () => db.insertEquipmentCleaning(
      tankId: cleaning.tankId,
      cleanedAt: cleaning.cleanedAt,
      note: cleaning.note,
    ),
  ),
  final DosingEntry entry => MaintenanceEventActions(
    delete: () => db.deleteDosingEntry(entry.id),
  ),
  final ManualDose dose => MaintenanceEventActions(
    delete: () => db.deleteManualDose(dose.id),
  ),
  _ => const MaintenanceEventActions(),
};

@immutable
class MaintenanceEvent {
  const MaintenanceEvent({
    required this.key,
    required this.kind,
    required this.timestamp,
    required this.title,
    required this.icon,
    required this.summary,
    required this.source,
    this.note,
    this.sourceLabel,
    this.tags = const [],
    this.timelineDetail,
    this.detailHighlighted = false,
    this.deleteTitle,
    this.deleteBody,
    this.markerKind,
    this.corrupt = false,
    this.actions = const MaintenanceEventActions(),
  });

  final String key;
  final MaintenanceEventKind kind;
  final DateTime timestamp;
  final String title;
  final IconData icon;
  final String summary;
  final String? note;
  final String? sourceLabel;
  final List<String> tags;
  final String? timelineDetail;
  final bool detailHighlighted;
  final String? deleteTitle;
  final String? deleteBody;
  final MaintenanceMarkerKind? markerKind;
  final bool corrupt;
  final Object source;
  final MaintenanceEventActions actions;
}

class MaintenanceEventContext {
  const MaintenanceEventContext({
    required this.context,
    required this.l,
    required this.units,
  });

  final BuildContext context;
  final AppLocalizations l;
  final UnitPrefs units;
}

abstract interface class MaintenanceEventAdapter {
  bool supports(Object record);

  MaintenanceEvent adapt(
    Object record,
    MaintenanceEventContext context, {
    MaintenanceEventActions actions,
  });

  ({DateTime time, MaintenanceMarkerKind kind})? marker(Object record);
}

class MaintenanceEventAdapterRegistry {
  MaintenanceEventAdapterRegistry(Iterable<MaintenanceEventAdapter> adapters)
    : _adapters = List.unmodifiable(adapters);

  final List<MaintenanceEventAdapter> _adapters;

  List<MaintenanceEventAdapter> get adapters => _adapters;

  MaintenanceEventAdapter? adapterFor(Object record) {
    for (final adapter in _adapters) {
      if (adapter.supports(record)) return adapter;
    }
    return null;
  }

  MaintenanceEvent? tryAdapt(
    Object record,
    MaintenanceEventContext context, {
    MaintenanceEventActions actions = const MaintenanceEventActions(),
  }) => adapterFor(record)?.adapt(record, context, actions: actions);

  List<MaintenanceEvent> adaptAll(
    Iterable<Object> records,
    MaintenanceEventContext context, {
    MaintenanceEventActions Function(Object record)? actionsFor,
  }) {
    final events = <MaintenanceEvent>[];
    for (final record in records) {
      final event = tryAdapt(
        record,
        context,
        actions: actionsFor?.call(record) ?? const MaintenanceEventActions(),
      );
      if (event != null) events.add(event);
    }
    events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return events;
  }

  List<({DateTime time, MaintenanceMarkerKind kind})> markers(
    Iterable<Object> records,
  ) => [for (final record in records) ?adapterFor(record)?.marker(record)];
}

class _WaterChangeAdapter implements MaintenanceEventAdapter {
  const _WaterChangeAdapter();

  @override
  bool supports(Object record) => record is WaterChange;

  @override
  MaintenanceEvent adapt(
    Object record,
    MaintenanceEventContext context, {
    MaintenanceEventActions actions = const MaintenanceEventActions(),
  }) {
    final change = record as WaterChange;
    return MaintenanceEvent(
      key: 'water-${change.id}',
      kind: MaintenanceEventKind.waterChange,
      timestamp: change.changedAt,
      title: context.l.waterChange,
      icon: Icons.format_color_fill,
      summary: change.amountLiters == null
          ? context.l.amountNotRecorded
          : context.l.volumeWithUnit(
              change.amountLiters!,
              context.units.volume,
            ),
      note: change.note,
      markerKind: MaintenanceMarkerKind.waterChange,
      source: change,
      actions: actions,
    );
  }

  @override
  ({DateTime time, MaintenanceMarkerKind kind})? marker(Object record) {
    if (record is! WaterChange) return null;
    return (time: record.changedAt, kind: MaintenanceMarkerKind.waterChange);
  }
}

class _CarbonChangeAdapter implements MaintenanceEventAdapter {
  const _CarbonChangeAdapter();

  @override
  bool supports(Object record) => record is CarbonChange;

  @override
  MaintenanceEvent adapt(
    Object record,
    MaintenanceEventContext context, {
    MaintenanceEventActions actions = const MaintenanceEventActions(),
  }) {
    final change = record as CarbonChange;
    return MaintenanceEvent(
      key: 'carbon-${change.id}',
      kind: MaintenanceEventKind.carbonChange,
      timestamp: change.changedAt,
      title: context.l.carbonChange,
      icon: Icons.grain,
      summary: change.grams == null
          ? context.l.weightNotRecorded
          : context.l.gramsSuffix(formatLocaleNumberTrim(change.grams!)),
      note: change.note,
      markerKind: MaintenanceMarkerKind.carbonChange,
      source: change,
      actions: actions,
    );
  }

  @override
  ({DateTime time, MaintenanceMarkerKind kind})? marker(Object record) {
    if (record is! CarbonChange) return null;
    return (time: record.changedAt, kind: MaintenanceMarkerKind.carbonChange);
  }
}

class _EquipmentCleaningAdapter implements MaintenanceEventAdapter {
  const _EquipmentCleaningAdapter();

  @override
  bool supports(Object record) => record is EquipmentCleaning;

  @override
  MaintenanceEvent adapt(
    Object record,
    MaintenanceEventContext context, {
    MaintenanceEventActions actions = const MaintenanceEventActions(),
  }) {
    final cleaning = record as EquipmentCleaning;
    return MaintenanceEvent(
      key: 'equipment-${cleaning.id}',
      kind: MaintenanceEventKind.equipmentCleaning,
      timestamp: cleaning.cleanedAt,
      title: context.l.equipmentCleaning,
      icon: Icons.cleaning_services_outlined,
      summary: '',
      note: cleaning.note,
      markerKind: MaintenanceMarkerKind.equipmentCleaning,
      source: cleaning,
      actions: actions,
    );
  }

  @override
  ({DateTime time, MaintenanceMarkerKind kind})? marker(Object record) {
    if (record is! EquipmentCleaning) return null;
    return (
      time: record.cleanedAt,
      kind: MaintenanceMarkerKind.equipmentCleaning,
    );
  }
}

class _DosingEntryAdapter implements MaintenanceEventAdapter {
  const _DosingEntryAdapter();

  @override
  bool supports(Object record) => record is DosingEntry;

  @override
  MaintenanceEvent adapt(
    Object record,
    MaintenanceEventContext context, {
    MaintenanceEventActions actions = const MaintenanceEventActions(),
  }) {
    final entry = record as DosingEntry;
    final names = resolveSupplementNames(
      productKey: entry.productKey,
      storedVendor: entry.vendor,
      storedProgram: entry.program,
      storedProduct: entry.product,
    );
    final state = _strictDosingState(entry.state);
    final active = state == DosingState.active;
    final localizations = MaterialLocalizations.of(context.context);
    final from = entry.startedAt ?? entry.createdAt;
    final fromText = localizations.formatMediumDate(from);
    final period = active || entry.endedAt == null
        ? context.l.dosingHistorySince(fromText)
        : context.l.dosingHistoryPeriod(
            fromText,
            localizations.formatMediumDate(entry.endedAt!),
          );
    return MaintenanceEvent(
      key: 'dosing-${entry.id}',
      kind: MaintenanceEventKind.dosingPlan,
      timestamp: entry.startedAt ?? entry.createdAt,
      title: names.product,
      icon: active ? Icons.play_circle_outline : Icons.history,
      summary: dosingDetailLine(context.context, context.l, entry),
      note: entry.note,
      sourceLabel: [
        names.vendor,
        names.program,
      ].where((value) => value != null && value.isNotEmpty).join(' · '),
      tags: [
        if (entry.elementKey case final key?) context.l.paramName(key),
        if (active) context.l.dosingHistoryCurrent,
      ],
      timelineDetail: period,
      detailHighlighted: active,
      deleteTitle: context.l.deleteDosingRecordTitle,
      deleteBody: context.l.deleteDosingRecordBody,
      corrupt: state == null,
      source: entry,
      actions: actions,
    );
  }

  @override
  ({DateTime time, MaintenanceMarkerKind kind})? marker(Object record) => null;
}

class _ManualDoseAdapter implements MaintenanceEventAdapter {
  const _ManualDoseAdapter();

  @override
  bool supports(Object record) => record is ManualDose;

  @override
  MaintenanceEvent adapt(
    Object record,
    MaintenanceEventContext context, {
    MaintenanceEventActions actions = const MaintenanceEventActions(),
  }) {
    final dose = record as ManualDose;
    final names = resolveSupplementNames(
      productKey: dose.productKey,
      storedVendor: dose.vendor,
      storedProgram: dose.program,
      storedProduct: dose.product,
    );
    final unit = DoseUnit.fromName(dose.amountUnit);
    final localizations = MaterialLocalizations.of(context.context);
    final when =
        '${localizations.formatMediumDate(dose.dosedAt)} '
        '${TimeOfDay.fromDateTime(dose.dosedAt).format(context.context)}';
    return MaintenanceEvent(
      key: 'manual-dose-${dose.id}',
      kind: MaintenanceEventKind.manualDose,
      timestamp: dose.dosedAt,
      title: names.product,
      icon: Icons.vaccines_outlined,
      summary: '${formatDoseAmount(dose.amount)} ${unit.symbol} · $when',
      note: dose.note,
      sourceLabel: [
        names.vendor,
        names.program,
      ].where((value) => value != null && value.isNotEmpty).join(' · '),
      tags: [
        if (dose.elementKey case final key?) context.l.paramName(key),
        context.l.dosingHistoryManual,
      ],
      deleteTitle: context.l.deleteManualDoseTitle,
      deleteBody: context.l.deleteManualDoseBody,
      source: dose,
      actions: actions,
    );
  }

  @override
  ({DateTime time, MaintenanceMarkerKind kind})? marker(Object record) => null;
}

DosingState? _strictDosingState(String? name) {
  for (final state in DosingState.values) {
    if (state.name == name) return state;
  }
  return null;
}

final maintenanceEventAdapters = MaintenanceEventAdapterRegistry(const [
  _WaterChangeAdapter(),
  _CarbonChangeAdapter(),
  _EquipmentCleaningAdapter(),
  _DosingEntryAdapter(),
  _ManualDoseAdapter(),
]);
