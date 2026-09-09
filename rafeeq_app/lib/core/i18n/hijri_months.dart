import 'package:easy_localization/easy_localization.dart';

/// The twelve Hijri month names, in the app's current language.
///
/// There were two hardcoded tables of these — one in `home_screen.dart` and
/// one in `prayer_status_notification.dart` — and between them they covered
/// Arabic and English only, so a French, Spanish, Portuguese, Russian or Urdu
/// reader got the English transliteration on the Home card and in the
/// persistent prayer notification. Both now read from here, and here reads
/// from the locale files, so a month name is translated exactly once.
///
/// [month] is 1..12 as the Hijri calendar numbers them; anything else returns
/// an empty string rather than throwing, because a date formatter is not the
/// place to crash an app.
String hijriMonthName(int month) =>
    (month < 1 || month > 12) ? '' : 'hijri.m$month'.tr();
