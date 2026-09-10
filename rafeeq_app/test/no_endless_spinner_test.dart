import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `if (!snapshot.hasData) return CircularProgressIndicator();` renders three
/// different states as "loading": still waiting, completed with an **error**,
/// and completed with null.
///
/// The owner met the second one and described it as «لما بفتح سنن النسائي
/// بتحمل على الفاضي ومش بتنزل حاجة» — from the outside, a failure and an
/// infinite load look identical. `FutureView` separates them.
///
/// This fails the build if the pattern comes back.
void main() {
  test('no screen renders a failed future as a spinner', () {
    final offenders = <String>[];
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        // The fix's own file quotes the pattern in its doc comment.
        .where((f) =>
            f.path.endsWith('.dart') &&
            !f.path.endsWith('future_view.dart'))) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!lines[i].contains('!snapshot.hasData')) continue;
        // Legitimate when the same builder already handles the error case
        // itself — look at the few lines around it before blaming.
        final around = lines
            .sublist((i - 6).clamp(0, i), (i + 3).clamp(0, lines.length))
            .join('\n');
        if (around.contains('hasError')) continue;
        offenders.add('${f.path}:${i + 1}');
      }
    }
    expect(offenders, isEmpty,
        reason: 'these turn a failed query into a permanent spinner with no '
            'message and no retry; use FutureView:\n${offenders.join("\n")}');
  });
}
