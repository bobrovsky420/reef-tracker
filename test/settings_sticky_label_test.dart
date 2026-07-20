import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reeftracker/widgets/reef_settings.dart';

/// [ReefSettingsList]'s sticky section labels: a label pins at the top while
/// its section scrolls, paints an opaque fill only while rows pass beneath
/// it, and is pushed out (not left pinned) by the next section's label.
void main() {
  // ReefSettingsRow: minHeight 44 wins over 12+15+12 text content in the
  // test font.
  const rowHeight = 44.0;
  const rowsPerSection = 20;
  // M3-dialect (test default platform) label extent: 22 above + 10 below +
  // one 12 px * 1.4 text line.
  const labelExtent = 22.0 + 10.0 + 12.0 * 1.4;
  const sectionExtent = labelExtent + rowHeight * rowsPerSection;
  // The M3 inter-section divider: 1 px hairline + 8 px vertical margins.
  const dividerExtent = 17.0;

  Widget buildList(ScrollController controller) => MaterialApp(
    home: Scaffold(
      body: PrimaryScrollController(
        controller: controller,
        child: ReefSettingsList(
          sections: [
            for (final label in ['One', 'Two'])
              ReefSettingsSection(
                label: label,
                children: [
                  for (var i = 0; i < rowsPerSection; i++)
                    ReefSettingsRow(title: '$label row $i'),
                ],
              ),
          ],
        ),
      ),
    ),
  );

  Container labelContainer(WidgetTester tester, String label) =>
      tester.widget<Container>(
        find
            .ancestor(of: find.text(label), matching: find.byType(Container))
            .first,
      );

  Rect labelRect(WidgetTester tester, String label) => tester.getRect(
    find.ancestor(of: find.text(label), matching: find.byType(Container)).first,
  );

  testWidgets('label pins while its section scrolls', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(buildList(controller));

    // At rest: label in place at the top, no fill (gradient shows through).
    expect(labelRect(tester, 'ONE').top, 0.0);
    expect(labelContainer(tester, 'ONE').color, isNull);

    // Mid-section: still pinned at the top, now with an opaque fill over the
    // rows scrolling beneath.
    controller.jumpTo(400);
    await tester.pump();
    expect(labelRect(tester, 'ONE').top, moreOrLessEquals(0.0, epsilon: 0.01));
    expect(labelContainer(tester, 'ONE').color, isNotNull);
    expect(find.text('One row 9'), findsOneWidget);
  });

  testWidgets('next section pushes the pinned label out', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(buildList(controller));

    // Less than one label extent of section One remains on screen — its
    // pinned label must be partially pushed off the top by the group edge.
    controller.jumpTo(sectionExtent - labelExtent / 2);
    await tester.pump();
    expect(labelRect(tester, 'ONE').top, lessThan(0.0));

    // Fully past section One: its label is gone and Two pins in its place.
    controller.jumpTo(sectionExtent + dividerExtent + 100);
    await tester.pump();
    expect(find.text('ONE'), findsNothing);
    expect(labelRect(tester, 'TWO').top, moreOrLessEquals(0.0, epsilon: 0.01));
    expect(labelContainer(tester, 'TWO').color, isNotNull);
  });
}
