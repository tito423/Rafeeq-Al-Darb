/// Domain models for the Hadith library feature.

class HadithCollection {
  final String id;
  final String name;
  final int totalHadiths;

  const HadithCollection({
    required this.id,
    required this.name,
    required this.totalHadiths,
  });

  factory HadithCollection.fromMap(Map<String, dynamic> map) {
    return HadithCollection(
      id: map['id'] as String,
      name: map['name'] as String,
      totalHadiths: map['total_hadiths'] as int? ?? 0,
    );
  }

  /// Arabic display name for the collection
  String get nameAr {
    const map = {
      'bukhari': 'صحيح البخاري',
      'muslim': 'صحيح مسلم',
      'tirmidhi': 'جامع الترمذي',
      'abudawud': 'سنن أبي داود',
      'nasai': 'سنن النسائي',
      'ibnmajah': 'سنن ابن ماجه',
      'malik': 'موطأ مالك',
      'nawawi': 'الأربعون النووية',
      'qudsi': 'الأحاديث القدسية',
    };
    return map[id] ?? name;
  }

  /// Icon string (emoji) for the collection
  String get icon {
    const map = {
      'bukhari': '📗',
      'muslim': '📘',
      'tirmidhi': '📙',
      'abudawud': '📕',
      'nasai': '📓',
      'ibnmajah': '📔',
      'malik': '📒',
      'nawawi': '🌟',
      'qudsi': '✨',
    };
    return map[id] ?? '📖';
  }
}

class HadithChapter {
  final int id;
  final String collectionId;
  final String chapterId;
  final String name;
  final int? hadithFirst;
  final int? hadithLast;

  const HadithChapter({
    required this.id,
    required this.collectionId,
    required this.chapterId,
    required this.name,
    this.hadithFirst,
    this.hadithLast,
  });

  factory HadithChapter.fromMap(Map<String, dynamic> map) {
    return HadithChapter(
      id: map['id'] as int,
      collectionId: map['collection_id'] as String,
      chapterId: map['chapter_id'] as String,
      name: map['name'] as String,
      hadithFirst: map['hadith_first'] as int?,
      hadithLast: map['hadith_last'] as int?,
    );
  }

  int get hadithCount {
    if (hadithFirst != null && hadithLast != null) {
      return hadithLast! - hadithFirst! + 1;
    }
    return 0;
  }
}

class Hadith {
  final int id;
  final String collectionId;
  final String? chapterId;
  final int hadithNumber;
  final String? arabicNumber;
  final String textAr;
  final String? grade;
  final String? referenceBook;
  final String? referenceHadith;

  const Hadith({
    required this.id,
    required this.collectionId,
    this.chapterId,
    required this.hadithNumber,
    this.arabicNumber,
    required this.textAr,
    this.grade,
    this.referenceBook,
    this.referenceHadith,
  });

  factory Hadith.fromMap(Map<String, dynamic> map) {
    return Hadith(
      id: map['id'] as int,
      collectionId: map['collection_id'] as String,
      chapterId: map['chapter_id'] as String?,
      hadithNumber: map['hadith_number'] as int,
      arabicNumber: map['arabic_number'] as String?,
      textAr: map['text_ar'] as String,
      grade: map['grade'] as String?,
      referenceBook: map['reference_book'] as String?,
      referenceHadith: map['reference_hadith'] as String?,
    );
  }
}
