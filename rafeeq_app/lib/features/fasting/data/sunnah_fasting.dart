import 'package:hijri/hijri_calendar.dart';

/// «تذكير بصيام السنن كالاثنين والخميس والأيام البيض».
///
/// Which evenings get a reminder, computed — not a weekly alarm that fires
/// blindly. A weekly Monday alarm would remind a reader to fast a sunnah fast
/// on the Monday of Eid, when fasting is forbidden, and on every Monday of
/// Ramadan, when the fast is already obligatory. And the thirteenth of Dhu
/// al-Hijjah is a «white day» by the calendar and a day of tashriq by the
/// sunnah, on which fasting is forbidden. So every candidate day is converted
/// to the Hijri calendar — with the reader's own Hijri correction, the one on
/// the prayer screen — and checked.

/// The words the reminder quotes, cut VERBATIM out of `hadith.db` —
/// `test/sunnah_fasting_test.dart` fails if either stops being a substring of
/// the numbered hadith it names. Each carries its grading as at-Tirmidhi
/// himself gave it, in his own words at the end of the hadith.
class FastingHadith {
  final String text;

  /// Book key and number in `hadith.db`, for the test.
  final String bookKey;
  final int number;

  /// Translation key for the citation line, with the grader named.
  final String citationKey;

  const FastingHadith(this.text, this.bookKey, this.number, this.citationKey);
}

const mondayThursdayHadith = FastingHadith(
  'تُعْرَضُ الأَعْمَالُ يَوْمَ الاِثْنَيْنِ وَالْخَمِيسِ فَأُحِبُّ أَنْ يُعْرَضَ عَمَلِي وَأَنَا صَائِمٌ',
  'tirmidhi',
  747,
  'fasting.cite_747',
);

const whiteDaysHadith = FastingHadith(
  'يَا أَبَا ذَرٍّ إِذَا صُمْتَ مِنَ الشَّهْرِ ثَلاَثَةَ أَيَّامٍ فَصُمْ ثَلاَثَ عَشْرَةَ وَأَرْبَعَ عَشْرَةَ وَخَمْسَ عَشْرَةَ',
  'tirmidhi',
  761,
  'fasting.cite_761',
);

enum FastKind { monday, thursday, whiteDays }

class FastingReminder {
  /// When the notification fires — the evening before the fast.
  final DateTime at;

  /// The day to be fasted (the first of the three for [FastKind.whiteDays]).
  final DateTime fastDay;
  final FastKind kind;

  const FastingReminder(this.at, this.fastDay, this.kind);

  @override
  String toString() => '$kind fast=${fastDay.toIso8601String().substring(0, 10)}';
}

/// The Hijri date of [day], shifted by the reader's correction in days.
HijriCalendar hijriOf(DateTime day, int offsetDays) =>
    HijriCalendar.fromDate(day.add(Duration(days: offsetDays)));

/// Whether a VOLUNTARY fast may be kept on this Hijri date.
///
/// False in Ramadan (the fast is obligatory, not a sunnah to be reminded of),
/// on the two Eids, and on the days of tashriq (11–13 Dhu al-Hijjah).
bool voluntaryFastAllowed(HijriCalendar h) {
  if (h.hMonth == 9) return false; // Ramadan
  if (h.hMonth == 10 && h.hDay == 1) return false; // Eid al-Fitr
  if (h.hMonth == 12 && h.hDay >= 10 && h.hDay <= 13) return false; // Adha + tashriq
  return true;
}

/// Every reminder due after [now] within [days] days.
List<FastingReminder> planFastingReminders({
  required DateTime now,
  required int hijriOffsetDays,
  required bool mondayThursday,
  required bool whiteDays,
  required int hour,
  required int minute,
  int days = 60,
}) {
  final out = <FastingReminder>[];
  // Hijri months whose white-days reminder was actually planned.
  final remindedWhite = <int>{};
  final today = DateTime(now.year, now.month, now.day);
  for (var i = 1; i <= days; i++) {
    final day = DateTime(today.year, today.month, today.day + i);
    final eve = DateTime(day.year, day.month, day.day - 1, hour, minute);
    if (!eve.isAfter(now)) continue;
    final h = hijriOf(day, hijriOffsetDays);
    final isWhite = h.hDay >= 13 && h.hDay <= 15;

    if (whiteDays && h.hDay == 13) {
      // All three must be permitted — which in practice rules out Ramadan
      // and Dhu al-Hijjah, whose thirteenth is a day of tashriq.
      final allOk = [0, 1, 2].every((k) => voluntaryFastAllowed(
          hijriOf(DateTime(day.year, day.month, day.day + k), hijriOffsetDays)));
      if (allOk) {
        out.add(FastingReminder(eve, day, FastKind.whiteDays));
        remindedWhite.add(h.hYear * 12 + h.hMonth);
      }
    }

    if (mondayThursday &&
        (day.weekday == DateTime.monday || day.weekday == DateTime.thursday) &&
        voluntaryFastAllowed(h) &&
        // Already inside the white days the reader was reminded of: one
        // reminder for the evening, not two.
        !(isWhite && remindedWhite.contains(h.hYear * 12 + h.hMonth))) {
      out.add(FastingReminder(
        eve,
        day,
        day.weekday == DateTime.monday ? FastKind.monday : FastKind.thursday,
      ));
    }
  }
  return out;
}
