import 'dart:convert';

class Surah {
  final int id;
  final String nameAr;
  final String nameEn;
  final String revelationType; // 'Meccan' | 'Medinan'
  final int ayahsCount;
  final int pageNumber; // start page, from first ayah

  const Surah({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.revelationType,
    required this.ayahsCount,
    required this.pageNumber,
  });

  bool get isMakki =>
      revelationType.toLowerCase().contains('mec') ||
      revelationType.toLowerCase().contains('مك');

  static String _fix(String text) {
    if (text.isEmpty) return text;
    try {
      return utf8.decode(text.codeUnits, allowMalformed: false);
    } catch (_) {
      return text;
    }
  }

  factory Surah.fromMap(Map<String, dynamic> m) => Surah(
        id: m['id'] as int,
        nameAr: _fix(m['name'] as String? ?? ''),
        nameEn: _fix(m['english_name'] as String? ?? ''),
        revelationType: _fix(m['revelation_type'] as String? ?? ''),
        ayahsCount: m['number_of_ayahs'] as int? ?? 0,
        pageNumber: m['page_number'] as int? ?? 1,
      );
}
