import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The shipped quotes, checked against the rules that decided what could be
/// in them at all.
///
/// `scripts/build_quotes.py` extracts and `scripts/quotes_curated.py` curates
/// and translates. This enforces the rules on the file that actually ships,
/// because the three can drift: a hand edit, a rebuild from a changed source,
/// a filter loosened to get a bigger number. The rules are not stylistic —
///
///   * §1.1: every quote carries the book it came from. A saying with no
///     source is the thing this project refuses to ship, and the owner said
///     it again for this feature: «كل مقولة لازم تحمل اسم كتابها».
///   * §1.2: no Qur'anic ayah shown with no reference, and no prophetic
///     hadith shown with no grading. The first pass of the extractor shipped
///     both, and they were caught by reading the output rather than by any
///     test — hence this one.
///   * and since «ترجم كل اللي ينفع يترجم»: every quote in every one of the
///     seven languages, because a card that falls back to Arabic on a French
///     UI is the defect the translation was done to remove.
void main() {
  final doc = jsonDecode(File('assets/data/quotes.json').readAsStringSync())
      as Map<String, dynamic>;
  final books = (doc['books'] as List<dynamic>).cast<Map<String, dynamic>>();
  const langs = ['ar', 'en', 'es', 'fr', 'pt', 'ru', 'ur'];

  Map<String, String> textsOf(Map<String, dynamic> q) =>
      (q['t'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v as String));

  test('there are quotes, from more than one book', () {
    expect(doc['schema'], 2);
    expect(books.length, greaterThanOrEqualTo(2));
    final total =
        books.fold<int>(0, (n, b) => n + (b['quotes'] as List).length);
    // Fifty-eight, not the 359 the extractor produced. The extractor cannot
    // tell a maxim from the middle of an argument, and a card that opens on
    // «الفائدة الأولى: …» is a sentence with its head cut off. This is the
    // subset that stands alone — and every one of them is translated seven
    // ways, which is the other reason the number is what a person could read.
    expect(total, greaterThanOrEqualTo(50),
        reason: 'a rotating notification needs a corpus, not a handful');
  });

  test('every book names itself, its author and its printed edition', () {
    for (final b in books) {
      for (final field in ['id', 'titleAr', 'authorAr', 'sourceLabel']) {
        expect((b[field] as String?)?.trim() ?? '', isNotEmpty,
            reason: '${b['id']} has no $field');
      }
      // The edition line has to be the real one, not the bare book name.
      expect((b['sourceLabel'] as String).length, greaterThan(20),
          reason: '${b['id']}: sourceLabel is too short to be an edition');
    }
  });

  test('every quote exists in all seven languages', () {
    expect((doc['langs'] as List).cast<String>(), langs);
    for (final b in books) {
      for (final q in (b['quotes'] as List).cast<Map<String, dynamic>>()) {
        final t = textsOf(q);
        expect(t.keys.toSet(), langs.toSet(),
            reason: '${b['id']} p.${q['p']}');
        for (final lang in langs) {
          expect(t[lang]!.trim(), isNotEmpty,
              reason: '${b['id']} p.${q['p']} has an empty $lang');
        }
      }
    }
  });

  test('a translation is a translation, not a copy of the Arabic', () {
    for (final b in books) {
      for (final q in (b['quotes'] as List).cast<Map<String, dynamic>>()) {
        final t = textsOf(q);
        for (final lang in ['en', 'es', 'fr', 'pt', 'ru']) {
          expect(t[lang], isNot(t['ar']), reason: '${b['id']} $lang');
          // A Latin-script translation with Arabic letters in it is an
          // untranslated line that slipped through.
          expect(RegExp('[؀-ۿ]').hasMatch(t[lang]!), isFalse,
              reason: '${b['id']} p.${q['p']} $lang still has Arabic in it');
        }
        // Urdu is Arabic script, so the check for it is that it differs.
        expect(t['ur'], isNot(t['ar']), reason: '${b['id']} ur');
      }
    }
  });

  test('no quote carries an ayah, a hadith or an isnad', () {
    // The two typographic conventions the Shamela editions use, and the
    // words that mark somebody else's speech. Both were found by reading
    // real output: braces for Qur'an and doubled parens for hadith are what
    // the first pass shipped.
    const forbidden = [
      '{', '}', '﴿', '﴾', '((', '))',
      'قال رسول الله', 'صلى الله عليه وسلم', 'ﷺ', 'قال تعالى',
      'حدثنا', 'أخبرنا', 'أنبأنا',
    ];
    for (final b in books) {
      for (final q in (b['quotes'] as List).cast<Map<String, dynamic>>()) {
        final t = textsOf(q)['ar']!;
        for (final bad in forbidden) {
          expect(t.contains(bad), isFalse,
              reason: '${b['id']} p.${q['p']} contains "$bad": $t');
        }
      }
    }
  });

  test('every quote fits a card and is a whole fragment', () {
    for (final b in books) {
      for (final q in (b['quotes'] as List).cast<Map<String, dynamic>>()) {
        final t = textsOf(q);
        expect(t['ar']!.length, inInclusiveRange(70, 300),
            reason: '${b['id']} p.${q['p']}');
        for (final lang in langs) {
          expect(t[lang]!.trim(), t[lang],
              reason: 'untrimmed $lang: ${b['id']} p.${q['p']}');
          // A translation may run longer than its Arabic, but not by so much
          // that the card it was measured for cannot hold it.
          expect(t[lang]!.length, lessThanOrEqualTo(520),
              reason: '$lang too long for the card: ${b['id']} p.${q['p']}');
        }
        expect(q['p'], isA<int>());
      }
    }
  });

  test('no quote appears twice', () {
    final seen = <String>{};
    for (final b in books) {
      for (final q in (b['quotes'] as List).cast<Map<String, dynamic>>()) {
        final ar = textsOf(q)['ar']!;
        expect(seen.add(ar), isTrue, reason: 'duplicate in ${b['id']}: $ar');
      }
    }
  });
}
