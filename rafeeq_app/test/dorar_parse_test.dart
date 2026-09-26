import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/dorar/data/dorar_service.dart';

/// A real response of dorar.net/dorar_api.json («إنما الأعمال», fetched
/// 2026-09-26): 15 entries, every one with a named grader (one has «-»
/// as its NARRATOR, not its grader).
void main() {
  final result = (jsonDecode(File(
                  'test/fixtures/dorar_innama_al_amal_2026-09-26.json')
              .readAsStringSync()) as Map<String, dynamic>)['ahadith']['result']
      as String;
  final list = parseDorar(result);

  test('every grading shown names its grader', () {
    expect(list, isNotEmpty);
    expect(list.length, 15);
    for (final h in list) {
      expect(h.muhaddith, isNot(anyOf('', '-')));
      expect(h.text, isNotEmpty);
    }
  });

  test('fields are Dorar\'s own text', () {
    final first = list.first;
    // Compared with Dorar's own characters, not retyped ones: the harakat
    // order (shadda/fatha) of a retyped string need not match theirs.
    expect(first.text, contains('[يعني حديث:'));
    expect(result, contains(first.text.split(' ').first.substring(0, 2)));
    expect(first.rawi, 'أبو سعيد الخدري');
    expect(first.muhaddith, 'الدارقطني');
    expect(first.source, 'علل الدارقطني');
    expect(first.page, '2269');
    String bare(String t) => t.replaceAll(RegExp('[ً-ْ]'), '');
    expect(bare(first.grade), endsWith('وهو الصحيح.'));
    expect(list[1].grade, 'مرفوع وهو غير محفوظ');
  });
}
