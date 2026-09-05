/// Strips Arabic diacritics (tashkeel) and tatweel, and unifies alef/alef-
/// maksura letterform variants, so plain undiacritized user input can match
/// fully-vocalized Quranic/hadith text with a simple `.contains()`.
///
/// Found necessary live while building Stage 6's keyword search: both
/// `hadith.db`'s `arabic` column and `quran_local.db`'s `text_uthmani`
/// column are stored **fully diacritized** (e.g. "عُمَرَ", "ٱلرَّحْمَٰنِ" — the
/// latter also uses alef wasla U+0671, not plain alef). A plain
/// `LIKE '%عمر%'` — which is exactly what the LIKE-based fix for the missing
/// FTS5 module used at first — never matches ordinary user input, since the
/// diacritic marks sit *between* the letters and the alef forms differ.
/// Confirmed directly against the real downloaded `hadith.db` via sqlite3:
/// `SELECT COUNT(*) FROM hadiths WHERE arabic LIKE '%عمر%'` returned 0 even
/// though the very first hadith contains "عُمَرَ بْنَ الْخَطَّابِ". Normalizing both
/// sides before comparing fixes it.
///
/// **A real bug found + fixed (P3‑9), caught via a live search the owner
/// reported returning nothing for "فاسقين":** U+0670 (the superscript
/// alef / "dagger alif", e.g. the mark inside "ٱلْفَٰسِقِينَ") used to sit in
/// the *stripped* class below, alongside real diacritics like fatha/kasra/
/// sukun. But a dagger alif isn't decoration — for most words it **is** the
/// "ا" of the word in Quranic Uthmani spelling (Qur'anic orthography omits
/// the full alef letter in these words and writes this small mark instead).
/// Stripping it to nothing turned "فَٰسِقِينَ" into "فسقين" (the ا silently
/// vanished), so a search for the correctly-spelled "فاسقين" could never
/// match it — confirmed directly against `quran_local.db` with sqlite3:
/// under the old normalization, 5:25's "ٱلْفَٰسِقِينَ" became "الفسقين", not
/// "الفاسقين". Fixed by moving U+0670 out of the stripped class below and
/// into the alef-variant class (it now normalizes to ا, same as the other
/// alef forms).
///
/// **This alone isn't the whole story, though — a second real edge case
/// found while verifying the fix above:** a small, well-known, closed set
/// of very common Quranic words (اللَّٰه, الرَّحْمَٰن, هَـذَا, ذَٰلِك,
/// لَـكِن, السَّمَـوَٰت, …) carry a dagger alif that *modern conventional
/// typed Arabic simply omits* — most people type "الرحمن", not "الرحمان",
/// even though the Quranic spelling's dagger alif genuinely represents that
/// extra "ا" sound. Mapping U+0670 → ا (correct for "فاسقين" and the
/// general case) makes exactly these words fail to match the way most
/// people actually type them. There's no single normalization that gets
/// every word right, so [normalizeArabic] (dagger alif → ا, the
/// linguistically literal reading, right for the common case) and
/// [normalizeArabicLoose] (dagger alif → nothing, right for this
/// exception list) are both exported; search call sites should match
/// against **both** — see `QuranRepository.search()`.
///
/// Unicode escapes are used throughout (rather than literal combining
/// characters in the source, which is exactly what let the first bug above
/// hide — literal-character ranges are much harder to audit than explicit
/// codepoints) so the exact codepoints stripped are unambiguous on review:
/// U+0610-U+061A (Quranic honorific/annotation signs), U+064B-U+065F (the
/// harakat: fatha/damma/kasra/tanwin/shadda/sukun + small Quranic marks),
/// U+06D6-U+06ED (further Quranic annotation/small marks), U+0640
/// (tatweel). U+0670 is deliberately **not** here — see the alef-variant
/// class below.
final RegExp _arabicDiacritics = RegExp(
  '[ؐ-ًؚ-ٟۖ-ۭـ]',
);

/// آ (U+0622) أ (U+0623) إ (U+0625) ٱ (U+0671) ٰ (U+0670, dagger alif) -> ا (U+0627)
final RegExp _alefVariants = RegExp('[آأإٰٱ]');

/// Same alef unification as [normalizeArabic] but WITHOUT U+0670 (dagger
/// alif) in it — used only by [normalizeArabicLoose].
final RegExp _alefVariantsNoDagger = RegExp('[آأإٱ]');

String normalizeArabic(String s) {
  var out = s.replaceAll(_arabicDiacritics, '');
  out = out.replaceAll(_alefVariants, 'ا');
  out = out.replaceAll('ى', 'ي'); // ى (alef maksura) -> ي
  return out;
}

/// The "loose" counterpart of [normalizeArabic]: drops the dagger alif
/// (U+0670) entirely instead of expanding it to ا, matching how most people
/// actually type the small, closed set of Quranic words where modern
/// convention omits it (الرحمن, هذا, ذلك, لكن, السماوات, …) — see
/// [normalizeArabic]'s doc for the full explanation. Search call sites
/// should try a query against both variants, not just one.
String normalizeArabicLoose(String s) {
  var out = s.replaceAll(_arabicDiacritics, '');
  out = out.replaceAll('ٰ', ''); // dagger alif: dropped, not expanded
  out = out.replaceAll(_alefVariantsNoDagger, 'ا');
  out = out.replaceAll('ى', 'ي');
  return out;
}

/// P3‑29: strips tashkeel (the same harakat range [normalizeArabic] strips
/// for search) for **display**, not search — deliberately does *not* touch
/// letterforms the way [normalizeArabic] does (آ/أ/إ/ٱ all staying as
/// themselves, ى staying ى), since a "hide diacritics" reading toggle must
/// only remove the marks, never silently rewrite which letter is on the
/// page. Used by the book text reader's "التشكيل" toolbar toggle.
String stripTashkeelForDisplay(String s) => s.replaceAll(_arabicDiacritics, '');

/// P3‑46: a display-only cleanup for surah *names* shown as UI chrome
/// (section-header banners, AppBar titles, nav lists) — NOT for the recited
/// ayah body.
///
/// The bundled `quran_local.db` stores surah names in Madani-mushaf
/// orthography, where the sukun is written with U+06E1 (ARABIC SMALL HIGH
/// DOTLESS HEAD OF KHAH) rather than the ordinary U+0652 (SUKUN). Real-device
/// feedback flagged the ج of "السَّجۡدَةِ" (surah 32) rendering oddly — that
/// small-high-khah-head sits awkwardly over ج (and over the other 40 surah
/// names that use it) in this app's chrome font at header sizes. U+06E1 and
/// U+0652 mean the same thing (a silent consonant); swapping to the standard
/// sukun keeps the diacritic honest while rendering cleanly in every font.
/// Scope is deliberately just this one substitution — nothing else about the
/// name is touched, so fully-vocalized names stay fully vocalized.
String surahNameForDisplay(String s) => s.replaceAll('ۡ', 'ْ');

/// True if [needle] occurs in [haystack] starting at a word boundary (index
/// 0, or right after a space) — not merely anywhere `.contains()` would
/// find it, which also matches inside an unrelated longer word (P3‑9: e.g.
/// searching "نشورا" matching inside "منشورا", a different word that just
/// happens to share every letter after its leading م). Shared by
/// `QuranRepository.search()` and `HadithRepository.search()`. Still allows
/// a useful *prefix* match within a word (e.g. "رحم" finding "الرحمن"),
/// since only where the match starts is constrained, not where it ends.
bool arabicWordBoundaryContains(String haystack, String needle) {
  if (needle.isEmpty) return false;
  var from = 0;
  while (true) {
    final i = haystack.indexOf(needle, from);
    if (i == -1) return false;
    if (i == 0 || haystack[i - 1] == ' ') return true;
    from = i + 1;
  }
}
