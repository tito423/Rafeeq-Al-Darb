/// P3‑41: the owner's real-device feedback — "do not write grade or
/// الدرجة, just write what is the grade" (no "Grade:" label prefix) "...
/// in the app selected language only". The bundled hadith dataset's own
/// `grade`/`grader` columns are English-only free text (verified directly
/// against `scripts/pipeline_zips/hadith.db`: "Da'if Jiddan", "Sahih li
/// ghairih", "Sahih except for \"one vessel ...\"", etc. — real
/// classical hadith-science terminology, not simple single words).
///
/// Full machine translation of arbitrary free text into 6 UI locales isn't
/// something this project has a trustworthy source for, so this is an
/// honest, bounded fix: Arabic gets a real term-by-term restoration to the
/// actual Arabic words these are transliterations *of* (صحيح، حسن، ضعيف...
/// — this isn't translation so much as undoing a transliteration), tried
/// longest-phrase-first so compound terms like "Da'if Jiddan" match before
/// the bare "Da'if" would. Every other locale keeps the original English
/// term — not a silent gap, a deliberate one, since guessing at Spanish/
/// Russian/Portuguese/French hadith-science vocabulary without a real
/// source would be worse than showing the honest English.
const _kGradeTermsArabic = <String, String>{
  // Longest/most specific phrases first.
  "Sahih li ghairih": "صحيح لغيره",
  "Hasan li ghairih": "حسن لغيره",
  "Da'if Jiddan": "ضعيف جدًا",
  "Hasan Sahih": "حسن صحيح",
  "Sahih Mauquf": "صحيح موقوف",
  "Da'if Mauquf": "ضعيف موقوف",
  "Sahih Maqtu'": "صحيح مقطوع",
  "Da'if Maqtu'": "ضعيف مقطوع",
  "Sahih in chain": "صحيح الإسناد",
  "Shadh 'anha": "شاذ عنها",
  "li ghairih": "لغيره",
  "in chain": "في الإسناد",
  "Jiddan": "جدًا",
  "Mauquf": "موقوف",
  "Maqtu'": "مقطوع",
  "Sahih": "صحيح",
  "Hasan": "حسن",
  "Da'if": "ضعيف",
  "Shadh": "شاذ",
  "Munkar": "منكر",
};

const _kGraderNamesArabic = <String, String>{
  'Al-Albani': 'الألباني',
  'Darussalam': 'دار السلام',
};

/// Restores [grade] to Arabic term-by-term when [languageCode] is 'ar';
/// returns it unchanged for every other locale (see the file doc above).
String localizedHadithGrade(String grade, String languageCode) {
  if (languageCode != 'ar') return grade;
  var out = grade;
  for (final entry in _kGradeTermsArabic.entries) {
    out = out.replaceAll(entry.key, entry.value);
  }
  return out;
}

String localizedHadithGrader(String grader, String languageCode) {
  if (languageCode != 'ar') return grader;
  return _kGraderNamesArabic[grader] ?? grader;
}
