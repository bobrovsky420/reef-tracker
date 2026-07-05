import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/features/actions/action_markers.dart';

void main() {
  final t0 = DateTime(2026, 6, 1, 12);
  DateTime day(int d) => t0.add(Duration(days: d));
  double ms(DateTime t) => t.millisecondsSinceEpoch.toDouble();

  WaterChange water(int d) => WaterChange(id: d, tankId: 1, changedAt: day(d));
  CarbonChange carbon(int d) =>
      CarbonChange(id: d, tankId: 1, changedAt: day(d));
  EquipmentCleaning cleaning(int d) =>
      EquipmentCleaning(id: d, tankId: 1, cleanedAt: day(d));

  test('actionMarkers maps every log to its kind and timestamp', () {
    final markers = actionMarkers(
      waterChanges: [water(1)],
      carbonChanges: [carbon(2)],
      cleanings: [cleaning(3)],
    );
    expect(markers, hasLength(3));
    expect(markers[0].kind, ActionMarkerKind.waterChange);
    expect(markers[0].time, day(1));
    expect(markers[1].kind, ActionMarkerKind.carbonChange);
    expect(markers[1].time, day(2));
    expect(markers[2].kind, ActionMarkerKind.equipmentCleaning);
    expect(markers[2].time, day(3));
  });

  test('actionMarkerLines draws only markers inside the window, styled per '
      'kind', () {
    final markers = actionMarkers(
      waterChanges: [water(0), water(5)],
      carbonChanges: [carbon(2)],
      cleanings: [cleaning(10)],
    );
    final lines = actionMarkerLines(
      markers: markers,
      minX: ms(day(1)),
      maxX: ms(day(6)),
      color: (_) => Colors.black,
    );
    // water(0) and cleaning(10) fall outside the window.
    expect(lines, hasLength(2));
    expect(lines[0].x, ms(day(5)));
    expect(lines[0].dashArray, actionMarkerDash(ActionMarkerKind.waterChange));
    expect(lines[1].x, ms(day(2)));
    expect(lines[1].dashArray, actionMarkerDash(ActionMarkerKind.carbonChange));
  });

  test('dash patterns are pairwise distinct (color-blind separability)', () {
    final dashes = [
      for (final k in ActionMarkerKind.values) actionMarkerDash(k).join(','),
    ];
    expect(dashes.toSet(), hasLength(ActionMarkerKind.values.length));
  });

  test('actionMarkerKindsInWindow includes bounds and drops outsiders', () {
    final markers = actionMarkers(
      waterChanges: [water(1)],
      carbonChanges: [carbon(4)],
      cleanings: [cleaning(9)],
    );
    final kinds = actionMarkerKindsInWindow(markers, ms(day(1)), ms(day(4)));
    expect(kinds, {
      ActionMarkerKind.waterChange,
      ActionMarkerKind.carbonChange,
    });
    expect(
      actionMarkerKindsInWindow(markers, ms(day(20)), ms(day(30))),
      isEmpty,
    );
  });
}
