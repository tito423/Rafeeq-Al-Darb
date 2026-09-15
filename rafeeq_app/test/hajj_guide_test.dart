import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/hajj/data/hajj_guide.dart';

/// «مناسك الحج والعمرة» reads every step out of Ibn Baz's manual by paragraph
/// range, exactly as the Tajweed course reads its lessons. A wrong range puts
/// the tail of one rite under the next rite's title — on a subject where that
/// is not a cosmetic mistake.
///
/// The steps are deliberately NOT all in book order (the chapter on a child's
/// Hajj and the visitation chapters are moved to the end of the guide), so the
/// invariant is "no two steps share a paragraph", not "each starts after the
/// previous one".
void main() {
  (int, int) start(HajjStep s) => (s.fromPage, s.fromPara);
  (int, int) end(HajjStep s) => (s.toPage, s.toPara);
  bool before((int, int) a, (int, int) b) =>
      a.$1 < b.$1 || (a.$1 == b.$1 && a.$2 < b.$2);

  test('every step has a well-formed, forward range', () {
    expect(hajjSteps, isNotEmpty);
    for (final s in hajjSteps) {
      expect(s.fromPage, greaterThanOrEqualTo(0), reason: s.key);
      expect(s.fromPara, greaterThanOrEqualTo(0), reason: s.key);
      expect(s.toPara, greaterThanOrEqualTo(0), reason: s.key);
      expect(before(end(s), start(s)), isFalse,
          reason: '${s.key} ends before it starts');
    }
  });

  test('no two steps share a paragraph of the book', () {
    for (var i = 0; i < hajjSteps.length; i++) {
      for (var j = i + 1; j < hajjSteps.length; j++) {
        final a = hajjSteps[i];
        final b = hajjSteps[j];
        final disjoint = before(end(a), start(b)) || before(end(b), start(a));
        expect(disjoint, isTrue, reason: '${a.key} overlaps ${b.key}');
      }
    }
  });

  test('keys are unique, and every Umrah step is also a Hajj step', () {
    final keys = hajjSteps.map((s) => s.key).toList();
    expect(keys.toSet().length, keys.length);
    for (final s in hajjSteps) {
      expect(s.tracks, contains(HajjTrack.hajj), reason: s.key);
    }
    // Umrah is ihram, tawaf, sa'i and shaving or shortening; those four have
    // to be in its track or the Umrah view is not an Umrah.
    final umrah = hajjSteps
        .where((s) => s.tracks.contains(HajjTrack.umrah))
        .map((s) => s.key)
        .toSet();
    expect(umrah, containsAll(['ihram', 'tawaf', 'sai']));
  });

  test('every title and day label exists in all seven locales', () {
    const locales = ['ar', 'en', 'es', 'ru', 'pt', 'fr', 'ur'];
    final keys = <String>{
      for (final s in hajjSteps) 'hajj.step_${s.key}',
      for (final s in hajjSteps)
        if (s.dayKey != null) s.dayKey!,
    };
    for (final locale in locales) {
      final json = jsonDecode(
        File('assets/translations/$locale.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      for (final dotted in keys) {
        dynamic node = json;
        for (final part in dotted.split('.')) {
          expect(node, isA<Map<String, dynamic>>(),
              reason: '$locale.json: $dotted');
          node = (node as Map<String, dynamic>)[part];
        }
        expect(node, isA<String>(), reason: '$locale.json is missing $dotted');
        expect((node as String).trim(), isNotEmpty,
            reason: '$locale.json has an empty $dotted');
      }
    }
  });

  // Against the real book, when it has been built on this machine
  // (`py -3 scripts/build_ibn_baz_hajj_book.py`). The build output is not in
  // the repository, so on a clean checkout this is skipped rather than failed.
  final built = File('../scripts/book_text_build/$hajjGuideBook.json');
  test('every range lands on real paragraphs of the built book', () {
    final doc = jsonDecode(utf8.decode(gzip.decode(built.readAsBytesSync())))
        as Map<String, dynamic>;
    final paras = <int, int>{};
    for (final p in doc['pages'] as List) {
      final page = p as Map<String, dynamic>;
      paras[page['p'] as int] = (page['paras'] as List).length;
    }
    for (final s in hajjSteps) {
      expect(paras[s.fromPage], isNotNull, reason: '${s.key}: no page ${s.fromPage}');
      expect(s.fromPara, lessThan(paras[s.fromPage]!), reason: s.key);
      expect(paras[s.toPage], isNotNull, reason: '${s.key}: no page ${s.toPage}');
      expect(s.toPara, lessThan(paras[s.toPage]!), reason: s.key);
    }
  }, skip: built.existsSync() ? false : 'book not built on this machine');
}
