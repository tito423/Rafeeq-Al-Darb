import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// CLAUDE.md trap #23: in Dart, a backslash before `$` is an **escape**, not
/// an interpolation. `'j\$j'` is the literal text `j$j`, and
/// `flutter analyze` says nothing about it because it is a perfectly valid
/// string.
///
/// It cost this project eleven library books that shipped with
/// `'\${AppConfig.contentBaseUrl}/…'` as their URL — eight of them in v3.6.0.
/// It happened again while writing the khatma sheet: a Python generator wrote
/// `value: 'j\$j'` into a dropdown, which would have given all thirty juz the
/// same value and thrown at build time. Caught by reading the file, not by the
/// analyzer.
///
/// So: no source file may contain an escaped `$` unless it says why.
void main() {
  test('no accidentally escaped interpolation anywhere in lib/', () {
    final offenders = <String>[];
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (!line.contains(r'\$')) continue;
        final code = line.trimLeft();
        // A doc comment explaining the trap is not the trap.
        if (code.startsWith('//') || code.startsWith('///')) continue;
        // A deliberate escape says so on the line itself.
        if (line.contains('literal dollar')) continue;
        offenders.add('${f.path}:${i + 1}  ${code.trim()}');
      }
    }
    expect(offenders, isEmpty,
        reason: 'a backslash before \$ is an escape, not an interpolation — '
            'trap #23:\n${offenders.join("\n")}');
  });
}
