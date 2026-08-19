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

  factory Surah.fromMap(Map<String, dynamic> m) => Surah(
        id: m['id'] as int,
        nameAr: m['name'] as String? ?? '',
        nameEn: m['english_name'] as String? ?? '',
        revelationType: m['revelation_type'] as String? ?? '',
        ayahsCount: m['number_of_ayahs'] as int? ?? 0,
        pageNumber: m['page_number'] as int? ?? 1,
      );
}
