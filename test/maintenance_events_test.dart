import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/domain/supplement_catalog.dart';
import 'package:reeftracker/domain/units.dart';
import 'package:reeftracker/features/maintenance/maintenance_events.dart';
import 'package:reeftracker/l10n/app_localizations.dart';

void main() {
  testWidgets('all persisted event variants normalize with parity metadata', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (value) {
            context = value;
            return const SizedBox();
          },
        ),
      ),
    );

    final base = DateTime(2026, 8, 1, 12);
    final records = <Object>[
      WaterChange(
        id: 1,
        tankId: 7,
        changedAt: base,
        amountLiters: 20,
        note: 'water note',
      ),
      CarbonChange(
        id: 2,
        tankId: 7,
        changedAt: base.add(const Duration(hours: 1)),
        grams: 75,
      ),
      EquipmentCleaning(
        id: 3,
        tankId: 7,
        cleanedAt: base.add(const Duration(hours: 2)),
      ),
      DosingEntry(
        id: 4,
        tankId: 7,
        product: 'Alkalinity mix',
        elementKey: 'alkalinity',
        amount: 5,
        amountUnit: DoseUnit.ml.name,
        basis: DoseBasis.perDay.name,
        frequency: DoseFrequency.daily.name,
        remindEnabled: false,
        displayOrder: 0,
        createdAt: base.add(const Duration(hours: 3)),
        startedAt: base.add(const Duration(hours: 3)),
        state: DosingState.active.name,
      ),
      ManualDose(
        id: 5,
        tankId: 7,
        dosedAt: base.add(const Duration(hours: 4)),
        product: 'Correction dose',
        elementKey: 'alkalinity',
        amount: 2.5,
        amountUnit: DoseUnit.ml.name,
      ),
    ];
    final events = maintenanceEventAdapters.adaptAll(
      records,
      MaintenanceEventContext(
        context: context,
        l: AppLocalizations.of(context),
        units: const UnitPrefs(),
      ),
      actionsFor: (_) => MaintenanceEventActions(
        edit: () async {},
        delete: () async {},
        undo: () async {},
      ),
    );

    expect(events.map((event) => event.kind), [
      MaintenanceEventKind.manualDose,
      MaintenanceEventKind.dosingPlan,
      MaintenanceEventKind.equipmentCleaning,
      MaintenanceEventKind.carbonChange,
      MaintenanceEventKind.waterChange,
    ]);
    expect(events.every((event) => event.actions.canEdit), isTrue);
    expect(events.every((event) => event.actions.canDelete), isTrue);
    expect(events.every((event) => event.actions.canUndo), isTrue);
    expect(events.last.summary, contains('20'));
    expect(events.last.note, 'water note');
    expect(events[1].tags, contains('Current'));
    expect(events.first.tags, contains('Manual'));

    final markers = maintenanceEventAdapters.markers(records);
    expect(markers.map((marker) => marker.kind), [
      MaintenanceMarkerKind.waterChange,
      MaintenanceMarkerKind.carbonChange,
      MaintenanceMarkerKind.equipmentCleaning,
    ]);
  });

  testWidgets('unknown records are explicit and corrupt dosing state is safe', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (value) {
            context = value;
            return const SizedBox();
          },
        ),
      ),
    );
    final presentation = MaintenanceEventContext(
      context: context,
      l: AppLocalizations.of(context),
      units: const UnitPrefs(),
    );

    expect(maintenanceEventAdapters.tryAdapt(Object(), presentation), isNull);
    final corrupt = maintenanceEventAdapters.tryAdapt(
      DosingEntry(
        id: 9,
        tankId: 1,
        product: 'Legacy dose',
        remindEnabled: false,
        displayOrder: 0,
        createdAt: DateTime(2026),
        state: 'future-corrupt-state',
      ),
      presentation,
    );
    expect(corrupt, isNotNull);
    expect(corrupt!.corrupt, isTrue);
    expect(corrupt.tags, isNot(contains('Current')));
  });
}
