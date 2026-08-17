import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/domain/setup_type.dart';
import 'package:reeftracker/features/devices/device_inventory_actions.dart';
import 'package:reeftracker/l10n/app_localizations.dart';

void main() {
  testWidgets('shared inventory rename dialog persists the normalized name', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final tankId = await db.createTankWithPreset(
      name: 'Display Reef',
      type: SetupType.mixed,
    );
    await db.upsertReefFactoryDevice(
      identifier: 'RF-1',
      model: 'RFPM01',
      address: '10.0.2.2',
      name: 'Old name',
    );
    final device = (await db.deviceByIdentifier('RF-1'))!;
    await db.updateDeviceNameTank(device.id, name: device.name, tankId: tankId);
    final assigned = (await db.deviceByIdentifier('RF-1'))!;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => FilledButton(
                onPressed: () => DeviceInventoryActions(ref: ref).rename(
                  context,
                  assigned,
                  DeviceInventoryLabels(
                    renameTitle: 'Rename meter',
                    nameField: 'Meter name',
                    selectTankTitle: 'Select tank',
                    removeTitle: 'Remove meter',
                    removeConfirm: (name) => 'Remove $name?',
                  ),
                ),
                child: const Text('Rename'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    expect(find.text('Rename meter'), findsOneWidget);
    expect(find.text('Old name'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '  New name  ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final renamed = await db.deviceByIdentifier('RF-1');
    expect(renamed?.name, 'New name');
    expect(renamed?.tankId, tankId);
  });
}
