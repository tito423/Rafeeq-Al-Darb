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

/// The same twelve months **always in Arabic**, whatever the app's language.
///
/// Not a duplicate of [hijriMonthName]: this one is not for reading, it is for
/// addressing. Arabic Wikipedia's per-Hijri-day pages are titled «17 رمضان»
/// and «12 ربيع الأول», so the link under the Hijri day sheet has to build
/// that exact title even when the reader is on the French UI — a translated
/// month name would point at a page that does not exist.
const _arabicMonths = <String>[
  'محرم', 'صفر', 'ربيع الأول', 'ربيع الآخر', 'جمادى الأولى',
  'جمادى الآخرة', 'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة',
];

String hijriMonthNameAr(int month) =>
    (month < 1 || month > 12) ? '' : _arabicMonths[month - 1];
