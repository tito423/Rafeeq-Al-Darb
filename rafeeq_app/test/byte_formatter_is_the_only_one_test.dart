import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/utils/byte_formatter.dart';

/// CLAUDE.md trap #16, pinned.
///
/// «60.5 MB» rendered as «MB 60.5» on every size label in the app, because a
/// numeral is bidi-weak and takes its direction from what surrounds it. There
/// were **five** copies of the formatter and every one of them had the same
/// bug. `byte_formatter.dart` was written to be the only one — and then a
/// sixth appeared anyway, in `QuranTranslationInfo.sizeLabel`, built by hand
/// and missing the same left-to-right isolate.
///
/// So the invariant is a test now, not a note.
void main() {
  test('nothing builds its own byte label', () {
    // A string literal that is a bare unit right after an interpolation or a
    // number — `'$x MB'`, `'${...} KB'` — is the shape of the bug.
    final offenders = <String>[];
    final pattern = RegExp(r"""(\}|[0-9])\s*(B|KB|MB|GB)'""");
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      if (f.path.endsWith('byte_formatter.dart')) continue;
      for (final line in f.readAsLinesSync()) {
        final code = line.trimLeft();
        if (code.startsWith('//') || code.startsWith('///')) continue;
        if (pattern.hasMatch(line)) offenders.add('${f.path}: $line');
      }
    }
    expect(offenders, isEmpty,
        reason: 'use formatBytes/formatBytesBinary — a hand-built size label '
            'has no LTR isolate and reverses in Arabic:\n'
            '${offenders.join("\n")}');
  });

  test('a size is wrapped so it cannot reverse in an Arabic paragraph', () {
    // U+2066 LEFT-TO-RIGHT ISOLATE … U+2069 POP DIRECTIONAL ISOLATE.
    for (final s in [
      formatBytes(512),
      formatBytes(1500),
      formatBytes(12626797),
      formatBytesBinary(2307544),
    ]) {
      expect(s.codeUnitAt(0), 0x2066, reason: s);
      expect(s.codeUnitAt(s.length - 1), 0x2069, reason: s);
    }
  });

  test('the decimal and binary formatters disagree, on purpose', () {
    // 1,048,576 bytes is «1.0 MB» binary and «1.0 MB» decimal only by
    // coincidence of rounding; 1,500,000 separates them, and the Downloads
    // screen must keep agreeing with Android's own storage figures.
    expect(formatBytes(1500000), contains('1.5 MB'));
    expect(formatBytesBinary(1500000), contains('1.4 MB'));
  });
}
