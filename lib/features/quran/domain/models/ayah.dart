class Ayah {
  final int id;
  final int surahId;
  final int ayahNumber;
  final String textUthmani;
  final String textClean;
  final int pageNumber;
  final int juzNumber;

  final String tafsir;
  final String tafsirJalalayn;
  final String translation;
  final String wordMeanings;
  final String irab;
  final String asbab;

  const Ayah({
    required this.id,
    required this.surahId,
    required this.ayahNumber,
    required this.textUthmani,
    this.textClean = '',
    this.pageNumber = 1,
    this.juzNumber = 1,
    this.tafsir = '',
    this.tafsirJalalayn = '',
    this.translation = '',
    this.wordMeanings = '',
    this.irab = '',
    this.asbab = '',
  });

  factory Ayah.fromMap(Map<String, dynamic> m) => Ayah(
        id: m['id'] as int? ?? 0,
        surahId: m['surah_number'] as int? ?? 1,
        ayahNumber: m['ayah_in_surah'] as int? ?? 1,
        textUthmani: m['text_uthmani'] as String? ?? '',
        textClean: m['text_uthmani'] as String? ?? '',
        pageNumber: m['page_number'] as int? ?? 1,
        juzNumber: m['juz_number'] as int? ?? 1,
        tafsir: m['tafsir'] as String? ?? '',
        tafsirJalalayn: m['tafsir_jalalayn'] as String? ?? '',
        translation: m['translation'] as String? ?? '',
        wordMeanings: m['word_meanings'] as String? ?? '',
        irab: m['irab'] as String? ?? '',
        asbab: m['asbab'] as String? ?? '',
      );
}
