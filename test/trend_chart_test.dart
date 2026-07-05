import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/domain/units.dart';
import 'package:reeftracker/l10n/app_localizations.dart';
import 'package:reeftracker/widgets/trend_chart.dart';

/// Direct widget tests for [TrendChart]'s U5c zoom/pan behavior (the rest of
/// the chart is exercised via the history/ratio screens in the router sweep).
void main() {
  const pres = ParamPresentation(
    unitLabel: 'dKH',
    decimals: 1,
    toDisplay: _identity,
    toCanonical: _identity,
  );

  List<Reading> readings() {
    final base = DateTime(2026, 6, 1, 9);
    const values = [8.6, 8.5, 8.3, 8.2, 8.0, 7.9, 7.7, 7.6];
    return [
      for (var i = 0; i < values.length; i++)
        Reading(
          id: i + 1,
          tankId: 1,
          paramKey: 'alkalinity',
          value: values[i],
          takenAt: base.add(Duration(days: i * 4)),
        ),
    ];
  }

  Future<void> pumpChart(WidgetTester tester, {required bool zoomable}) {
    return tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // Mirror the history screen's real environment: the chart lives in a
        // SliverToBoxAdapter inside a CustomScrollView (T14), whose drag
        // recognizers compete with the chart's scale gesture.
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 280,
                  child: TrendChart(
                    readings: readings(),
                    param: null,
                    pres: pres,
                    markers: const [],
                    zoomable: zoomable,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The set of bottom-axis date labels currently rendered.
  Set<String> dateLabels(WidgetTester tester) => {
    for (final t in tester.widgetList<Text>(find.byType(Text)))
      if (t.data != null && t.data!.contains('/')) t.data!,
  };

  /// Drives a horizontal two-finger pinch-out centered on the chart.
  Future<void> pinchOut(WidgetTester tester) async {
    final center = tester.getCenter(find.byType(LineChart));
    final a = await tester.createGesture();
    final b = await tester.createGesture();
    await a.down(center - const Offset(40, 0));
    await tester.pump(const Duration(milliseconds: 20));
    await b.down(center + const Offset(40, 0));
    await tester.pump(const Duration(milliseconds: 20));
    for (var i = 0; i < 12; i++) {
      await a.moveBy(const Offset(-10, 0));
      await b.moveBy(const Offset(10, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await a.up();
    await b.up();
    await tester.pump();
  }

  testWidgets('pinch-out zooms the time axis when zoomable', (tester) async {
    await pumpChart(tester, zoomable: true);
    final before = dateLabels(tester);
    expect(before, isNotEmpty);

    await pinchOut(tester);

    expect(
      dateLabels(tester),
      isNot(equals(before)),
      reason: 'zooming in must narrow the visible window (new date labels)',
    );
  });

  testWidgets('double-tap resets the zoom', (tester) async {
    await pumpChart(tester, zoomable: true);
    final initial = dateLabels(tester);

    await pinchOut(tester);
    expect(dateLabels(tester), isNot(equals(initial)));

    final center = tester.getCenter(find.byType(LineChart));
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 400));

    expect(dateLabels(tester), equals(initial));
  });

  testWidgets('pinch-out does nothing when not zoomable', (tester) async {
    await pumpChart(tester, zoomable: false);
    final before = dateLabels(tester);

    await pinchOut(tester);

    expect(dateLabels(tester), equals(before));
  });
}

double _identity(double v) => v;
