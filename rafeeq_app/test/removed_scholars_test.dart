import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/library/data/book_catalog.dart';

/// The seven names the owner asked out of the app on 2026-09-17 stay out.
///
/// «فيه حوار جامد سالت فيه احد الشيوخ … فاحذفهم كلهم والقرني معاهم … اي حاجة
/// ابن باز داخل فيها شيلها يعني مش تخلي له اي حاجة في مصادرنا.»
///
/// WHAT THIS CHECKS. The places where **Rafeeq itself presents a name as an
/// authority**: a book on its shelf, a source on its Sources screen, a channel,
/// a site, a line of UI text.
///
/// WHAT IT DELIBERATELY DOES NOT. The hadith and tafsir corpora are untouched.
/// A classical text that narrates through a man, or a tafsir that mentions
/// him, is the source's own words, and §1.2 forbids rewriting those. It also
/// matters that «القرني» appears **96 times** in `tafseer_texts` and every one
/// of them is **أويس القرني**, the Tābiʿī — seven centuries from the man meant
/// here. A test matching the bare string across the databases would have
/// demanded the deletion of a different person entirely.
///
/// THE EXEMPTIONS ARE NAMED, NOT IMPLIED. Each one below is a specific string
/// in a specific place with a reason. Anything else fails — which is the point:
/// the list can only grow by someone writing down why.
void main() {
  const locales = ['ar', 'en', 'es', 'fr', 'pt', 'ru', 'ur'];

  /// Every spelling each name plausibly appears under in this repo's text.
  const names = <String, List<String>>{
    'ابن باز': ['ابن باز', 'بن باز', 'Ibn Baz', 'Bin Baz'],
    'ابن عثيمين': [
      'ابن عثيمين', 'بن عثيمين', 'العثيمين', 'Uthaymeen', 'Uthaimeen'
    ],
    'ابن تيمية': [
      'ابن تيمية', 'بن تيمية', 'ابن تيمي', 'Ibn Taymiyyah', 'Ibn Taymiyya',
      'Taymiyy'
    ],
    'ابن جبرين': ['ابن جبرين', 'بن جبرين', 'Jibreen', 'Jibrin'],
    'محمد بن عبد الوهاب': ['محمد بن عبد الوهاب', 'ابن عبد الوهاب'],
    'الألباني': ['الألباني', 'الالباني', 'al-Albani', 'Al-Albani', 'Albaani'],
    'عائض القرني': ['عائض القرني', 'عائض', 'Aaidh al-Qarni'],
  };

  /// **مكتبة ابن تيمية is a Cairo publishing house**, not the man. Four books
  /// in the library were printed by it, and `sourceLabel`'s job is to name the
  /// printing the text came from (§1.2). Deleting the publisher's name to
  /// satisfy a string search would make the provenance line *wrong*, which is
  /// a worse failure than the one being guarded against.
  ///
  /// The same word is stripped before matching, not whitelisted per book, so
  /// a *fifth* book from the same press passes too and a book actually
  /// **by** Ibn Taymiyyah still fails.
  const publishers = ['مكتبة ابن تيمية', 'دار ابن تيمية'];

  /// al-Albani's name survives in exactly two kinds of place, both of them
  /// **takhrij** — isnād criticism by a named critic, which CLAUDE.md §1.2
  /// requires the app to attribute («grade without grader is not
  /// acceptable»). The owner was shown the count — 4,898 gradings in
  /// `hadiths.grader` — and chose to keep the takhrij while removing the man
  /// from everywhere else.
  const takhrijExemptions = <String, String>{
    'sunan_suwar.source_kahf':
        'a hadith grading line: «صححه الألباني» on the Kahf hadith',
    'mishkat_al_masabih':
        'his edition of Mishkat IS a takhrij edition — he graded every hadith '
        'in it; naming the printing is what §1.2 requires',
  };

  String flatten(Object? node) {
    if (node is String) return node;
    if (node is Map) return node.values.map(flatten).join(' \u0000 ');
    if (node is List) return node.map(flatten).join(' \u0000 ');
    return '';
  }

  String stripPublishers(String s) {
    for (final p in publishers) {
      s = s.replaceAll(p, '«publisher»');
    }
    return s;
  }

  /// Comments are dropped before a Dart file is searched.
  ///
  /// A comment saying «this row was stale, it credited ابن باز, here is why it
  /// changed» is the record CLAUDE.md §2.4 asks for — the note that stops the
  /// next session putting it back. Failing the build over it would push the
  /// reasoning out of the file, which is the opposite of the intent. Only what
  /// ships to a reader is searched.
  String codeOnly(String s) => s
      .split('\n')
      .where((l) => !l.trimLeft().startsWith('//'))
      .join('\n');

  test('the exemptions are real, not stale', () {
    // An exemption that no longer describes anything is a licence nobody is
    // using, and the next reader would take it as a statement about the app.
    final ar = jsonDecode(File('assets/translations/ar.json').readAsStringSync())
        as Map<String, dynamic>;
    final kahf = (ar['sunan_suwar'] as Map<String, dynamic>)['source_kahf'];
    expect(kahf, contains('الألباني'),
        reason: 'the sunan_suwar.source_kahf exemption is stale — remove it');
    expect(libraryBookCatalog.any((b) => b.id == 'mishkat_al_masabih'), isTrue,
        reason: 'the mishkat exemption is stale — remove it');
  });

  for (final locale in locales) {
    test('$locale names none of the removed scholars', () {
      final json = jsonDecode(
          File('assets/translations/$locale.json').readAsStringSync())
          as Map<String, dynamic>;
      // Drop the one exempt block, then flatten the rest.
      final rest = Map<String, dynamic>.from(json)..remove('sunan_suwar');
      final text = stripPublishers(flatten(rest));
      for (final entry in names.entries) {
        for (final spelling in entry.value) {
          expect(text.contains(spelling), isFalse,
              reason: '$locale still says «$spelling». ${entry.key} was taken '
                  'out of the app on 2026-09-17 and nothing shown to a reader '
                  'may still attribute anything to him.');
        }
      }
    });
  }

  test('no library book is by one of them, or names one on its card', () {
    final offenders = <String>[];
    for (final b in libraryBookCatalog) {
      if (takhrijExemptions.containsKey(b.id)) continue;
      final card = stripPublishers([
        b.titleAr,
        b.titleEn,
        b.authorAr,
        b.authorEn,
        b.textEdition?.sourceLabel ?? '',
      ].join(' \u0000 '));
      for (final entry in names.entries) {
        for (final spelling in entry.value) {
          if (card.contains(spelling)) {
            offenders.add('${b.id} → ${entry.key} («$spelling»)');
          }
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'these catalogue entries still carry a removed name:\n'
            '${offenders.join('\n')}');
  });

  test('no book is AUTHORED by one of them', () {
    // Separate from the card check, and without the publisher strip: a press
    // named after a man can print anybody, but a book whose author field is
    // his is the thing that was removed.
    final offenders = <String>[];
    for (final b in libraryBookCatalog) {
      final who = '${b.authorAr} \u0000 ${b.authorEn}';
      for (final entry in names.entries) {
        for (final spelling in entry.value) {
          if (who.contains(spelling)) offenders.add('${b.id} → ${entry.key}');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('the Sources screen names none of them', () {
    // `sources_catalog.dart` credited «التحقيق والإيضاح — ابن باز» for the
    // Hajj guide long after the guide had moved onto النووي's «الإيضاح», so
    // the app named a book it read no word from. That is the shape of defect
    // this catches: a citation outliving the thing it cited.
    final src = stripPublishers(codeOnly(
        File('lib/features/settings/data/sources_catalog.dart')
            .readAsStringSync()));
    for (final entry in names.entries) {
      for (final spelling in entry.value) {
        expect(src.contains(spelling), isFalse,
            reason: 'sources_catalog.dart still lists «$spelling»');
      }
    }
  });

  test('the channel and website lists name none of them', () {
    for (final path in const [
      'lib/features/channels/data/islamic_channels.dart',
      'lib/features/library/data/islamic_websites.dart',
    ]) {
      final src = stripPublishers(codeOnly(File(path).readAsStringSync()));
      for (final entry in names.entries) {
        for (final spelling in entry.value) {
          expect(src.contains(spelling), isFalse,
              reason: '$path still names «$spelling»');
        }
      }
    }
  });
}
