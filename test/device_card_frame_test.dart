import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/features/devices/device_card_frame.dart';

void main() {
  testWidgets('shared device frame owns title, menu, body, and semantics', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DeviceCardFrame(
            title: 'Salinity meter',
            menuItems: const [
              PopupMenuItem(value: 'rename', child: Text('Rename')),
            ],
            onMenuSelected: (value) => selected = value,
            body: const Text('1.026 SG'),
          ),
        ),
      ),
    );

    expect(find.text('Salinity meter'), findsOneWidget);
    expect(find.text('1.026 SG'), findsOneWidget);
    final semantics = tester.getSemantics(find.text('Salinity meter'));
    expect(semantics.flagsCollection.isHeader, isTrue);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    expect(selected, 'rename');
  });

  testWidgets('shared device frame normalizes loading and error states', (
    tester,
  ) async {
    Widget frame({bool loading = false, String? error}) => MaterialApp(
      home: Scaffold(
        body: DeviceCardFrame(
          title: 'Controller',
          menuItems: const [],
          onMenuSelected: (_) {},
          loading: loading,
          errorText: error,
          body: const Text('live body'),
        ),
      ),
    );

    await tester.pumpWidget(frame(loading: true));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('live body'), findsNothing);

    await tester.pumpWidget(frame(error: 'Could not connect'));
    expect(find.text('Could not connect'), findsOneWidget);
    expect(find.text('live body'), findsNothing);
  });
}
