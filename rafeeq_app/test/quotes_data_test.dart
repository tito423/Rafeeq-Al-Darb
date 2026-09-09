import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The shipped quotes, checked against the rules that decided what could be
/// in them at all.
///
/// `scripts/build_quotes.py` enforces these when it builds the file. This
/// enforces them on the file that actually ships, because the two can drift:
/// a hand edit, a rebuild from a changed source, a filter loosened to get a
/// bigger number. The rules are not stylistic —
///
///   * §1.1: every quote carries the book it came from. A saying with no
///     source is the thing this project refuses to ship, and the owner said
///     it again for this feature: «كل مقولة لازم تحمل اسم كتابها».
///   * §1.2: no Qur'anic ayah shown with no reference, and no prophetic
///     hadith shown with no grading. The first pass of the extractor shipped
///     both, and they were caught by reading the output rather than by any
///     test — hence this one.
void main() {
  final doc = jsonDecode(File('assets/data/quotes.json').readAsStringSync())
      as Map<String, dynamic>;
  final books = (doc['books'] as List<dynamic>).cast<Map<String, dynamic>>();

  test('there are quotes, from more than one book', () {
    expect(books.length, greaterThanOrEqualTo(2));
    final total =
        books.fold<int>(0, (n, b) => n + (b['quotes'] as List).length);
    expect(total, greaterThan(100),
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
        final t = q['t'] as String;
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
        final t = q['t'] as String;
        expect(t.length, inInclusiveRange(70, 300),
            reason: '${b['id']} p.${q['p']}');
        expect(t.trim(), t, reason: 'untrimmed: ${b['id']} p.${q['p']}');
        expect(q['p'], isA<int>());
      }
    }
  });

  test('no quote appears twice', () {
    final seen = <String>{};
    for (final b in books) {
      for (final q in (b['quotes'] as List).cast<Map<String, dynamic>>()) {
        expect(seen.add(q['t'] as String), isTrue,
            reason: 'duplicate in ${b['id']}: ${q['t']}');
      }
    }
  });
}
