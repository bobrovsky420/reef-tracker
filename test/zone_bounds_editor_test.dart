import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/domain/zones.dart';
import 'package:reeftracker/l10n/app_localizations.dart';
import 'package:reeftracker/widgets/zone_bounds_editor.dart';

import 'support/pump.dart';

/// Widget tests for [ZoneBoundsEditor] (T13): field seeding, parsing back via
/// [ZoneBoundsEditorState.values], and the `orderOk`/`pairsOk` invariants the
/// parent editors rely on to block invalid bounds before they reach the DB.
void main() {
  final editorKey = GlobalKey<ZoneBoundsEditorState>();
  final formKey = GlobalKey<FormState>();

  /// The four bound fields in render order:
  /// amberLow, greenLow, greenHigh, amberHigh.
  Finder field(int index) => find.byType(TextFormField).at(index);

  Future<void> pumpEditor(
    WidgetTester tester, {
    ZoneBounds initial = const ZoneBounds(),
  }) {
    return pumpApp(
      tester,
      SingleChildScrollView(
        child: Form(
          key: formKey,
          child: ZoneBoundsEditor(
            key: editorKey,
            initial: initial,
            format: (v) => v.toString(),
          ),
        ),
      ),
    );
  }

  testWidgets('seeds fields from initial bounds and parses them back', (
    tester,
  ) async {
    await pumpEditor(
      tester,
      initial: const ZoneBounds(
        amberLow: 7,
        greenLow: 7.5,
        greenHigh: 8.5,
        amberHigh: 9,
      ),
    );

    expect(find.text('7.0'), findsOneWidget);
    expect(find.text('7.5'), findsOneWidget);
    expect(find.text('8.5'), findsOneWidget);
    expect(find.text('9.0'), findsOneWidget);

    final values = editorKey.currentState!.values;
    expect(values.amberLow, 7);
    expect(values.greenLow, 7.5);
    expect(values.greenHigh, 8.5);
    expect(values.amberHigh, 9);
    expect(editorKey.currentState!.orderOk, isTrue);
    expect(editorKey.currentState!.pairsOk, isTrue);
  });

  testWidgets('blank fields parse to null and stay valid', (tester) async {
    await pumpEditor(tester);

    final values = editorKey.currentState!.values;
    expect(values.amberLow, isNull);
    expect(values.greenLow, isNull);
    expect(values.greenHigh, isNull);
    expect(values.amberHigh, isNull);
    // No bounds at all is a legal configuration (parameter with no zones).
    expect(editorKey.currentState!.orderOk, isTrue);
    expect(editorKey.currentState!.pairsOk, isTrue);
    expect(formKey.currentState!.validate(), isTrue);
  });

  testWidgets('orderOk rejects out-of-order bounds, also across blanks', (
    tester,
  ) async {
    await pumpEditor(tester);

    // greenLow above greenHigh.
    await tester.enterText(field(1), '9');
    await tester.enterText(field(2), '8');
    expect(editorKey.currentState!.orderOk, isFalse);

    // Fixing the order makes it valid again.
    await tester.enterText(field(2), '10');
    expect(editorKey.currentState!.orderOk, isTrue);

    // The check skips blanks: amberLow vs amberHigh with empty greens.
    await tester.enterText(field(1), '');
    await tester.enterText(field(2), '');
    await tester.enterText(field(0), '5');
    await tester.enterText(field(3), '4');
    expect(editorKey.currentState!.orderOk, isFalse);
  });

  testWidgets('pairsOk requires the matching green bound for each amber', (
    tester,
  ) async {
    await pumpEditor(tester);

    await tester.enterText(field(0), '5'); // amberLow without greenLow
    expect(editorKey.currentState!.pairsOk, isFalse);
    await tester.enterText(field(1), '6');
    expect(editorKey.currentState!.pairsOk, isTrue);

    await tester.enterText(field(3), '9'); // amberHigh without greenHigh
    expect(editorKey.currentState!.pairsOk, isFalse);
    await tester.enterText(field(2), '8');
    expect(editorKey.currentState!.pairsOk, isTrue);
  });

  testWidgets('non-numeric input fails form validation with the localized '
      'message', (tester) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    await pumpEditor(tester);

    await tester.enterText(field(1), 'abc');
    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text(l.enterANumber), findsOneWidget);

    await tester.enterText(field(1), '7.5');
    expect(formKey.currentState!.validate(), isTrue);
  });
}
