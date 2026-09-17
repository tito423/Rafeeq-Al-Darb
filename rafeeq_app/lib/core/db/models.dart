import 'package:easy_localization/easy_localization.dart';

class Surah {
  final int id;
  final String nameAr;
  final String nameEn;
  final String revelationType;
  final int ayahsCount;

  const Surah({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.revelationType,
    required this.ayahsCount,
  });

  factory Surah.fromRow(Map<String, Object?> row) => Surah(
        id: row['id'] as int,
        nameAr: row['name_ar'] as String? ?? '',
        nameEn: row['name_en'] as String? ?? '',
        revelationType: row['revelation_type'] as String? ?? '',
        ayahsCount: row['ayahs_count'] as int? ?? 0,
      );
}

class Ayah {
  final int id;
  final int surahId;
  final int ayahNumber;
  final String textUthmani;
  final int pageNumber;
  final int juzNumber;

  const Ayah({
    required this.id,
    required this.surahId,
    required this.ayahNumber,
    required this.textUthmani,
    required this.pageNumber,
    required this.juzNumber,
  });

  factory Ayah.fromRow(Map<String, Object?> row) => Ayah(
        id: row['id'] as int,
        surahId: row['surah_id'] as int,
        ayahNumber: row['ayah_number'] as int,
        textUthmani: row['text_uthmani'] as String? ?? '',
        pageNumber: row['page_number'] as int? ?? 1,
        juzNumber: row['juz_number'] as int? ?? 1,
      );
}

class TafsirText {
  final String source;
  final int surah;
  final int ayahStart;
  final int ayahEnd;
  final String text;

  const TafsirText({
    required this.source,
    required this.surah,
    required this.ayahStart,
    required this.ayahEnd,
    required this.text,
  });

  factory TafsirText.fromRow(Map<String, Object?> row) => TafsirText(
        source: row['source'] as String,
        surah: row['surah'] as int,
        ayahStart: row['ayah_start'] as int,
        ayahEnd: row['ayah_end'] as int,
        text: row['text'] as String,
      );
}

class WordMeaning {
  final int pos;
  final String en;

  const WordMeaning({required this.pos, required this.en});

  factory WordMeaning.fromRow(Map<String, Object?> row) => WordMeaning(
        pos: row['pos'] as int,
        en: row['en'] as String? ?? '',
      );
}

class WordGrammar {
  final int pos;
  final String token;
  final String posAr;
  final String caseAr;
  final String root;
  final String lemma;

  const WordGrammar({
    required this.pos,
    required this.token,
    required this.posAr,
    required this.caseAr,
    required this.root,
    required this.lemma,
  });

  factory WordGrammar.fromRow(Map<String, Object?> row) => WordGrammar(
        pos: row['pos'] as int,
        token: row['token'] as String? ?? '',
        posAr: row['pos_ar'] as String? ?? '',
        caseAr: row['case_ar'] as String? ?? '',
        root: row['root'] as String? ?? '',
        lemma: row['lemma'] as String? ?? '',
      );
}

class AzkarSection {
  final int id;

  /// an-Nawawi's own chapter heading, verbatim, in Arabic.
  final String title;

  const AzkarSection({required this.id, required this.title});

  factory AzkarSection.fromRow(Map<String, Object?> row) => AzkarSection(
        id: row['id'] as int,
        title: row['title'] as String? ?? '',
      );

  /// What the chapter is called **in the reader's language**.
  ///
  /// THE DEFECT THIS EXISTS FOR. `azkar_screen.dart` and
  /// `azkar_section_screen.dart` both drew [title] straight from the database,
  /// so a reader who had chosen English, French or Russian got an Arabic list
  /// and an Arabic app bar. That is the owner's standing rule — «مش ينفع تعرض
  /// بالعربي واللغة المختارة إنجليزي» — in a place the v3.29.0 and v3.30.0
  /// passes never reached, and it stayed there because fixing it meant
  /// translating 134 titles of a book that was about to be replaced.
  ///
  /// The book is replaced now: 18 chapters, keyed `azkar.section.<id>`. A
  /// missing key would render as the raw key on screen (CLAUDE.md trap #8), so
  /// this falls back to an-Nawawi's Arabic rather than to «azkar.section.7» —
  /// and `azkar_section_titles_test.dart` fails the build if a key is absent
  /// from any of the seven locales, so the fallback should never be reached.
  String localizedTitle() {
    final key = 'azkar.section.$id';
    final translated = key.tr();
    return translated == key ? title : translated;
  }
}

class AzkarItem {
  final int id;
  final int sectionId;
  final String body;
  final String footnote;

  const AzkarItem({
    required this.id,
    required this.sectionId,
    required this.body,
    required this.footnote,
  });

  factory AzkarItem.fromRow(Map<String, Object?> row) => AzkarItem(
        id: row['id'] as int,
        sectionId: row['section_id'] as int,
        body: row['body'] as String? ?? '',
        footnote: row['footnote'] as String? ?? '',
      );
}

class HadithCollection {
  final String id;
  final String name;
  final int totalHadiths;

  const HadithCollection({
    required this.id,
    required this.name,
    required this.totalHadiths,
  });

  factory HadithCollection.fromRow(Map<String, Object?> row) =>
      HadithCollection(
        id: row['id'] as String,
        name: row['name'] as String? ?? '',
        totalHadiths: row['total_hadiths'] as int? ?? 0,
      );
}

class HadithChapter {
  final String chapterId;
  final String name;
  final int hadithFirst;
  final int hadithLast;

  const HadithChapter({
    required this.chapterId,
    required this.name,
    required this.hadithFirst,
    required this.hadithLast,
  });

  factory HadithChapter.fromRow(Map<String, Object?> row) => HadithChapter(
        chapterId: row['chapter_id'] as String? ?? '',
        name: row['name'] as String? ?? '',
        hadithFirst: row['hadith_first'] as int? ?? 0,
        hadithLast: row['hadith_last'] as int? ?? 0,
      );
}

class Hadith {
  final int id;
  final String collectionId;
  final int hadithNumber;
  final String textAr;
  final String grade;

  const Hadith({
    required this.id,
    required this.collectionId,
    required this.hadithNumber,
    required this.textAr,
    required this.grade,
  });

  factory Hadith.fromRow(Map<String, Object?> row) => Hadith(
        id: row['id'] as int,
        collectionId: row['collection_id'] as String? ?? '',
        hadithNumber: row['hadith_number'] as int? ?? 0,
        textAr: row['text_ar'] as String? ?? '',
        grade: row['grade'] as String? ?? '',
      );
}
