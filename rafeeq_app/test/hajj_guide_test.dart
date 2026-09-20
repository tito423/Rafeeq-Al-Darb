import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/hajj/data/hajj_guide.dart';

/// «مناسك الحج والعمرة» reads every step out of al-Nawawi's الإيضاح by
/// paragraph range, exactly as the Tajweed course reads its lessons. A wrong
/// range puts the tail of one rite under the next rite's title — on a subject
/// where that is not a cosmetic mistake.
///
/// It read Ibn Baz's التحقيق والإيضاح until this session, and every range in
/// the file changed when the book did. That is why the last test here matters:
/// a page number that means one chapter in one printing means another in the
/// next, and nothing in Dart would notice.
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
      expect(
        before(end(s), start(s)),
        isFalse,
        reason: '${s.key} ends before it starts',
      );
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

  test('tracks keep their own chapters and shared rites in reading order', () {
    final keys = hajjSteps.map((s) => s.key).toList();
    expect(keys.toSet().length, keys.length);
    final hajj = hajjStepsFor(HajjTrack.hajj).map((s) => s.key).toList();
    final umrah = hajjStepsFor(HajjTrack.umrah).map((s) => s.key).toList();
    expect(hajj, isNot(contains('umrah')));
    expect(
      hajj,
      containsAllInOrder([
        'ihram',
        'tawaf',
        'sai',
        'arafah',
        'child',
        'counsel',
      ]),
    );
    expect(umrah, [
      'umrah',
      'preparation',
      'mawaqit',
      'ihram',
      'nusuk',
      'prohibitions',
      'tawaf',
      'sai',
      'visitation',
      'counsel',
    ]);
  });

  test('every title and day label exists in all seven locales', () {
    const locales = ['ar', 'en', 'es', 'ru', 'pt', 'fr', 'ur'];
    final keys = <String>{
      for (final s in hajjSteps) 'hajj.step_${s.key}',
      for (final s in hajjSteps)
        if (s.dayKey != null) s.dayKey!,
    };
    for (final locale in locales) {
      final json =
          jsonDecode(
                File('assets/translations/$locale.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      for (final dotted in keys) {
        dynamic node = json;
        for (final part in dotted.split('.')) {
          expect(
            node,
            isA<Map<String, dynamic>>(),
            reason: '$locale.json: $dotted',
          );
          node = (node as Map<String, dynamic>)[part];
        }
        expect(node, isA<String>(), reason: '$locale.json is missing $dotted');
        expect(
          (node as String).trim(),
          isNotEmpty,
          reason: '$locale.json has an empty $dotted',
        );
      }
    }
  });

  // Against the real book, when it has been built on this machine
  // (`py -3 scripts/build_book_text.py al_idah_fi_manasik_al_hajj_wal_umrah`).
  // The build output is not in the repository, so on a clean checkout this is
  // skipped rather than failed.
  final built = File('../scripts/book_text_build/$hajjGuideBook.json');
  test(
    'every range lands on real paragraphs of the built book',
    () {
      final doc =
          jsonDecode(utf8.decode(gzip.decode(built.readAsBytesSync())))
              as Map<String, dynamic>;
      final paras = <int, int>{};
      for (final p in doc['pages'] as List) {
        final page = p as Map<String, dynamic>;
        paras[page['p'] as int] = (page['paras'] as List).length;
      }
      for (final s in hajjSteps) {
        expect(
          paras[s.fromPage],
          isNotNull,
          reason: '${s.key}: no page ${s.fromPage}',
        );
        expect(s.fromPara, lessThan(paras[s.fromPage]!), reason: s.key);
        expect(
          paras[s.toPage],
          isNotNull,
          reason: '${s.key}: no page ${s.toPage}',
        );
        expect(s.toPara, lessThan(paras[s.toPage]!), reason: s.key);
      }
    },
    skip: built.existsSync() ? false : 'book not built on this machine',
  );
}
