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
}
