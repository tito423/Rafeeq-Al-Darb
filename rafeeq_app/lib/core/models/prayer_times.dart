/// Prayer times model (values are HH:mm 24h strings from AlAdhan API).
class PrayerTimes {
  final String fajr;
  final String sunrise;
  final String dhuhr;
  final String asr;
  final String maghrib;
  final String isha;
  final String cityName;

  /// Real reverse-geocoded country name (P3‑22's Home location line,
  /// "دبي، الإمارات العربية المتحدة") — empty when geocoding failed/was
  /// unavailable; never invented.
  final String countryName;
  final String hijriDate;
  final String gregorianDate;

  const PrayerTimes({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.cityName,
    this.countryName = '',
    required this.hijriDate,
    required this.gregorianDate,
  });

  factory PrayerTimes.empty() => const PrayerTimes(
        fajr: '--:--',
        sunrise: '--:--',
        dhuhr: '--:--',
        asr: '--:--',
        maghrib: '--:--',
        isha: '--:--',
        cityName: '',
        countryName: '',
        hijriDate: '',
        gregorianDate: '',
      );

  bool get isEmpty => fajr == '--:--';

  /// A copy with each timing shifted by [minuteOffsets] (see
  /// `PrayerAdjustments`). Returns `this` untouched when there is nothing to
  /// apply or the times were never fetched, so an empty card can't be turned
  /// into a plausible-looking wrong one.
  PrayerTimes withOffsets(
    Map<String, int> minuteOffsets,
    String Function(String, int) shift,
  ) {
    if (isEmpty || minuteOffsets.values.every((v) => v == 0)) return this;
    return PrayerTimes(
      fajr: shift(fajr, minuteOffsets['fajr'] ?? 0),
      sunrise: shift(sunrise, minuteOffsets['sunrise'] ?? 0),
      dhuhr: shift(dhuhr, minuteOffsets['dhuhr'] ?? 0),
      asr: shift(asr, minuteOffsets['asr'] ?? 0),
      maghrib: shift(maghrib, minuteOffsets['maghrib'] ?? 0),
      isha: shift(isha, minuteOffsets['isha'] ?? 0),
      cityName: cityName,
      countryName: countryName,
      hijriDate: hijriDate,
      gregorianDate: gregorianDate,
    );
  }

  String byName(String name) {
    switch (name) {
      case 'fajr':
        return fajr;
      case 'sunrise':
        return sunrise;
      case 'dhuhr':
        return dhuhr;
      case 'asr':
        return asr;
      case 'maghrib':
        return maghrib;
      case 'isha':
        return isha;
    }
    return fajr;
  }
}
