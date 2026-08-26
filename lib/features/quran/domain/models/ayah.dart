import 'dart:convert';

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

  static String _fix(String text) {
    if (text.isEmpty) return text;
    // Check if it's likely gibberish (Latin-1 chars over 0x80)
    // Actually, just try to decode the codeUnits as UTF-8. If it fails, return as-is.
    try {
      return utf8.decode(text.codeUnits, allowMalformed: false);
    } catch (_) {
      return text;
    }
  }

  factory Ayah.fromMap(Map<String, dynamic> m) => Ayah(
        id: m['id'] as int? ?? 0,
        surahId: m['surah_number'] as int? ?? 1,
        ayahNumber: m['ayah_in_surah'] as int? ?? 1,
        textUthmani: _fix(m['text_uthmani'] as String? ?? ''),
        textClean: _fix(m['text_uthmani'] as String? ?? ''),
        pageNumber: m['page_number'] as int? ?? 1,
        juzNumber: m['juz_number'] as int? ?? 1,
        tafsir: _fix(m['tafsir'] as String? ?? ''),
        tafsirJalalayn: _fix(m['tafsir_jalalayn'] as String? ?? ''),
        translation: _fix(m['translation'] as String? ?? ''),
        wordMeanings: _fix(m['word_meanings'] as String? ?? ''),
        irab: _fix(m['irab'] as String? ?? ''),
        asbab: _fix(m['asbab'] as String? ?? ''),
      );

  String get sanitizedText {
    if (surahId == 1 || surahId == 9) return textUthmani;
    
    if (ayahNumber == 1) {
      final bismillahVariants = [
        'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ ',
        'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ ',
        'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ ',
        'بسم الله الرحمن الرحيم ',
        'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
        'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ',
        'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ',
        'بسم الله الرحمن الرحيم',
      ];
      
      String text = textUthmani;
      for (final b in bismillahVariants) {
        if (text.startsWith(b)) {
          text = text.substring(b.length).trim();
          break;
        }
      }
      
      // Sometimes it's appended with a special space or pause mark
      text = text.replaceFirst(RegExp(r'^[\s\u200F\u200E\u200D\u200C]+'), '');
      return text;
    }
    
    return textUthmani;
  }
}
