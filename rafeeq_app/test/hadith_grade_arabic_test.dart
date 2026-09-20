import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/i18n/hadith_grade_i18n.dart';
import 'package:sqlite3/sqlite3.dart';

/// THE GAP THIS CLOSES.
///
/// On 2026-09-20 the owner opened the content-review site and said «انا عاوزه
/// عربي لان الشيوخ كلهم عرب». The hadith TEXT was Arabic, as it always is —
/// what was English was the **ruling**: `Sahih`, `Hasan Sahih`, `Al-Albani`,
/// `Darussalam`. Counted then: **23,058 of 45,219** rulings carried a Latin
/// letter, and that is what an Arabic reader saw inside the app too.
///
/// It is fair to ask how a full i18n audit missed it. Because every check
/// this project had ran the OTHER WAY:
///
///   * `ui_strings_translated_test` hunts **Arabic in Dart code** that should
///     have gone through `.tr()` — "Arabic must not reach a non-Arabic
///     reader". It has nothing to say about English reaching an Arabic one.
///   * `translation_parity_test` compares the seven locale FILES' key sets.
///   * `i18n_audit.txt` reported "UNTRANSLATED USER-VISIBLE STRINGS: 0" — and
///     it was right, by its own definition: it looks at source files.
///
/// None of them looks at what comes OUT OF THE DATABASE. The bundled data was
/// treated as content and content was assumed Arabic, which is true of the
/// hadith and false of the grading column: four of the nine books take their
/// rulings from an English-facing dataset, so the column is a transliteration
/// («صحيح» written `Sahih`), while Musnad Ahmad and ad-Darimi carry
/// al-Arna'ut's own Arabic («إسناده صحيح على شرط الشيخين»).
///
/// And `hadith_grade_i18n.dart` already existed — somebody had seen this once
/// and written a partial table. **No test measured its coverage**, so the
/// holes in it were invisible: a curly apostrophe (652 rows), a grader table
/// nothing read (18,047 rows), and a tail of spellings the source is not
/// consistent about.
///
/// So this test asks the only question that matters: take EVERY distinct
/// grade and grader in the bundled database, put it through the app's own
/// Arabic path, and require that not one Latin letter survives.
void main() {
  final dbFile = File('assets/data/hadith.db');

  test('every ruling in the bundled database renders in Arabic', () {
    if (!dbFile.existsSync()) {
      markTestSkipped('assets/data/hadith.db is not present (it is '
          'gitignored and regenerable); nothing to measure');
      return;
    }
    final db = sqlite3.open(dbFile.path, mode: OpenMode.readOnly);
    addTearDown(db.close);

    final latin = RegExp(r'[A-Za-z]');
    final offenders = <String, int>{};
    var graded = 0;

    for (final row in db.select(
        "SELECT grade, COUNT(*) AS n FROM hadiths "
        "WHERE grade IS NOT NULL AND grade <> '' GROUP BY grade")) {
      final n = row['n'] as int;
      graded += n;
      final ar = localizedHadithGrade(row['grade'] as String, 'ar');
      if (latin.hasMatch(ar)) offenders['grade: $ar'] = n;
    }
    for (final row in db.select(
        "SELECT grader, COUNT(*) AS n FROM hadiths "
        "WHERE grader IS NOT NULL AND grader <> '' GROUP BY grader")) {
      final ar = localizedHadithGrader(row['grader'] as String, 'ar');
      if (latin.hasMatch(ar)) offenders['grader: $ar'] = row['n'] as int;
    }

    expect(graded, greaterThan(40000),
        reason: 'the database really was read');
    expect(offenders, isEmpty,
        reason: 'these rulings still reach an Arabic reader in Latin script, '
            'with the number of hadiths behind each');
  });

  test('a non-Arabic locale is left alone, deliberately', () {
    // The file's own rule: Arabic gets the transliteration undone, every
    // other locale keeps the English term rather than being handed a guess
    // at Spanish or Russian hadith-science vocabulary.
    expect(localizedHadithGrade('Hasan Sahih', 'en'), 'Hasan Sahih');
    expect(localizedHadithGrader('Al-Albani', 'ru'), 'Al-Albani');
    expect(localizedHadithGrade('Hasan Sahih', 'ar'), 'حسن صحيح');
    expect(localizedHadithGrader('Al-Albani', 'ar'), 'الألباني');
  });

  test('the spellings the source is not consistent about all land', () {
    // Each of these is a real distinct value in the bundled database, and
    // each was English on an Arabic screen until 2026-09-20.
    for (final spelling in [
      "Da'if",
      'Da’if',
      'Daif',
      'Da if',
      'Da,if',
      'Da`if (Weak)',
      "Maudu'",
      'Maudu’',
      "Mawdu'",
      "Sahih Marfu'",
      'Sahih Mutawatir',
      "Da'if mursal",
    ]) {
      final ar = localizedHadithGrade(spelling, 'ar');
      expect(RegExp(r'[A-Za-z]').hasMatch(ar), isFalse,
          reason: '«$spelling» still reads «$ar»');
    }
  });
}
