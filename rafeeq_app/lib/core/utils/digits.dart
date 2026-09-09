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
/// ARABIC ONLY, DELIBERATELY.
/// Urdu writes its own extended Arabic-Indic digits (U+06F0 ۰۱۲۳…), which are
/// *not* the Arabic ones (U+0660 ٠١٢٣…). The Urdu build renders every other
/// number — the Hijri line, the prayer tiles, the sizes — in Latin digits, so
/// shaping only the reminder would make Urdu inconsistent with itself rather
/// than consistent with Urdu. Left as it is on purpose; if it is ever changed
/// it has to be changed everywhere at once, and looked at on a device.
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
