import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// #48's convention, enforced instead of remembered: **every drag handle in the
/// app carries a `semanticLabel`** (a `Tooltip` would fight the drag gesture,
/// so the label on the icon is the only affordance a screen reader gets).
///
/// This is a source scan rather than a widget test on purpose — there are ten
/// reorderable lists across as many screens, and pumping each one to assert a
/// label would cost far more than reading the files. #78 was exactly the case
/// this catches: one list added later than the rest, silently missing the label.
void main() {
  /// Line comments are stripped before the paren scan below: a comment such as
  /// "draggable with a finger (the schedule-list convention)" would otherwise
  /// have to be balanced for the scan to find the right closing paren.
  String withoutLineComments(String source) => source
      .split('\n')
      .map((line) {
        final i = line.indexOf('//');
        return i == -1 ? line : line.substring(0, i);
      })
      .join('\n');

  /// The argument list of the `ReorderableDragStartListener(` starting at
  /// [open] (the index of its `(`), by paren balance.
  String argumentsAt(String source, int open) {
    var depth = 0;
    for (var i = open; i < source.length; i++) {
      if (source[i] == '(') depth++;
      if (source[i] == ')') {
        depth--;
        if (depth == 0) return source.substring(open, i + 1);
      }
    }
    return source.substring(open);
  }

  test('every ReorderableDragStartListener wraps a labelled icon', () {
    const marker = 'ReorderableDragStartListener(';
    final offenders = <String>[];

    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    for (final file in files) {
      final source = withoutLineComments(file.readAsStringSync());
      final lines = source.split('\n');
      for (var start = source.indexOf(marker); start != -1;) {
        final open = start + marker.length - 1;
        if (!argumentsAt(source, open).contains('semanticLabel:')) {
          final line = '\n'.allMatches(source.substring(0, start)).length + 1;
          offenders.add('${file.path}:$line');
        }
        start = source.indexOf(marker, open);
      }
      // Guards the scan itself: a file with handles must still have lines to
      // report against, i.e. the strip above didn't eat the source.
      expect(lines, isNotEmpty);
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Drag handles without a semanticLabel (use `l.reorder`): '
          '${offenders.join(', ')}',
    );
  });

  test('the scan actually finds the app\'s drag handles', () {
    // Without this, deleting the marker string (or breaking the walk) would
    // leave a test that passes by finding nothing at all.
    final count = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .map(
          (f) => 'ReorderableDragStartListener('
              .allMatches(f.readAsStringSync())
              .length,
        )
        .fold<int>(0, (a, b) => a + b);

    expect(count, greaterThanOrEqualTo(10));
  });
}
