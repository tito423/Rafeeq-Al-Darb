/// المستوى الأول — «تحفة الأطفال والغلمان في تجويد القرآن» للجمزوري.
///
/// WHY THIS BOOK FOR THE FIRST LEVEL. «ابدأه بالسهل اللي يناسب الاطفال
/// وبالتدرج» — and the classical answer to that is literally named for it.
/// The Jamzuri's poem is the beginner's matn of tajweed, sixty-one lines that
/// cover the sakin nun, the sakin meem, the lam of «ال», the like letters and
/// the madd, and this edition carries الشيخ علي محمد الضباع's short commentary
/// under each page with real Qur'anic examples already in it. It is eight
/// pages long, it is already on R2 as `tuhfat_al_atfal`, and not one word of
/// it is written by me.
///
/// TWO THINGS ABOUT THIS BOOK THAT THE SHAPE OF THIS FILE EXISTS FOR.
///
/// **Its table of contents is incomplete.** The book's own `toc` lists seven
/// sections; the real headings are inside the body — «أَحْكَامُ َالمِيمِ
/// السَّاكِنَةِ», «في المِثْلَيْنِ وَالمُتَقَارِبَيْنِ وَالمُتَجَانِسَيْنِ»
/// and «أقْسَامُ المَدِّ الَّلازِمِ» appear as ordinary paragraphs. Building
/// the lessons from the toc would have produced seven lessons with wrong
/// boundaries, which is exactly the mistake `tajweed_course.dart` records
/// having made once already. These ranges were read off the paragraphs.
///
/// **Its commentary does not follow its own verses.** الضباع's notes sit at
/// the FOOT of each page, so «حكم لام أل»'s explanation is the last paragraph
/// of page 5 — *after* the verses of «المثلين» have already started on the
/// same page. Worse, one paragraph can carry the note for two lessons: page
/// 4's last paragraph holds (١) for المشددتين and (٢) for الميم الساكنة.
///
/// So a lesson here is a **list of ranges**, not one, and a shared footnote
/// paragraph is claimed by both lessons it explains. That is not duplication
/// by accident: the paragraph really does explain both, and showing a reader
/// only half of it would be worse.
library;

/// One run of paragraphs, inclusive at both ends.
class TuhfaRange {
  final int fromPage;
  final int fromPara;
  final int toPage;
  final int toPara;

  /// True when this run is الضباع's note rather than the Jamzuri's verse.
  /// The screen sets it in smaller type, and the test insists that a range
  /// marked this way really does begin with a «(١)» marker — and that a range
  /// NOT marked this way does not. Page 6's first paragraph is the tail of
  /// المثلين's verses and looks like a footnote only because it ends with the
  /// marker that points at one.
  final bool commentary;

  const TuhfaRange(
    this.fromPage,
    this.fromPara,
    this.toPage,
    this.toPara, {
    this.commentary = false,
  });
}

class TuhfaLesson {
  /// The heading as the book writes it, minus the footnote marker it carries.
  ///
  /// «أَحْكَامُ النُّونِ السَّاكِنَةِ وَالتَّنْوينِ (١)» is how the paragraph
  /// reads: the «(١)» is a pointer at الضباع's note at the foot of the page,
  /// not part of the name of the chapter, and the note itself is shown in the
  /// lesson anyway. The stray fatha in «أَحْكَامُ َالمِيمِ» IS the source's
  /// and stays — correcting the book is not mine to do.
  final String title;

  /// The verses, then the commentary that explains them, in reading order.
  final List<TuhfaRange> ranges;

  const TuhfaLesson(this.title, this.ranges);
}

const tuhfaBook = 'tuhfat_al_atfal';

const tuhfaSourceLabel =
    'تحفة الأطفال والغلمان في تجويد القرآن، لسليمان بن محمد الجمزوري '
    '(ت بعد ١١٩٨هـ)، بشرح وجيز للشيخ علي محمد الضباع — المكتبة الشاملة';

const tuhfaLessons = <TuhfaLesson>[
  TuhfaLesson('مُقَدِّمَةٌ', [
    TuhfaRange(2, 0, 2, 5),
  ]),
  TuhfaLesson('أَحْكَامُ النُّونِ السَّاكِنَةِ وَالتَّنْوينِ', [
    // Runs straight on: page 2 ends with its own footnote and page 3 opens
    // with the next verses, so this one really is contiguous.
    TuhfaRange(2, 6, 3, 8),
  ]),
  TuhfaLesson('أَحْكَامُ النُّونِ وَالمِيمِ المُشَدَّدَتَيْنِ', [
    TuhfaRange(4, 0, 4, 1),
    // (١) of the shared footnote.
    TuhfaRange(4, 9, 4, 9, commentary: true),
  ]),
  TuhfaLesson('أَحْكَامُ َالمِيمِ السَّاكِنَةِ', [
    TuhfaRange(4, 2, 4, 8),
    // (٢) of the same paragraph.
    TuhfaRange(4, 9, 4, 9, commentary: true),
  ]),
  TuhfaLesson('حُكْمُ لامِ ألْ وَلامِ الْفِعْلِ', [
    TuhfaRange(5, 0, 5, 6),
    // Its commentary is the last paragraph of the page, below المثلين's
    // verses — the reason a lesson needs more than one range.
    TuhfaRange(5, 12, 5, 12, commentary: true),
  ]),
  TuhfaLesson('في المِثْلَيْنِ وَالمُتَقَارِبَيْنِ وَالمُتَجَانِسَيْنِ', [
    TuhfaRange(5, 7, 5, 11),
    // The verses run on to the top of page 6 before the commentary.
    TuhfaRange(6, 0, 6, 0),
    TuhfaRange(6, 9, 6, 9, commentary: true),
  ]),
  TuhfaLesson('أقْسَامُ المَدِّ', [
    TuhfaRange(6, 1, 6, 8),
    TuhfaRange(6, 9, 6, 9, commentary: true),
  ]),
  TuhfaLesson('أَحْكَامُ َالمَدِّ', [
    TuhfaRange(7, 0, 7, 6),
    TuhfaRange(7, 12, 7, 12, commentary: true),
  ]),
  TuhfaLesson('أقْسَامُ المَدِّ الَّلازِمِ', [
    TuhfaRange(7, 7, 7, 11),
    TuhfaRange(8, 0, 8, 5),
    TuhfaRange(8, 11, 8, 11, commentary: true),
  ]),
  TuhfaLesson('الخاتمة', [
    TuhfaRange(8, 6, 8, 10),
  ]),
];
