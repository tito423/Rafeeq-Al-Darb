import 'package:adhan/adhan.dart' as adhan;
import 'package:hijri/hijri_calendar.dart';

import '../../../core/i18n/proper_name.dart';

/// Every prayer-time calculation method the app offers, with the actual
/// parameters the organisation behind it publishes.
///
/// WHERE THE NUMBERS COME FROM
/// The app calculates offline (`PrayerTimesService` uses the `adhan`
/// package), so each method here has to state its own angles. They are **not**
/// written from memory: they are AlAdhan's published method table
/// (`https://api.aladhan.com/v1/methods`), refetched by
/// `scripts/build_prayer_method_fixtures.py`, and
/// `test/calculation_methods_test.dart` asserts every angle in this list
/// against that file — and then asserts the times the app computes against a
/// grid of 168 real answers from the same API (21 methods × 4 cities × 2
/// dates, requested in UTC so nothing has to be guessed about timezones).
///
/// THE OFFSETS BELOW WERE MEASURED, NOT COPIED
/// Angles alone did not reproduce the published times. Six methods disagreed,
/// always by the same amount in all eight city/date combinations, so the
/// difference is a per-method offset rather than noise:
///
///   * Turkey  — sunrise −7, dhuhr +5, asr +4, maghrib +7
///   * Dubai   — dhuhr +3, maghrib +3
///   * Morocco — dhuhr +5, maghrib +5
///   * Lisbon  — dhuhr +5, isha +3
///   * Jordan and Lisbon also add minutes to Maghrib, which the table does
///     publish (`"Maghrib": "5 min"`).
///
/// Those are `scripts/build_prayer_method_fixtures.py` measurements, printed
/// per method and per prayer, and the timings test fails if any of them drifts.
///
/// UMM AL-QURA ADDS HALF AN HOUR TO ISHA IN RAMADAN
/// Not a quirk of the API — it is how the Umm al-Qura calendar is published,
/// and the `adhan` package says so in its own doc comment without
/// implementing it. Without it the app's Isha was **30 minutes early** for
/// every Umm al-Qura reader for the whole of Ramadan, which is the month it
/// matters most. AlAdhan applies it to Umm al-Qura only — the Gulf and Qatar
/// methods use the same 90-minute interval and were measured NOT to move.
///
/// ONE METHOD IS DELIBERATELY ABSENT, AND SO ARE TWO OTHERS
/// AlAdhan also publishes `MOONSIGHTING` (id 15), whose Fajr and Isha come
/// from a seasonal table rather than an angle. The `adhan` package has its own
/// implementation of that table and the two disagree by up to **9 minutes**,
/// with no constant offset to correct. Shipping a "Moonsighting Committee"
/// method whose times are not that committee's is exactly what CLAUDE.md §1.1
/// forbids, so it is not offered.
/// `JAFARI` (id 0) and `TEHRAN` (id 7) compute Maghrib from the sun reaching
/// 4°/4.5° below the horizon rather than from sunset, which is a Shia fiqh
/// position and not a neutral parameter. This is a Sunni app and the owner has
/// not asked for them, so they are left out rather than shipped unexplained.
///
/// The [id]s are AlAdhan's own, which is what the app already persists in
/// `SharedPreferences` (`adhan_calc_method_v1`) — 4 = Umm al-Qura, 3 = MWL,
/// 5 = Egypt, 2 = ISNA — so every existing install keeps the method it had.
///
/// NAMES ARE NOT TRANSLATED
/// An organisation's name is a proper name (`properName`, see
/// `core/i18n/proper_name.dart`): Arabic for the ar/ur reader, Latin for the
/// other five. No new translation keys, and no «رابطة العالم الإسلامي»
/// rewritten into French.
class PrayerCalculationMethod {
  /// AlAdhan's method id. Persisted; never renumber one.
  final int id;

  /// The organisation's own name, Arabic and Latin.
  final String nameAr;
  final String nameEn;

  /// Sun angle below the horizon for Fajr.
  final double fajrAngle;

  /// Sun angle for Isha, when the method uses one.
  final double? ishaAngle;

  /// Minutes after sunset, when the method uses a fixed interval instead of
  /// an angle (Umm al-Qura and the Gulf: 90; Qatar: 90; Lisbon: 77).
  final int ishaInterval;

  /// Per-prayer offsets this method applies on top of the astronomy. All
  /// measured against the published timings — see the class doc.
  final int sunriseOffsetMinutes;
  final int dhuhrOffsetMinutes;
  final int asrOffsetMinutes;
  final int maghribOffsetMinutes;
  final int ishaOffsetMinutes;

  /// Extra minutes added to Isha during Ramadan. 30 for Umm al-Qura, 0 for
  /// everything else.
  final int ramadanIshaBonusMinutes;

  const PrayerCalculationMethod({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.fajrAngle,
    this.ishaAngle,
    this.ishaInterval = 0,
    this.sunriseOffsetMinutes = 0,
    this.dhuhrOffsetMinutes = 0,
    this.asrOffsetMinutes = 0,
    this.maghribOffsetMinutes = 0,
    this.ishaOffsetMinutes = 0,
    this.ramadanIshaBonusMinutes = 0,
  });

  /// The name in the script the reader reads.
  String get name => properName(nameAr, nameEn);

  /// The parameters this method feeds to the `adhan` package.
  ///
  /// [madhab] and [highLatitudeRule] are the reader's own settings and are
  /// applied on top — they are not part of the method. [date] is only used to
  /// decide whether Ramadan's Isha bonus applies.
  adhan.CalculationParameters parameters({
    DateTime? date,
    adhan.Madhab madhab = adhan.Madhab.shafi,
    adhan.HighLatitudeRule highLatitudeRule =
        adhan.HighLatitudeRule.twilight_angle,
  }) {
    var isha = ishaOffsetMinutes;
    if (ramadanIshaBonusMinutes != 0 && date != null && _isRamadan(date)) {
      isha += ramadanIshaBonusMinutes;
    }

    return adhan.CalculationParameters(
      fajrAngle: fajrAngle,
      // `twilight_angle` needs an Isha angle to size the night portions, and
      // a method that sets an interval has none. The angle is only read for
      // that bound: the package takes the interval branch for Isha itself
      // whenever `ishaInterval > 0`, and never reaches the angle-based
      // `safeIsha`. Without this, Fajr in London in June came out 78–89
      // minutes away from the published time for Umm al-Qura, the Gulf, Qatar
      // and Lisbon, because the rule silently fell back to half the night.
      ishaAngle: ishaAngle ?? (ishaInterval > 0 ? fajrAngle : null),
      ishaInterval: ishaInterval,
      madhab: madhab,
      highLatitudeRule: highLatitudeRule,
      methodAdjustments: adhan.PrayerAdjustments(
        sunrise: sunriseOffsetMinutes,
        dhuhr: dhuhrOffsetMinutes,
        asr: asrOffsetMinutes,
        maghrib: maghribOffsetMinutes,
        isha: isha,
      ),
    );
  }

  /// Ramadan is the ninth Hijri month. The reader's own ±3-day Hijri
  /// correction is deliberately not applied here: this is the calendar Umm
  /// al-Qura publishes its own timetable against, not the date on the card.
  static bool _isRamadan(DateTime date) =>
      HijriCalendar.fromDate(date).hMonth == 9;
}

/// The catalogue, in the order the picker shows it: the four the app already
/// had first (they are the ones the owner's readers use), then the rest by
/// region.
const kPrayerCalculationMethods = <PrayerCalculationMethod>[
  PrayerCalculationMethod(
    id: 4,
    nameAr: 'جامعة أم القرى، مكة المكرمة',
    nameEn: 'Umm Al-Qura University, Makkah',
    fajrAngle: 18.5,
    ishaInterval: 90,
    ramadanIshaBonusMinutes: 30,
  ),
  PrayerCalculationMethod(
    id: 5,
    nameAr: 'الهيئة المصرية العامة للمساحة',
    nameEn: 'Egyptian General Authority of Survey',
    fajrAngle: 19.5,
    ishaAngle: 17.5,
  ),
  PrayerCalculationMethod(
    id: 3,
    nameAr: 'رابطة العالم الإسلامي',
    nameEn: 'Muslim World League',
    fajrAngle: 18,
    ishaAngle: 17,
  ),
  PrayerCalculationMethod(
    id: 2,
    nameAr: 'الجمعية الإسلامية لأمريكا الشمالية',
    nameEn: 'Islamic Society of North America (ISNA)',
    fajrAngle: 15,
    ishaAngle: 15,
  ),
  PrayerCalculationMethod(
    id: 1,
    nameAr: 'جامعة العلوم الإسلامية، كراتشي',
    nameEn: 'University of Islamic Sciences, Karachi',
    fajrAngle: 18,
    ishaAngle: 18,
  ),
  PrayerCalculationMethod(
    id: 8,
    nameAr: 'منطقة الخليج',
    nameEn: 'Gulf Region',
    fajrAngle: 19.5,
    ishaInterval: 90,
  ),
  PrayerCalculationMethod(
    id: 16,
    nameAr: 'دبي',
    nameEn: 'Dubai',
    fajrAngle: 18.2,
    ishaAngle: 18.2,
    dhuhrOffsetMinutes: 3,
    maghribOffsetMinutes: 3,
  ),
  PrayerCalculationMethod(
    id: 9,
    nameAr: 'الكويت',
    nameEn: 'Kuwait',
    fajrAngle: 18,
    ishaAngle: 17.5,
  ),
  PrayerCalculationMethod(
    id: 10,
    nameAr: 'قطر',
    nameEn: 'Qatar',
    fajrAngle: 18,
    ishaInterval: 90,
  ),
  PrayerCalculationMethod(
    id: 23,
    nameAr: 'وزارة الأوقاف والشؤون والمقدسات الإسلامية، الأردن',
    nameEn: 'Ministry of Awqaf, Islamic Affairs and Holy Places, Jordan',
    fajrAngle: 18,
    ishaAngle: 18,
    maghribOffsetMinutes: 5,
  ),
  PrayerCalculationMethod(
    id: 21,
    nameAr: 'المغرب',
    nameEn: 'Morocco',
    fajrAngle: 19,
    ishaAngle: 17,
    dhuhrOffsetMinutes: 5,
    maghribOffsetMinutes: 5,
  ),
  PrayerCalculationMethod(
    id: 19,
    nameAr: 'الجزائر',
    nameEn: 'Algeria',
    fajrAngle: 18,
    ishaAngle: 17,
  ),
  PrayerCalculationMethod(
    id: 18,
    nameAr: 'تونس',
    nameEn: 'Tunisia',
    fajrAngle: 18,
    ishaAngle: 18,
  ),
  PrayerCalculationMethod(
    id: 13,
    nameAr: 'رئاسة الشؤون الدينية، تركيا',
    nameEn: 'Diyanet İşleri Başkanlığı, Turkey',
    fajrAngle: 18,
    ishaAngle: 17,
    sunriseOffsetMinutes: -7,
    dhuhrOffsetMinutes: 5,
    asrOffsetMinutes: 4,
    maghribOffsetMinutes: 7,
  ),
  PrayerCalculationMethod(
    id: 14,
    nameAr: 'الإدارة الدينية لمسلمي روسيا',
    nameEn: 'Spiritual Administration of Muslims of Russia',
    fajrAngle: 16,
    ishaAngle: 15,
  ),
  PrayerCalculationMethod(
    id: 12,
    nameAr: 'اتحاد المنظمات الإسلامية في فرنسا',
    nameEn: 'Union des Organisations Islamiques de France',
    fajrAngle: 12,
    ishaAngle: 12,
  ),
  PrayerCalculationMethod(
    id: 22,
    nameAr: 'الجالية الإسلامية بلشبونة',
    nameEn: 'Comunidade Islâmica de Lisboa',
    fajrAngle: 18,
    ishaInterval: 77,
    dhuhrOffsetMinutes: 5,
    maghribOffsetMinutes: 3,
    ishaOffsetMinutes: 3,
  ),
  PrayerCalculationMethod(
    id: 17,
    nameAr: 'دائرة التنمية الإسلامية الماليزية (جاكيم)',
    nameEn: 'Jabatan Kemajuan Islam Malaysia (JAKIM)',
    fajrAngle: 20,
    ishaAngle: 18,
  ),
  PrayerCalculationMethod(
    id: 20,
    nameAr: 'وزارة الشؤون الدينية، إندونيسيا',
    nameEn: 'Kementerian Agama Republik Indonesia',
    fajrAngle: 20,
    ishaAngle: 18,
  ),
  PrayerCalculationMethod(
    id: 11,
    nameAr: 'المجلس الديني الإسلامي، سنغافورة',
    nameEn: 'Majlis Ugama Islam Singapura, Singapore',
    fajrAngle: 20,
    ishaAngle: 18,
  ),
];

/// The method with [id], or Umm al-Qura when the stored id is one the app no
/// longer offers — never a thrown exception on a settings read.
PrayerCalculationMethod prayerCalculationMethodById(int id) {
  for (final m in kPrayerCalculationMethods) {
    if (m.id == id) return m;
  }
  return kPrayerCalculationMethods.first;
}
