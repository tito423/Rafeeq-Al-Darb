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

import 'package:easy_localization/easy_localization.dart';

const String _latin = '0123456789';
const String _arabicIndic = '٠١٢٣٤٥٦٧٨٩';
const String _extendedArabicIndic = '۰۱۲۳۴۵۶۷۸۹';

/// [text] with Arabic-Indic (٠١٢…) and extended Arabic-Indic (۰۱۲…) digits
/// turned into ASCII — for PARSING, the inverse of [localizeDigits].
///
/// A stored «٠٤:٤٤» is what `DateFormat('HH:mm')` writes under `ar_EG` or
/// `fa`, and a `\d` pattern or `int.tryParse` reads nothing in it. That turned
/// a Fajr four hours away into «٨٧٥٩» hours on a real phone.
String asciiDigits(String text) {
  final out = StringBuffer();
  for (final ch in text.runes) {
    final c = String.fromCharCode(ch);
    var i = _arabicIndic.indexOf(c);
    if (i < 0) i = _extendedArabicIndic.indexOf(c);
    out.write(i < 0 ? c : _latin[i]);
  }
  return out.toString();
}

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

/// The language the UI is currently rendering in, for the two helpers below.
///
/// WHY A GLOBAL, when `context.locale.languageCode` is right there. Because
/// the defect this exists to kill was systemic, not local: **fifty-five**
/// call sites printed a number into an Arabic sentence with Latin digits, and
/// they were being found one screen at a time by opening the app and looking.
/// The library authors list put both systems on a single row — the author's
/// name «(٧٠١ - ٧٧٤ هـ)» carries Arabic-Indic digits from the catalogue, and
/// the line beneath it read «توفي 774 هـ ▪ 11 كتابًا». Patching each site by
/// hand is exactly how the previous fifteen were missed.
///
/// Several of those sites are not widgets and have no `BuildContext` at all —
/// `BookEntry.deathLabel()` in the data layer, `surahLabel()` in
/// `audio_common.dart` — so a context-based helper could not have covered
/// them, and threading a locale parameter through the data layer to format a
/// numeral is worse than this.
///
/// It is written from exactly one place: `RafeeqApp.build`, which is the one
/// widget that rebuilds on every locale change and the same seam that already
/// drives `appLocaleProvider` and the reader's translation language. It is
/// read-only everywhere else.
String uiLanguageCode = 'ar';

/// `.tr()` with the reader's own numerals.
///
/// Use in place of `key.tr(...)` wherever the result can contain a number.
String trn(String key, {List<String>? args, Map<String, String>? namedArgs}) =>
    localizeDigits(
        key.tr(args: args, namedArgs: namedArgs), uiLanguageCode);

/// `.plural()` with the reader's own numerals.
///
/// Keeps easy_localization's CLDR plural selection intact — Arabic has six
/// categories and «١٠ دقائق» is not «١٠ دقيقة» (trap #30) — and only maps the
/// digits afterwards.
String pluralN(String key, num value,
        {List<String>? args, Map<String, String>? namedArgs}) =>
    localizeDigits(
        key.plural(value, args: args, namedArgs: namedArgs), uiLanguageCode);
