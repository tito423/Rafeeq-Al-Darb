import '../../../core/db/models.dart';

/// Which surahs are actually **on** a mushaf page.
///
/// Two defects, both reported by the owner with a photograph.
///
/// 1. «الصورة بتاعة سورة يوسف مطلعه سورة هود وفوق على اليمين كاتب سورة يوسف».
///    The header used to take "the last surah whose start page is at or before
///    this page", which names Yusuf over the close of Hud on page 235.
///
/// 2. The fix for that assumed a surah always ends on the page where the next
///    one starts, and named the previous surah on every opening page: «كاتب في
///    الهيدر سورة الرعد سورة يوسف وهي الرعد بس». Measured against
///    `quran_local.db`: that is true at only **58 of the 113** boundaries. At
///    the other 55 the new surah opens at the top of a clean page — Yusuf ends
///    on 248 and al-Ra'd opens 249 — and the header named a surah that has no
///    verse on the page.
///
/// So the rule is read off the text itself: a surah is on page P when its
/// first verse is on or before P **and its last verse is on or after P**.
List<String> surahNamesOnPage({
  required List<Surah> surahs,
  required Map<int, int> startPages,
  required Map<int, int> endPages,
  required int page,
}) {
  final names = <String>[];
  for (final s in surahs) {
    final start = startPages[s.id];
    final end = endPages[s.id];
    if (start == null || end == null) continue;
    if (start <= page && page <= end) names.add(s.nameAr);
  }
  // A printing with no data at all still has to say something rather than
  // nothing.
  if (names.isEmpty && surahs.isNotEmpty) names.add(surahs.first.nameAr);
  return names;
}
