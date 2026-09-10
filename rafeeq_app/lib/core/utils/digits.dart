/// One place that shapes digits for the language the app is showing.
///
/// This was written twice before it was written here. `PrayerStatusNotification`
/// carried a private `_toArabicDigits` for its clock and its Hijri line, and
/// `azkar_repeat.dart` carries the inverse for parsing. The third copy would
/// have gone into `PrayerReminderService`, which is exactly how `formatBytes`
/// ended up in five places with the same bug (CLAUDE.md trap #16), so it goes
/// here instead.
///
/// WHY IT MATTERS, MEASURED.
/// The «قبل الأذان» reminder fired on emulator-5554 reading
/// «باقٍ 10 دقيقة على الفجر» while the app's own ongoing prayer card, one row
/// below it in the same shade, read «الفجر · ٠٦:١٣». Same app, same language,
/// two digit systems on screen at once.
///
/// ARABIC ONLY — AND URDU'S LATIN DIGITS ARE THE STANDARD, NOT AN OVERSIGHT.
///
/// The owner asked which is right for Urdu. It is a question with a measurable
/// answer rather than an opinion, so CLDR was asked — through the `intl`
/// package this app already depends on, `numberFormatSymbols[locale]`:
///
///     ur   ZERO_DIGIT = '0'   1,234,567
///     fa   ZERO_DIGIT = '۰'   ۱٬۲۳۴٬۵۶۷
///     ps   ZERO_DIGIT = '۰'   ۱٬۲۳۴٬۵۶۷
///     ar   ZERO_DIGIT = '0'   1,234,567
///
/// Persian and Pashto default to the **extended** Arabic-Indic digits
/// (U+06F0 ۰۱۲۳…, which are not the Arabic U+0660 ٠١٢٣…). **Urdu defaults to
/// Latin**, and so, in modern CLDR, does Arabic itself.
///
/// So the two cases are different in kind, and both are deliberate:
///
///  * **Urdu gets Latin** because that is the standard default and nobody
///    asked for anything else. Not "for consistency" — it is simply correct.
///  * **Arabic gets Arabic-Indic** because the owner wants it in the Arabic
///    UI — the clock, the Hijri line, the prayer notifications — which is a
///    deliberate departure from CLDR, not an accident. `test/digits_test.dart`
///    pins both so neither is "fixed" later by someone reading only half of
///    this.
library;

const String _latin = '0123456789';
const String _arabicIndic = '٠١٢٣٤٥٦٧٨٩';

/// [text] with its Latin digits replaced by the digits [localeCode] writes,
/// or unchanged when that language writes Latin digits.
///
/// Non-digit characters pass through untouched, so this is safe on a whole
/// formatted string — «١٠ دقائق», «٠٦:١٣», «٢٨ ربيع الأول ١٤٤٨ هـ».
String localizeDigits(String text, String localeCode) {
  if (localeCode != 'ar') return text;
  final b = StringBuffer();
  for (final ch in text.split('')) {
    final i = _latin.indexOf(ch);
    b.write(i >= 0 ? _arabicIndic[i] : ch);
  }
  return b.toString();
}
