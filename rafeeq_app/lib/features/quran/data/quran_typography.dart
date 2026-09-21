/// Display-only shaping for the sourced Uthmani text.
///
/// Tanzil stores the combining waqf signs U+06D6–U+06DC as whitespace-
/// separated tokens. In a justified paragraph that whitespace expands, so
/// the sign floats in the gap instead of sitting over the word it qualifies.
/// Removing that one display-space lets the Quran font attach the combining
/// sign to its preceding word. The database value is never changed.
///
/// U+06DE (rub el hizb) and U+06E9 (sajdah) are spacing symbols rather than
/// combining signs, so they deliberately remain separate.
String shapeQuranForDisplay(String source) => source.replaceAllMapped(
  RegExp(r'\s+([\u06D6-\u06DC])(?=\s|$)'),
  (match) => match.group(1)!,
);
