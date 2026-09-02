/// Buckwalter transliteration → Arabic script.
///
/// The bundled `quran_sciences.db` `word_grammar` table stores the corpus
/// `root` and `lemma` columns in Tim Buckwalter's ASCII transliteration
/// (e.g. `Hmd`, `rbb`, `r~aHoma\`n`, `{som`). Showing that raw in the i'rab
/// card is unreadable, so convert it to Arabic for display.
///
/// Mapping per the standard Buckwalter scheme:
/// <https://en.wikipedia.org/wiki/Buckwalter_transliteration>
library;

const Map<String, String> _buckwalterMap = {
  "'": 'ء', // ء  hamza
  '|': 'آ', // آ  alef madda
  '>': 'أ', // أ  alef + hamza above
  '&': 'ؤ', // ؤ  waw + hamza
  '<': 'إ', // إ  alef + hamza below
  '}': 'ئ', // ئ  ya + hamza
  'A': 'ا', // ا  alef
  'b': 'ب', // ب
  'p': 'ة', // ة  ta marbuta
  't': 'ت', // ت
  'v': 'ث', // ث
  'j': 'ج', // ج
  'H': 'ح', // ح
  'x': 'خ', // خ
  'd': 'د', // د
  '*': 'ذ', // ذ
  'r': 'ر', // ر
  'z': 'ز', // ز
  's': 'س', // س
  '\$': 'ش', // ش
  'S': 'ص', // ص
  'D': 'ض', // ض
  'T': 'ط', // ط
  'Z': 'ظ', // ظ
  'E': 'ع', // ع
  'g': 'غ', // غ
  'f': 'ف', // ف
  'q': 'ق', // ق
  'k': 'ك', // ك
  'l': 'ل', // ل
  'm': 'م', // م
  'n': 'ن', // ن
  'h': 'ه', // ه
  'w': 'و', // و
  'Y': 'ى', // ى  alef maksura
  'y': 'ي', // ي
  'F': 'ً', // ً  fathatan
  'N': 'ٌ', // ٌ  dammatan
  'K': 'ٍ', // ٍ  kasratan
  'a': 'َ', // َ  fatha
  'u': 'ُ', // ُ  damma
  'i': 'ِ', // ِ  kasra
  '~': 'ّ', // ّ  shadda
  'o': 'ْ', // ْ  sukun
  '`': 'ٰ', // ٰ  dagger alef
  '{': 'ٱ', // ٱ  alef wasla
  '_': 'ـ', // ـ  tatweel
};

/// Converts a Buckwalter-transliterated string to Arabic script.
/// Characters with no mapping (spaces, digits, stray punctuation) pass
/// through unchanged, so `Hmd` → `حمد` and `rbb` → `ربب`.
String buckwalterToArabic(String input) {
  if (input.isEmpty) return input;
  final buffer = StringBuffer();
  for (final rune in input.split('')) {
    buffer.write(_buckwalterMap[rune] ?? rune);
  }
  return buffer.toString();
}

/// True when [s] looks like it is already Arabic script (nothing to convert).
bool _isArabic(String s) =>
    s.runes.any((r) => r >= 0x0600 && r <= 0x06FF);

/// Safe wrapper for display: returns [s] untouched if it is already Arabic
/// (some rows may already be populated in script), otherwise transliterates.
String buckwalterForDisplay(String s) =>
    _isArabic(s) ? s : buckwalterToArabic(s);
