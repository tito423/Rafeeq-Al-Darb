/// The landmark events of the Hijri year — in the reader's own language.
///
/// «مش ينفع تعرض احداث بالعربي واللغه المختارة انجليزي» — and the day-by-day
/// Hijri record the app carries has no counterpart in any other language:
/// Arabic Wikipedia is the only encyclopaedia that keeps per-Hijri-day pages,
/// and English Wikipedia answers 404 for `17_Ramadan`. So a French or Urdu
/// reader used to get a wall of Arabic with an apology over it.
///
/// This is what they get instead: the days everyone means when they say «أهم
/// الأحداث» — Badr, the Hijra, Hattin, Ain Jalut, the fall of Granada — each
/// written once as a translation key and therefore present in all seven
/// languages, exactly like every other string in the app.
///
/// **Each date below was read out of the bundled Hijri dataset**, not recalled:
/// the day, the month and the Hijri year are the ones
/// `assets/data/on_this_day_hijri_ar.json` records for that event, and
/// `test/hijri_landmarks_test.dart` fails if a landmark ever names a day its
/// own source does not.
///
/// It is a short list on purpose. Translating all 5,747 lines of the Arabic
/// record faithfully is a piece of work in its own right; this covers the days
/// a reader is most likely to be told about, and it grows by adding a row here
/// and seven strings to the locale files.
library;

import 'package:easy_localization/easy_localization.dart';

import 'on_this_day_repository.dart';

class HijriLandmark {
  /// 1..12, as the Hijri calendar numbers the months.
  final int month;

  /// The day of that month.
  final int day;

  /// The Hijri year it happened in.
  final int year;

  /// `hijri_day.<key>` in the locale files.
  final String key;

  const HijriLandmark({
    required this.month,
    required this.day,
    required this.year,
    required this.key,
  });
}

const hijriLandmarks = <HijriLandmark>[
  HijriLandmark(month: 1, day: 1, year: 1, key: 'hijra'),
  HijriLandmark(month: 1, day: 10, year: 61, key: 'karbala'),
  HijriLandmark(month: 1, day: 21, year: 897, key: 'granada'),
  HijriLandmark(month: 1, day: 30, year: 7, key: 'khaybar'),
  HijriLandmark(month: 2, day: 14, year: 656, key: 'baghdad'),
  HijriLandmark(month: 3, day: 12, year: 1, key: 'arrival_madinah'),
  HijriLandmark(month: 3, day: 12, year: 11, key: 'abu_bakr'),
  HijriLandmark(month: 4, day: 24, year: 583, key: 'hattin'),
  HijriLandmark(month: 4, day: 26, year: 857, key: 'constantinople_siege'),
  HijriLandmark(month: 5, day: 5, year: 8, key: 'mutah'),
  HijriLandmark(month: 5, day: 20, year: 857, key: 'constantinople'),
  HijriLandmark(month: 5, day: 24, year: 359, key: 'azhar'),
  HijriLandmark(month: 6, day: 10, year: 36, key: 'jamal'),
  HijriLandmark(month: 7, day: 5, year: 15, key: 'yarmouk'),
  HijriLandmark(month: 7, day: 12, year: 479, key: 'zallaqa'),
  HijriLandmark(month: 8, day: 13, year: 15, key: 'qadisiyyah'),
  HijriLandmark(month: 9, day: 17, year: 2, key: 'badr'),
  HijriLandmark(month: 9, day: 17, year: 223, key: 'amorium'),
  HijriLandmark(month: 9, day: 25, year: 658, key: 'ain_jalut'),
  HijriLandmark(month: 9, day: 28, year: 92, key: 'guadalete'),
  HijriLandmark(month: 10, day: 4, year: 8, key: 'hunayn'),
  HijriLandmark(month: 10, day: 17, year: 5, key: 'khandaq'),
  HijriLandmark(month: 11, day: 16, year: 6, key: 'hudaybiyyah'),
  HijriLandmark(month: 12, day: 5, year: 10, key: 'farewell_hajj'),
];

/// The landmarks of one Hijri day, as the sheet's own row type.
///
/// The text is resolved through `.tr()` at call time, so it is in whatever
/// language the reader has chosen — which is the whole point of this file.
List<HistoricalEvent> hijriLandmarksFor(int month, int day) {
  final out = <HistoricalEvent>[];
  for (final l in hijriLandmarks) {
    if (l.month == month && l.day == day) {
      out.add(HistoricalEvent(
        year: l.year,
        text: 'hijri_day.${l.key}'.tr(),
      ));
    }
  }
  return out;
}
