import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/l10n/l10n_helpers.dart';

import 'support/pump.dart';

void main() {
  final initial = DateTime(2026, 6, 1, 10, 30);

  /// Pumps a button that runs [pickPastDateTime] and records its result.
  Future<void Function()> pumpPicker(
    WidgetTester tester,
    void Function(DateTime? result) onResult,
  ) async {
    late void Function() open;
    await pumpApp(
      tester,
      Builder(
        builder: (context) {
          open = () async => onResult(await pickPastDateTime(context, initial));
          return TextButton(onPressed: open, child: const Text('pick'));
        },
      ),
    );
    return open;
  }

  testWidgets('confirming both steps returns the composed date and time', (
    tester,
  ) async {
    DateTime? result;
    var completed = false;
    await pumpPicker(tester, (r) {
      result = r;
      completed = true;
    });

    await tester.tap(find.text('pick'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK')); // date step
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK')); // time step
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(result, initial);
  });

  testWidgets('cancelling the time step aborts instead of recording midnight', (
    tester,
  ) async {
    DateTime? result;
    var completed = false;
    await pumpPicker(tester, (r) {
      result = r;
      completed = true;
    });

    await tester.tap(find.text('pick'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK')); // confirm the date step
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel')); // cancel the time step (#16)
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(result, isNull);
  });
}
