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
  (int, int) start(HajjTextRange r) => (r.fromPage, r.fromPara);
  (int, int) end(HajjTextRange r) => (r.toPage, r.toPara);
  bool before((int, int) a, (int, int) b) =>
      a.$1 < b.$1 || (a.$1 == b.$1 && a.$2 < b.$2);

  test('every step has a well-formed, forward range', () {
    expect(hajjSteps, isNotEmpty);
    for (final s in hajjSteps) {
      for (final range in s.textRanges) {
        expect(range.fromPage, greaterThanOrEqualTo(0), reason: s.key);
        expect(range.fromPara, greaterThanOrEqualTo(0), reason: s.key);
        expect(range.toPara, greaterThanOrEqualTo(0), reason: s.key);
        expect(
          before(end(range), start(range)),
          isFalse,
          reason: '${s.key} ends before it starts',
        );
      }
    }
  });

  test('no two steps in the same track share a source paragraph', () {
    for (final track in HajjTrack.values) {
      final entries = [
        for (final step in hajjStepsFor(track))
          for (final range in step.textRanges) (step.key, range),
      ];
      for (var i = 0; i < entries.length; i++) {
        for (var j = i + 1; j < entries.length; j++) {
          final a = entries[i];
          final b = entries[j];
          final disjoint =
              before(end(a.$2), start(b.$2)) || before(end(b.$2), start(a.$2));
          expect(disjoint, isTrue, reason: '${a.$1} overlaps ${b.$1}');
        }
      }
    }
  });

  test('Umrah follows only its chapter and its explicit shared references', () {
    final keys = hajjSteps.map((s) => s.key).toList();
    expect(keys.toSet().length, keys.length);
    final hajj = hajjStepsFor(HajjTrack.hajj).map((s) => s.key).toList();
    final umrah = hajjStepsFor(HajjTrack.umrah).map((s) => s.key).toList();
    expect(hajj, isNot(contains('umrah')));
    expect(hajj, containsAllInOrder(['ihram', 'tawaf', 'sai', 'arafah']));
    expect(umrah, [
      'umrah_obligation',
      'umrah_miqaat',
      'umrah_ihram',
      'umrah_prohibitions',
      'umrah_rites',
      'umrah_invalidating',
    ]);
    expect(hajj.toSet().intersection(umrah.toSet()), isEmpty);
    // al-Fiqh al-Manhaji (2026-09-23): the Umrah track is the chapter
    // «ثانياً: أعمال العمرة» (p.143:9-144) and what it rests on - the ruling
    // on Umrah, the miqats, the ihram, its prohibitions, and the Umrah path of
    // «كيف تحج؟», which ends at 184:7 («حلق شعره أو قصره، وقد انتهى من
    // عمرته»). Nothing about the days of Hajj may appear in it: the
    // obligations of Muzdalifah, stoning and Mina (pp. 136-139), Arafah
    // (p.140:0-4), the outings from 8 Dhu al-Hijjah (pp. 149:5-153) and the
    // Hajj path from 184:8 on.
    bool hajjDays(int page, int para) =>
        (page >= 136 && page <= 139) ||
        (page == 140 && para <= 4) ||
        (page == 149 && para >= 5) ||
        (page >= 150 && page <= 153) ||
        (page == 184 && para >= 8) ||
        page >= 185;
    for (final step in hajjStepsFor(HajjTrack.umrah)) {
      for (final r in step.textRanges) {
        expect(hajjDays(r.fromPage, r.fromPara), isFalse, reason: step.key);
        expect(hajjDays(r.toPage, r.toPara), isFalse, reason: step.key);
      }
    }
  });

  test('every title and day label exists in all seven locales', () {
    const locales = ['ar', 'en', 'es', 'ru', 'pt', 'fr', 'ur'];
    final keys = <String>{
      for (final s in hajjSteps) 'hajj.step_${s.key}',
      for (final s in hajjSteps) 'hajj.desc_${s.key}',
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
        for (final range in s.textRanges) {
          expect(
            paras[range.fromPage],
            isNotNull,
            reason: '${s.key}: no page ${range.fromPage}',
          );
          expect(
            range.fromPara,
            lessThan(paras[range.fromPage]!),
            reason: s.key,
          );
          expect(
            paras[range.toPage],
            isNotNull,
            reason: '${s.key}: no page ${range.toPage}',
          );
          expect(range.toPara, lessThan(paras[range.toPage]!), reason: s.key);
        }
      }
    },
    skip: built.existsSync() ? false : 'book not built on this machine',
  );
}
