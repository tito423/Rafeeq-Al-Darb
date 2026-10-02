/// Typing errors in the tajweed course texts, corrected where they are read.
///
/// The owner, 2026-10-02: «اتاكد ان الخط واضح والحروف مكتوبة مظبوط لاني لقيت
/// غلطات كتابيه كتير جدا». He found them in the lessons, and they are real:
/// Shamela's e-text of these books carries a stray fatha before a hamzat
/// al-wasl («أَحْكَامُ َالمِيمِ»), a damma on the wrong letter («مَخَفَّفٌ»),
/// two vowels stacked on one letter («عِِمْرَانَ»), a vowel cut off from its
/// letter by a space («وَالنُّون ُ»).
///
/// The bundled files stay byte-for-byte what R2 serves (`bundled_matn.dart`),
/// so the corrections are applied on top of them here, each one listed with
/// the reason it is a correction and not an edit. The rules for that:
///
/// * Only typing errors: a mark on the wrong letter, a doubled mark, a space
///   inside a word, the dotless «ى» written for a final «ي» in prose.
///   A variant reading is not an error and is never "fixed".
/// * A verse of the Jazariyyah quoted inside its شرح is corrected to the
///   critical edition the second level already shows above it — «الجزرية»,
///   ed. عبد المحسن بن محمد القاسم (٢٣٠ مخطوطة), `al_muqaddimah_al_jazariyyah_matn`.
///   Where that edition's footnotes say a manuscript marks both vowels
///   («مقدّمه» بفتح الدال وكسرها), the edition's chosen vowel is taken.
/// * Qur'an words are NOT touched here. CLAUDE.md §1.2 sets a separate,
///   heavier procedure for them (the Madinah page as evidence), so the few
///   doubtful Qur'anic spellings in these commentaries are left as printed.
///
/// `test/tajweed_text_corrections_test.dart` reads the bundled books and
/// fails if any [TextCorrection.from] no longer occurs exactly
/// [TextCorrection.count] times — a correction must never stop applying
/// silently, nor start applying somewhere it was not checked.
library;

import '../../library/data/book_text.dart';

class TextCorrection {
  final String from;
  final String to;

  /// How many times [from] occurs in the book; all of them are corrected.
  final int count;

  /// Why this is a typing error, and the evidence.
  final String why;

  const TextCorrection(this.from, this.to, this.why, {this.count = 1});
}

const _strayMark = 'a mark standing alone before the word, on no letter';
const _dotlessYa =
    'final «ي» printed dotless as «ى» (Egyptian print style); '
    'the word ends in ي, and a beginner reads «ى» as alif maqsura';
const _critical = 'the verse as the critical edition (al-Qasim) sets it';

const tajweedTextCorrections = <String, List<TextCorrection>>{
  'tuhfat_al_atfal': [
    TextCorrection('أَحْكَامُ َالمِيمِ', 'أَحْكَامُ المِيمِ', _strayMark),
    TextCorrection('أَحْكَامُ َالمَدِّ', 'أَحْكَامُ المَدِّ', _strayMark),
    TextCorrection('الْمِيهِىِّ', 'الْمِيهِيِّ',
        'a kasra and a shadda on a dotless ى: the nisba ending is «يّ»'),
    TextCorrection('قَد ضَّمَّنْتُهَا', 'قَدْ ضَمَّنْتُهَا',
        'a shadda on ض after «قد» (no idgham of د into ض), and the '
        'sukun of «قَدْ» missing; the verb is ضَمَّنْتُهَا'),
    TextCorrection('مَخَفَّفٌ كُلٌّ', 'مُخَفَّفٌ كُلٌّ',
        'passive participle مُفَعَّل, as the line before it has «مُخَفَّفٌ»'),
    TextCorrection('نَدٌّ بَداَ', 'نَدٌّ بَدَا',
        'the fatha sits on the alif instead of the dal'),
    TextCorrection('الَّلازِمِ', 'اللَّازِمِ',
        'the shadda belongs on the second lam, not the article\'s'),
    TextCorrection('وَالتَّنْوينِ (١)', 'وَالتَّنْوِينِ (١)',
        'the heading drops the kasra the verse under it has'),
    TextCorrection('يعنى', 'يعني', _dotlessYa, count: 12),
    TextCorrection('وهى ', 'وهي ', _dotlessYa, count: 3),
    TextCorrection('أصلى', 'أصلي', _dotlessYa),
    TextCorrection('كلمى', 'كلمي', _dotlessYa, count: 2),
    TextCorrection('(حى طهر)', '(حي طهر)', _dotlessYa),
    TextCorrection('الاقلاب', 'الإقلاب',
        'hamzat al-qat\' of the masdar إقلاب, as the verses write it',
        count: 2),
  ],
  'fath_rabb_al_bariyyah_sharh_al_jazariyyah': [
    TextCorrection('مُقَدَِّمَهْ', 'مُقَدِّمَهْ', '$_critical (v. 4)'),
    TextCorrection('وَالنُّون ُ', 'وَالنُّونُ', '$_critical (v. 15)'),
    TextCorrection('مُكَمَِّلاً', 'مُكَمَّلاً', '$_critical (v. 32)'),
    TextCorrection('إِِهْدِنَا', 'إِهْدِنَا', '$_critical (v. 35)'),
    TextCorrection('بَرْق ٍ', 'بَرْقٍ', '$_critical (v. 37)'),
    TextCorrection('مُقَلْقَِلاً', 'مُقَلْقَلاً', '$_critical (v. 39)'),
    TextCorrection('مُسْتَقِيم ِ', 'مُسْتَقِيمِ', '$_critical (v. 40)'),
    TextCorrection('وَالْمَد ُّ', 'وَالْمَدُّ', '$_critical (v. 69)'),
    TextCorrection('حَرَامٌٍ غَيْرُِ', 'حَرَامٌ غَيْرُ', '$_critical (v. 78)'),
    TextCorrection('عِِمْرَانَ', 'عِمْرَانَ', '$_critical (v. 96)', count: 2),
    TextCorrection('وَاكْْسِرْهُ', 'وَاكْسِرْهُ', '$_critical (v. 102)'),
    TextCorrection('غَيْرَِ اللاَّمِ', 'غَيْرِ اللاَّمِ', '$_critical (v. 102)'),
    TextCorrection('بُِيونُسَ', 'بِيُونُسَ',
        'the damma of يُونُس typed on the preposition ب'),
    TextCorrection('إذا: ً الضاد', 'إذا: الضاد', _strayMark),
    TextCorrection('رحيم ٍ', 'رحيمٍ',
        'a space between the word and its tanween (the example is رحيمٍ)'),
  ],
};

/// [book] with the corrections listed for [id] applied, or [book] itself.
BookText correctedBookText(String id, BookText book) {
  final list = tajweedTextCorrections[id];
  if (list == null) return book;
  String fix(String t) {
    for (final c in list) {
      if (t.contains(c.from)) t = t.replaceAll(c.from, c.to);
    }
    return t;
  }

  return BookText(
    meta: book.meta,
    toc: book.toc,
    pages: [
      for (final p in book.pages)
        BookPage(
          printedPage: p.printedPage,
          editorOnly: p.editorOnly,
          paras: [
            for (final a in p.paras)
              BookPara(text: fix(a.text), kind: a.kind, ref: a.ref),
          ],
        ),
    ],
  );
}
