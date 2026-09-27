import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/dorar/data/dorar_encyclopedia.dart';
import 'package:rafeeq_app/features/dorar/data/dorar_search.dart';

/// Against the real aqeeda contents page (fixture of dorar.net/aqeeda).
void main() {
  final e = dorarEncyclopedias.firstWhere((x) => x.slug == 'aqeeda');
  final toc = parseDorarToc(
      utf8.decode(gzip.decode(
          File('test/fixtures/dorar_enc_aqeeda.html.gz').readAsBytesSync())),
      'aqeeda');
  final all = flattenDorarToc(e, toc);

  test('every section of the tree is searchable, with its folders', () {
    expect(all.length, greaterThan(100));
    expect(all.every((x) => x.$1.id > 0 && x.$1.title.isNotEmpty), isTrue);
    expect(all.where((x) => x.$1.path.isNotEmpty), isNotEmpty);
  });

  test('a section title finds that section first', () {
    for (final (hit, _) in all.take(40)) {
      final r = searchDorarSections(all, hit.title);
      expect(_norm(r.first.title), _norm(hit.title), reason: hit.title);
    }
  });

  test('a word finds sections; harakat and hamza do not matter', () {
    final r = searchDorarSections(all, 'التوحيد');
    expect(r, isNotEmpty);
    expect(searchDorarSections(all, 'التَّوْحِيد').length, r.length);
    expect(searchDorarSections(all, 'zzzz'), isEmpty);
    expect(searchDorarSections(all, '   '), isEmpty);
  });
}

String _norm(String s) => s.replaceAll(RegExp(r'[ً-ْ\s]'), '');
