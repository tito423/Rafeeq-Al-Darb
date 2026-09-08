import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every locale file must carry the exact same set of keys. Adding a string to
/// one locale and forgetting the others is the classic i18n bug — this fails
/// the build instead of letting a raw `some.key` ship on screen.
void main() {
  const locales = ['ar', 'en', 'es', 'ru', 'pt', 'fr', 'ur'];

  Set<String> keysOf(String locale) {
    final raw = File('assets/translations/$locale.json').readAsStringSync();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final out = <String>{};
    void walk(Map<String, dynamic> node, String prefix) {
      node.forEach((k, v) {
        final dotted = prefix.isEmpty ? k : '$prefix.$k';
        if (v is Map<String, dynamic>) {
          walk(v, dotted);
        } else {
          out.add(dotted);
        }
      });
    }

    walk(json, '');
    return out;
  }

  test('all locales have identical key sets', () {
    final reference = keysOf('en');
    expect(reference, isNotEmpty);
    for (final locale in locales) {
      final keys = keysOf(locale);
      expect(
        keys.difference(reference),
        isEmpty,
        reason: '$locale.json has keys that en.json does not',
      );
      expect(
        reference.difference(keys),
        isEmpty,
        reason: '$locale.json is missing keys that en.json has',
      );
    }
  });

  test('no empty values', () {
    for (final locale in locales) {
      final raw = File('assets/translations/$locale.json').readAsStringSync();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      void walk(Map<String, dynamic> node, String prefix) {
        node.forEach((k, v) {
          final dotted = prefix.isEmpty ? k : '$prefix.$k';
          if (v is Map<String, dynamic>) {
            walk(v, dotted);
          } else {
            expect(v is String && v.trim().isNotEmpty, isTrue,
                reason: '$locale.json:$dotted is empty');
          }
        });
      }

      walk(json, '');
    }
  });
}
