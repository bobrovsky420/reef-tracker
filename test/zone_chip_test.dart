import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/domain/zones.dart';
import 'package:reeftracker/widgets/zone_chip.dart';

import 'support/pump.dart';

void main() {
  testWidgets('shows the localized label and the zone icon', (tester) async {
    await pumpApp(tester, const ZoneChip(Zone.green));
    expect(find.text('OK'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('amber uses its own label', (tester) async {
    await pumpApp(tester, const ZoneChip(Zone.amber));
    expect(find.text('Attention'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets('compact renders the icon only, without a label', (tester) async {
    await pumpApp(tester, const ZoneChip(Zone.red, compact: true));
    expect(find.byIcon(Icons.error), findsOneWidget);
    expect(find.text('Act now'), findsNothing);
  });
}
