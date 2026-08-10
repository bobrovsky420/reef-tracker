import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/domain/units.dart';
import 'package:reeftracker/l10n/app_localizations.dart';
import 'package:reeftracker/widgets/implausible_value_dialog.dart';

/// The three cases of the shared confirmation funnel that no other test
/// reaches. The skip / rail / value-line cases are already driven end-to-end
/// through the device dashboards in `devices_save_guards_test.dart:111-176`
/// and are deliberately not repeated here; what is left is what only a direct
/// pump can reach:
///
/// * dismissing the dialog by tapping the barrier — the answer must be
///   [SuspectChoice.cancel], not the `null` the dialog's future carries, which
///   a caller comparing against `SuspectChoice.save` would misread;
/// * the `allowSkip: false` labelling every non-device caller gets (manual
///   entry, the ICP/Hanna imports), where the left button abandons the save
///   rather than offering to drop the value;
/// * the explicit [SuspectValue.pres] path used by the history editor, whose
///   parameter carries a per-tank unit that the app preferences must not
///   override.
void main() {
  /// Pumps a single button that opens the dialog, and taps it. [answer] holds
  /// the dialog's result once the user has answered.
  Future<void> pumpAndOpen(
    WidgetTester tester, {
    required List<SuspectValue> values,
    required List<SuspectChoice?> answer,
    UnitPrefs? prefs,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  answer.add(
                    await showImplausibleValuesDialog(
                      ctx,
                      values: values,
                      prefs: prefs,
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Unusual values'), findsOneWidget);
  }

  testWidgets('dismissing the dialog by tapping outside it means cancel', (
    tester,
  ) async {
    final answer = <SuspectChoice?>[];
    await pumpAndOpen(
      tester,
      values: const [SuspectValue('temperature', 45)],
      answer: answer,
    );

    // The modal barrier fills the screen behind the dialog; the top-left
    // corner is never covered by the AlertDialog itself.
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    expect(find.text('Unusual values'), findsNothing);
    expect(answer, [
      SuspectChoice.cancel,
    ], reason: 'a dismissed dialog must not read as "save", nor stay null');
  });

  testWidgets('without allowSkip the left button cancels the whole save', (
    tester,
  ) async {
    final answer = <SuspectChoice?>[];
    await pumpAndOpen(
      tester,
      values: const [SuspectValue('temperature', 45)],
      answer: answer,
    );

    // "Skip" only exists for the bulk device save; a typed-in or imported
    // value is all-or-nothing.
    expect(find.widgetWithText(TextButton, 'Skip'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Save anyway'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(answer, [SuspectChoice.cancel]);
  });

  testWidgets('an explicit presentation renders the value and its typical '
      'range in that unit, overriding the preferences', (tester) async {
    // The history editor's case: its parameter carries a per-tank unit, so it
    // hands the dialog a ready-made presentation. Here it is Fahrenheit while
    // the app preferences say Celsius — the dialog must follow the former, and
    // must convert the plausible bounds through the same presentation (a raw
    // "typical 10.0–40.0 °F" would be the classic affine slip).
    final answer = <SuspectChoice?>[];
    await pumpAndOpen(
      tester,
      values: [
        SuspectValue(
          'temperature',
          45,
          pres: presentationForKey(
            'temperature',
            '°C',
            const UnitPrefs(temp: TempUnit.fahrenheit),
          ),
        ),
      ],
      prefs: const UnitPrefs(),
      answer: answer,
    );

    expect(
      find.text('Temperature: 113.0 °F (typical 50.0–104.0 °F)'),
      findsOneWidget,
    );
    expect(find.textContaining('°C'), findsNothing);

    // Control: the same value with no presentation supplied follows the
    // preferences instead, so the override above is what is being observed.
    // (Close the open dialog first — re-pumping the app reuses the same
    // Navigator, which would otherwise keep the dialog route on top.)
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    await pumpAndOpen(
      tester,
      values: const [SuspectValue('temperature', 45)],
      prefs: const UnitPrefs(),
      answer: answer,
    );
    expect(
      find.text('Temperature: 45.0 °C (typical 10.0–40.0 °C)'),
      findsOneWidget,
    );
  });
}
