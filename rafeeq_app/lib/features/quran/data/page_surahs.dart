import '../../../core/db/models.dart';

/// Which surahs are actually **on** a mushaf page.
///
/// THE BUG THIS EXISTS FOR, reported by the owner with a photograph:
/// «الصورة بتاعة سورة يوسف مطلعه سورة هود وفوق على اليمين كاتب سورة يوسف».
///
/// The running header used to take "the last surah whose start page is at or
/// before the current page". On a page where one surah **ends** and the next
/// **begins** — which is most page boundaries in the mushaf — that names the
/// one that begins, even when every line the reader can see belongs to the one
/// that ends. His screenshot is page 235: the visible text is the close of Hud
/// (١١٩–١٢١, and the audio player reads 11:118), Yusuf begins lower down the
/// same page, and the header said Yusuf.
///
/// A page is not a surah. A surah is on page P when it starts at or before P
/// **and** the next surah starts at or after P — so a page carrying the end of
/// one and the start of another honestly names both.
///
/// Pulled out of `quran_screen.dart` so the rule can be tested against real
/// page numbers instead of being read and believed.
List<String> surahNamesOnPage({
  required List<Surah> surahs,
  required Map<int, int> startPages,
  required int page,
}) {
  final names = <String>[];
  for (var i = 0; i < surahs.length; i++) {
    final start = startPages[surahs[i].id] ?? 1;
    if (start > page) break;
    final nextStart =
        i + 1 < surahs.length ? (startPages[surahs[i + 1].id] ?? _far) : _far;
    if (nextStart >= page) names.add(surahs[i].nameAr);
  }
  // A page before the first recorded start (or a printing with no data at all)
  // still has to say something rather than nothing.
  if (names.isEmpty && surahs.isNotEmpty) names.add(surahs.first.nameAr);
  return names;
}

const int _far = 999999;
