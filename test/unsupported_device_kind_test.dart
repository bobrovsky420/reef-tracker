import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/domain/setup_type.dart';
import 'package:reeftracker/features/apex/apex_screen.dart';
import 'package:reeftracker/features/devices/devices_screen.dart';
import 'package:reeftracker/l10n/app_localizations.dart';

void main() {
  testWidgets(
    'an unknown persisted kind is shown as unsupported, never as Apex',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final tankId = await db.createTankWithPreset(
        name: 'Reef',
        type: SetupType.mixed,
      );
      await db
          .into(db.devices)
          .insert(
            DevicesCompanion.insert(
              kind: 'future-controller',
              identifier: 'FUTURE-1',
              name: const Value('Future controller'),
              address: const Value('10.0.0.99'),
              tankId: Value(tankId),
            ),
          );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [dbProvider.overrideWithValue(db)],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const DevicesScreen(),
          ),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('Future controller'), findsOneWidget);
      expect(
        find.textContaining("This app can't read this device type yet."),
        findsWidgets,
      );
      expect(find.textContaining('future-controller'), findsOneWidget);
      expect(find.byType(ApDeviceSection), findsNothing);
      expect(
        deviceVendorIcon('future-controller'),
        Icons.device_unknown_outlined,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    },
  );
}
