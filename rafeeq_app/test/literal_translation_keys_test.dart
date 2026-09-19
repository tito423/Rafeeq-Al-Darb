import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every key written as a literal - `'section.key'.tr()` - must exist.
///
/// `translation_parity_test` proves the seven files agree with EACH OTHER;
/// it cannot see a key the code asks for that none of them has. That is how
/// «common.ok» reached a phone as raw text on the reader's dialog button.
void main() {
  test('every literal .tr() key exists in the Arabic file', () {
    final ar = jsonDecode(File('assets/translations/ar.json').readAsStringSync())
        as Map<String, dynamic>;
    bool has(String key) {
      Object? node = ar;
      for (final part in key.split('.')) {
        if (node is! Map<String, dynamic> || !node.containsKey(part)) {
          return false;
        }
        node = node[part];
      }
      return node is String || node is Map;
    }

    final re = RegExp(r"""'([a-z][a-z0-9_]*(?:\.[a-z0-9_]+)+)'\s*\.\s*tr\(""");
    final missing = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      for (final m in re.allMatches(f.readAsStringSync())) {
        if (!has(m.group(1)!)) missing.add('${f.path}: ${m.group(1)}');
      }
    }
    expect(missing, isEmpty,
        reason: 'these render as the raw key on screen:\n${missing.join('\n')}');
  });
}
