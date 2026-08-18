import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// #48's convention, enforced instead of remembered: **every drag handle in the
/// app carries a `semanticLabel`** (a `Tooltip` would fight the drag gesture,
/// so the label on the icon is the only affordance a screen reader gets).
///
/// This is a source scan rather than a widget test on purpose — the remaining
/// handle-driven lists span several screens, and pumping each one to assert a
/// label would cost far more than reading the files. Device cards use
/// whole-card delayed dragging instead, with their temporary badge covered by
/// `device_reorder_widget_test.dart`. #78 was exactly the case this catches: a
/// list added later than the rest, silently missing the label.
void main() {
  /// Line comments are stripped before the paren scan below: a comment such as
  /// "draggable with a finger (the schedule-list convention)" would otherwise
  /// have to be balanced for the scan to find the right closing paren.
  ///
  /// KNOWN LIMITATION (#116b): this is a lexical strip — a `//` *inside a
  /// string literal* truncates that line too, which can unbalance the paren
  /// scan. The per-handle balance guard in the test body turns that from a
  /// silent false pass into a loud failure at the offending site.
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
      for (var start = source.indexOf(marker); start != -1;) {
        final open = start + marker.length - 1;
        final args = argumentsAt(source, open);
        final line = '\n'.allMatches(source.substring(0, start)).length + 1;
        // Guards the scan itself (#116b): an unbalanced snippet means
        // `argumentsAt` ran off the end of the file — the comment strip ate
        // real code (a `//` inside a string literal) — and the
        // `semanticLabel:` check below would be matching against the rest of
        // the file rather than this handle's arguments.
        expect(
          args.endsWith(')'),
          isTrue,
          reason:
              'Unbalanced paren scan at ${file.path}:$line — '
              'a // inside a string literal upstream of this handle?',
        );
        if (!args.contains('semanticLabel:')) {
          offenders.add('${file.path}:$line');
        }
        start = source.indexOf(marker, open);
      }
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

    expect(count, greaterThanOrEqualTo(7));
  });
}
