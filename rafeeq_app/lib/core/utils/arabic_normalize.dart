/// Strips Arabic diacritics (tashkeel) and tatweel, and unifies alef/alef-
/// maksura letterform variants, so plain undiacritized user input can match
/// fully-vocalized Quranic/hadith text with a simple `.contains()`.
///
/// Found necessary live while building Stage 6's keyword search: both
/// `hadith.db`'s `arabic` column and `quran_local.db`'s `text_uthmani`
/// column are stored **fully diacritized** (e.g. "عُمَرَ", "ٱلرَّحْمَٰنِ" — the
/// latter also uses alef wasla U+0671, not plain alef). A plain
/// `LIKE '%عمر%'` — which is exactly what the LIKE-based fix for the missing
/// FTS5 module used at first — never matches ordinary user input, since the
/// diacritic marks sit *between* the letters and the alef forms differ.
/// Confirmed directly against the real downloaded `hadith.db` via sqlite3:
/// `SELECT COUNT(*) FROM hadiths WHERE arabic LIKE '%عمر%'` returned 0 even
/// though the very first hadith contains "عُمَرَ بْنَ الْخَطَّابِ". Normalizing both
/// sides before comparing fixes it.
///
/// Unicode escapes are used throughout (rather than literal combining
/// characters in the source) so the exact codepoints stripped are
/// unambiguous on review: U+0610-U+061A (Quranic honorific/annotation
/// signs), U+064B-U+065F (the harakat: fatha/damma/kasra/tanwin/
/// shadda/sukun + small Quranic marks), U+0670 (superscript alef),
/// U+06D6-U+06ED (further Quranic annotation/small marks), U+0640
/// (tatweel).
final RegExp _arabicDiacritics = RegExp(
  '[ؐ-ًؚ-ٰٟۖ-ۭـ]',
);

/// آ (U+0622) أ (U+0623) إ (U+0625) ٱ (U+0671) -> ا (U+0627)
final RegExp _alefVariants = RegExp('[آأإٱ]');

String normalizeArabic(String s) {
  var out = s.replaceAll(_arabicDiacritics, '');
  out = out.replaceAll(_alefVariants, 'ا');
  out = out.replaceAll('ى', 'ي'); // ى (alef maksura) -> ي
  return out;
}
