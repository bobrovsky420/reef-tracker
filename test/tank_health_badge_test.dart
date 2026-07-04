import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/domain/setup_type.dart';
import 'package:reeftracker/l10n/app_localizations.dart';
import 'package:reeftracker/l10n/l10n_helpers.dart';
import 'package:reeftracker/widgets/tank_health_badge.dart';

/// Widget tests for the tank-health badges (T13): hidden/empty states with no
/// data, the populated header, and the breakdown sheet it opens.
void main() {
  /// Bounded fake-time settle; see test/router_test.dart for why
  /// `pumpAndSettle` is off-limits (spinner animations never settle).
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Flushes drift's pending stream timers inside the test body; the binding's
  /// "Timer is still pending" check runs before `addTearDown` callbacks.
  Future<void> unmountApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<AppDatabase> pumpBadges(WidgetTester tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: Column(
              children: [TankHealthHeader(), TankHealthBadgeCompact()],
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    return db;
  }

  testWidgets('with no readings the header shows the empty state and the '
      'compact badge hides itself', (tester) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    final db = await pumpBadges(tester);
    await db.createTankWithPreset(name: 'A', type: SetupType.mixed);
    await settle(tester);

    expect(find.text('—'), findsOneWidget);
    expect(find.text(l.healthNoReadingsYet), findsOneWidget);
    // The compact app-bar badge renders nothing at all without data.
    expect(find.byType(InkResponse), findsNothing);
    await unmountApp(tester);
  });

  testWidgets('with a fresh reading both badges render and show a score', (
    tester,
  ) async {
    final db = await pumpBadges(tester);
    final tankId = await db.createTankWithPreset(
      name: 'A',
      type: SetupType.mixed,
    );
    await db.insertReading(
      tankId: tankId,
      paramKey: 'alkalinity',
      value: 8.0,
      takenAt: DateTime.now(),
    );
    await settle(tester);

    expect(find.text('—'), findsNothing);
    // The header ring now carries a numeric score.
    expect(find.textContaining(RegExp(r'^\d{1,3}$')), findsWidgets);
    expect(find.byType(InkResponse), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('tapping the header opens the breakdown sheet with the tracked '
      'parameters grouped', (tester) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    final db = await pumpBadges(tester);
    final tankId = await db.createTankWithPreset(
      name: 'A',
      type: SetupType.mixed,
    );
    await db.insertReading(
      tankId: tankId,
      paramKey: 'alkalinity',
      value: 8.0,
      takenAt: DateTime.now(),
    );
    await settle(tester);

    await tester.tap(find.byType(TankHealthHeader));
    await settle(tester);

    expect(find.text(l.healthTitle), findsOneWidget);
    // The scored parameter is listed by its localized name…
    expect(find.text(l.paramName('alkalinity')), findsOneWidget);
    // …and the untested preset parameters land in the stale section.
    expect(find.text(l.healthSectionStale.toUpperCase()), findsOneWidget);
    expect(find.text(l.healthNeverTested), findsWidgets);
    await unmountApp(tester);
  });
}
