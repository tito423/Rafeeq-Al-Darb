/// Display-only shaping for the sourced Uthmani text. The database value is
/// never changed (§1.2); these are two ways the Tanzil encoding and the
/// mushaf font disagree about how a mark is drawn.
///
/// 1. **Waqf signs.** Tanzil stores the combining waqf signs U+06D6–U+06DC
///    as whitespace-separated tokens. In a justified paragraph that
///    whitespace expands, so the sign floats in the gap instead of sitting
///    over the word it qualifies. Removing that one display-space lets the
///    Quran font attach the combining sign to its preceding word. U+06DE
///    (rub el hizb) and U+06E9 (sajdah) are spacing symbols rather than
///    combining signs, so they deliberately remain separate.
///
/// 2. **Open tanween.** Tanzil writes a tanween that is not pronounced
///    clearly — idgham or ikhfa — as the tanween followed by U+06ED SMALL
///    LOW MEEM. Measured over the bundled text (2026-09-22): 2,901 after a
///    fathatan and 1,807 after a dammatan, every one of them before a letter
///    of idgham or ikhfa (و م ل ي ر ن, ف ق ك ث ت ش س …) and **not one** before
///    a throat letter. The printed Madinah mushaf draws that tanween
///    staggered, with no meem; AmiriQuran drew the U+06ED literally, a small
///    «م» under «أُمَّةًۭ مُّسْلِمَةًۭ» (2:128) and some 4,700 other words.
///    Unicode encodes exactly this mark as U+08F0 ARABIC OPEN FATHATAN and
///    U+08F1 ARABIC OPEN DAMMATAN, both in the font, so the pair is drawn as
///    that one mark.
///
///    The 99 cases after a KASRATAN are left alone: all of them stand
///    before «ب» — iqlab — where the printed mushaf really does set a small
///    meem beneath the letter.
String shapeQuranForDisplay(String source) => source
    .replaceAllMapped(
      RegExp(r'\s+([ۖ-ۜ])(?=\s|$)'),
      (match) => match.group(1)!,
    )
    .replaceAll('ًۭ', 'ࣰ')
    .replaceAll('ٌۭ', 'ࣱ');
