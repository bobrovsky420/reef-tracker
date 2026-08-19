import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/domain/setup_type.dart';
import 'package:reeftracker/domain/wall_display.dart';
import 'package:reeftracker/features/wall/wall_settings_screen.dart';
import 'package:reeftracker/l10n/app_localizations.dart';

class _SlowWallOrderDatabase extends AppDatabase {
  _SlowWallOrderDatabase() : super(NativeDatabase.memory());

  final writeStarted = Completer<void>();
  final releaseWrite = Completer<void>();

  @override
  Future<void> setWallTileOrder(
    int tankId,
    List<({String deviceIdentifier, String paramKey})> orderedIds,
  ) async {
    writeStarted.complete();
    await releaseWrite.future;
    await super.setWallTileOrder(tankId, orderedIds);
  }
}

void main() {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> unmountApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('wall cards reorder by dragging their handles', (tester) async {
    tester.view.physicalSize = const Size(600, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = _SlowWallOrderDatabase();
    addTearDown(db.close);
    addTearDown(() {
      if (!db.releaseWrite.isCompleted) db.releaseWrite.complete();
    });
    final tankId = await db.createTankWithPreset(
      name: 'Reef',
      type: SetupType.mixed,
    );
    for (final parameter in await db.getTrackedParameters(tankId)) {
      await db.updateTrackedParameter(
        parameter.copyWith(
          enabled:
              parameter.paramKey == 'temperature' ||
              parameter.paramKey == 'salinity',
        ),
      );
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const WallSettingsScreen(),
        ),
      ),
    );
    await settle(tester);

    final handles = find.byIcon(Icons.drag_handle);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await settle(tester);
    expect(handles, findsNWidgets(2));
    await tester.ensureVisible(handles.first);
    await settle(tester);
    final firstDragListener = find.ancestor(
      of: handles.first,
      matching: find.byType(ReorderableDragStartListener),
    );
    final handleRect = tester.getRect(firstDragListener);
    expect(handleRect.width, greaterThanOrEqualTo(kMinInteractiveDimension));
    expect(handleRect.height, greaterThanOrEqualTo(kMinInteractiveDimension));
    // Start beside the painted icon. The whole visible handle area must accept
    // the drag, not just the icon's 16×16 glyph.
    final gesture = await tester.startGesture(
      Offset(handleRect.left + 4, handleRect.center.dy),
    );
    for (var i = 0; i < 5; i++) {
      await gesture.moveBy(const Offset(0, 35));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await settle(tester);
    expect(db.writeStarted.isCompleted, isTrue);

    expect(
      tester.getTopLeft(find.text('Salinity')).dy,
      lessThan(tester.getTopLeft(find.text('Temperature')).dy),
      reason: 'the dragged order should update before SQLite finishes writing',
    );

    db.releaseWrite.complete();
    await settle(tester);

    final rows = await db.getWallTileSettings(tankId);
    rows.sort((a, b) => a.displayOrder!.compareTo(b.displayOrder!));
    expect([for (final row in rows) row.paramKey], ['salinity', 'temperature']);
    expect(rows.every((row) => row.deviceIdentifier == kWallNoDevice), isTrue);

    await unmountApp(tester);
  });

  testWidgets('wall device card subtitle contains only the device name', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final tankId = await db.createTankWithPreset(
      name: 'Reef',
      type: SetupType.mixed,
    );
    await db.upsertReefFactoryDevice(
      identifier: 'RFPM012204210108',
      model: 'RFPM01',
      address: '192.168.1.15',
      name: 'Sump probe',
      tankId: tankId,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const WallSettingsScreen(),
        ),
      ),
    );
    await settle(tester);

    await tester.scrollUntilVisible(
      find.text('Sump probe'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester);
    expect(find.text('Sump probe'), findsOneWidget);
    expect(find.textContaining('Hiding this stops'), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('collected-data dialog can retain recent samples or clear all', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final tankId = await db.createTankWithPreset(
      name: 'Reef',
      type: SetupType.mixed,
    );
    final now = DateTime.now();
    for (final (id, age) in [
      ('old', const Duration(hours: 2)),
      ('recent', const Duration(minutes: 30)),
    ]) {
      await db.upsertDeviceSample(
        tankId: tankId,
        deviceIdentifier: id,
        paramKey: 'temperature',
        bucketStart: bucketStartFor(now.subtract(age)),
        value: 25,
      );
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const WallSettingsScreen(),
        ),
      ),
    );
    await settle(tester);

    final clearRow = find.text('Clear collected measurements');
    await tester.ensureVisible(clearRow);
    await tester.tap(clearRow);
    await tester.pumpAndSettle();
    expect(find.text('Delete everything'), findsOneWidget);
    expect(find.text('Keep the last 1 hour'), findsOneWidget);
    expect(find.text('Keep the last 4 hours'), findsOneWidget);
    expect(find.text('Keep the last 12 hours'), findsOneWidget);

    await tester.tap(find.text('Keep the last 1 hour'));
    await tester.pumpAndSettle();
    var rows = await db.getDeviceSamplesSince(
      tankId,
      now.subtract(const Duration(days: 1)),
    );
    expect([for (final row in rows) row.deviceIdentifier], ['recent']);

    await tester.tap(clearRow);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete everything'));
    await tester.pumpAndSettle();
    rows = await db.getDeviceSamplesSince(
      tankId,
      now.subtract(const Duration(days: 1)),
    );
    expect(rows, isEmpty);

    await unmountApp(tester);
  });
}
