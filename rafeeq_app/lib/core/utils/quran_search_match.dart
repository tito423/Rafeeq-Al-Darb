import 'arabic_normalize.dart';

/// How a Qur'an search matches a word.
///
/// «ادي خيار في البحث بالكلمة بحث بجزء من الكلمة أو كلمة متطابقة، بتشكيل أو
/// بغير تشكيل». Three ways, measured over the bundled `quran_local.db` before
/// any of them shipped (`scratchpad/measure_search.py`):
///
/// | query   | word start (the old search) | part of a word | derivatives |
/// |---------|------------------------------|----------------|-------------|
/// | الصبر   | 52                           | 84             | 90          |
/// | الرحمة  | 72                           | 73             | 73          |
/// | الجنة   | 75                           | 76             | 76          |
/// | الصلاة  | **0**                        | **0**          | 63          |
///
/// The last row is a bug the old search had all along: the Uthmani text writes
/// الصلاة as «ٱلصَّلَوٰة», which normalises to «الصلواة», so the word as anyone
/// types it matched nothing. The derivatives pattern allows a long vowel
/// between any two letters, which is exactly the gap, and it is also what
/// finds «الصابرين» and «صبّار» for «صبر».
enum QuranSearchMode {
  /// Every form: a long vowel (ا و ي) may sit between any two letters.
  derivatives,

  /// The letters appear together anywhere inside a word.
  partial,

  /// The word itself, allowing only the particles Arabic joins to its front
  /// (و ف ب ل ك and the article).
  wholeWord,
}

/// One word of an ayah in the three forms a search compares against.
class QuranWord {
  /// Diacritics stripped, every alef form (dagger alif included) → ا, ى → ي.
  final String strict;

  /// As [strict] but the dagger alif dropped — see `normalizeArabicLoose`.
  final String loose;

  /// Harakat KEPT: only the Qur'anic annotation marks and tatweel removed, and
  /// alef wasla written as a plain alef. For «بالتشكيل».
  final String harakat;

  const QuranWord(this.strict, this.loose, this.harakat);

  factory QuranWord.of(String raw) => QuranWord(
        normalizeArabic(raw),
        normalizeArabicLoose(raw),
        normalizeKeepHarakat(raw),
      );

  bool get isEmpty => strict.isEmpty;
}

/// Qur'anic annotation marks (U+0610–U+061A, U+06D6–U+06ED) and tatweel.
/// The harakat (U+064B–U+065F) are deliberately not here.
final RegExp _annotationMarks = RegExp('[ؐ-ؚۖ-ۭـ]');

String normalizeKeepHarakat(String s) =>
    s.replaceAll(_annotationMarks, '').replaceAll('ٱ', 'ا');

bool _wholeWord(String word, String needle) =>
    word == needle || arabicProclitics.any((p) => word == '$p$needle');

/// A test for one word, or null for an empty query. Single words only; a
/// phrase is matched against the whole ayah by the repository.
bool Function(QuranWord word)? quranWordTest(
  String query, {
  required QuranSearchMode mode,
  bool matchDiacritics = false,
}) {
  final q = query.trim();
  if (q.isEmpty) return null;

  if (matchDiacritics) {
    final h = normalizeKeepHarakat(q);
    return mode == QuranSearchMode.wholeWord
        ? (w) => _wholeWord(w.harakat, h)
        : (w) => w.harakat.contains(h);
  }

  final bare = withoutArabicArticle(q);
  final cores = <String>{
    normalizeArabic(q),
    normalizeArabicLoose(q),
    if (bare != null) normalizeArabic(bare),
    if (bare != null) normalizeArabicLoose(bare),
  }..removeWhere((c) => c.isEmpty);

  switch (mode) {
    case QuranSearchMode.partial:
      return (w) => cores.any((c) => w.strict.contains(c) || w.loose.contains(c));
    case QuranSearchMode.wholeWord:
      return (w) =>
          cores.any((c) => _wholeWord(w.strict, c) || _wholeWord(w.loose, c));
    case QuranSearchMode.derivatives:
      final core = normalizeArabicLoose(bare ?? q);
      // Under three letters a vowel-tolerant pattern matches half the book.
      if (core.length < 3) {
        return (w) =>
            cores.any((c) => w.strict.contains(c) || w.loose.contains(c));
      }
      final rx = RegExp(core.split('').map(RegExp.escape).join('[اوي]?'));
      return (w) => rx.hasMatch(w.strict) || rx.hasMatch(w.loose);
  }
}

/// A curated topic's own word pattern, with the false friends that measuring
/// it turned up excluded by name.
class TopicPattern {
  /// Searched inside each word, strict and loose forms both.
  final String pattern;

  /// A word containing any of these is not a match.
  final List<String> excludeContaining;

  /// A word exactly equal to one of these is not a match.
  final List<String> excludeWords;

  /// Matched against the whole ayah instead of word by word.
  final List<String> phrases;

  const TopicPattern({
    this.pattern = '',
    this.excludeContaining = const [],
    this.excludeWords = const [],
    this.phrases = const [],
  });

  /// A word is excluded when EITHER of its forms hits an exclusion. Testing
  /// each form on its own let a false friend back in through the other one:
  /// «الصدقات» is excluded as strict «الصدقات» but its loose form «الصدقت»
  /// contains no «صدقات», and «المنافقين» loosely reads «المنفقين» — measured,
  /// both were counted until this was written this way.
  bool Function(QuranWord word)? get wordTest {
    if (pattern.isEmpty) return null;
    final rx = RegExp(pattern);
    bool excluded(String form) =>
        excludeWords.contains(form) || excludeContaining.any(form.contains);
    return (w) =>
        !excluded(w.strict) &&
        !excluded(w.loose) &&
        ((w.strict.isNotEmpty && rx.hasMatch(w.strict)) ||
            (w.loose.isNotEmpty && rx.hasMatch(w.loose)));
  }
}
