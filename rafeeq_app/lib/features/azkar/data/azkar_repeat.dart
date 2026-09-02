/// How many times a dhikr should be repeated — **extracted from the real
/// bundled text**, not invented. Hisn al-Muslim's own wording embeds the
/// repeat count inline, e.g. "...( ثلاث مرات )" or "...(مائة مرة)"; when a
/// dhikr's text carries no such phrase it is said once, so the honest
/// default is 1 — never a guessed round number.
int parseAzkarRepeatCount(String body) {
  // A literal digit (Arabic-Indic or Western) right before "مرة"/"مرات"
  // takes priority — it's unambiguous.
  final digitMatch =
      RegExp(r'([0-9٠-٩]+)\s*مر[ةات]').firstMatch(body);
  if (digitMatch != null) {
    final n = _fromArabicDigits(digitMatch.group(1)!);
    if (n != null && n > 0) return n;
  }

  // Otherwise match the Arabic number-word before "مرة"/"مرات"/"مرتين" —
  // ordered longest-phrase-first so "عشر مرات" isn't shadowed by a shorter
  // partial match.
  const wordToCount = <String, int>{
    'مرة واحدة': 1,
    'مرتين': 2,
    'ثلاث مرات': 3,
    'ثلاثاً': 3,
    'ثلاثا': 3,
    'أربع مرات': 4,
    'أربعاً': 4,
    'خمس مرات': 5,
    'ست مرات': 6,
    'سبع مرات': 7,
    'ثماني مرات': 8,
    'ثمان مرات': 8,
    'تسع مرات': 9,
    'عشر مرات': 10,
    'عشراً': 10,
    'عشرا': 10,
    'ثلاثين مرة': 30,
    'مائة مرة': 100,
    'مئة مرة': 100,
  };
  for (final entry in wordToCount.entries) {
    if (body.contains(entry.key)) return entry.value;
  }
  return 1;
}

int? _fromArabicDigits(String s) {
  const arabicIndic = '٠١٢٣٤٥٦٧٨٩';
  final western = s.split('').map((c) {
    final i = arabicIndic.indexOf(c);
    return i >= 0 ? i.toString() : c;
  }).join();
  return int.tryParse(western);
}
