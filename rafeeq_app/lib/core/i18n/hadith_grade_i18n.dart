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
  // The last three, counted rather than guessed: after the pass
  // above, 45,219 rulings read Arabic and exactly three still held
  // an English word. Each is one row in 67,153 and each is an
  // editor’s note, so each is matched whole.
  "[Abu 'Eisa said:] This Hadith is": "[قال أبو عيسى:] هذا حديث",
  // Single-quoted on purpose: the key itself contains double quotes,
  // and the generator that reads this table splits on the quote the
  // line opens with.
  'except for "one vessel ..."': 'إلا قوله: «إناء واحد …»',
  "Mauquf and Marfu'": "موقوف ومرفوع",
  // Added 2026-09-20 after counting every distinct grade in the
  // bundled database: 54 carried Latin letters and the table below
  // caught most but not all. Longest first, because the table is
  // applied in order and a sentence has to match before the terms
  // inside it do.
  "Abu Eisa (at-Tirmidhi) said: This Hadith is Hasan Sahih.": "قال أبو عيسى الترمذي: هذا حديث حسن صحيح.",
  "Da'if Munkar, and the Sahih version is 19 days as in a previous hadith.": "ضعيف منكر، والمحفوظ تسعة عشر يومًا كما في حديث سابق.",
  "1: Hasan 2: Sahih 3: The authenticator did not find a chain": "١: حسن ٢: صحيح ٣: لم يقف المحقق على إسناد",
  "1: Sahih 2: 3: Sahih Mauquf 4: The chain is da'if": "١: صحيح ٢: ٣: صحيح موقوف ٤: الإسناد ضعيف",
  "The authenticator did not find a chain": "لم يقف المحقق على إسناد",
  "The chain is da'if": "الإسناد ضعيف",
  "(fabricated)": "(موضوع)",
  "(Fabricated)": "(موضوع)",
  "(Weak)": "(ضعيف)",
  "Mutawatir": "متواتر",
  "Mawdu'": "موضوع",
  "Maudu’": "موضوع",
  "Maudu'": "موضوع",
  "Maudu": "موضوع",
  "Marfu'": "مرفوع",
  "Marfu": "مرفوع",
  "mursal": "مرسل",
  "Da`if": "ضعيف",
  "Da,if": "ضعيف",
  "Da if": "ضعيف",
  "Daif": "ضعيف",
  "da'if": "ضعيف",
  "Sah,": "صحيح،",
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
  // The dataset writes the apostrophe BOTH ways. Counted on the bundled
  // hadith.db: "Da'if" 2,122 rows, "Da’if" 652, "Da’if in chain"
  // and friends besides — and only the straight form was here, so 652
  // hadiths went on showing a transliteration to an Arabic reader.
  "Da’if Jiddan": "ضعيف جدًا",
  "Da’if Mauquf": "ضعيف موقوف",
  "Da’if Maqtu'": "ضعيف مقطوع",
  "Da’if": "ضعيف",
  "Maqtu’": "مقطوع",
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
