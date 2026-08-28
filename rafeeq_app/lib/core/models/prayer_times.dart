/// Prayer times model (values are HH:mm 24h strings from AlAdhan API).
class PrayerTimes {
  final String fajr;
  final String sunrise;
  final String dhuhr;
  final String asr;
  final String maghrib;
  final String isha;
  final String cityName;
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
        hijriDate: '',
        gregorianDate: '',
      );

  bool get isEmpty => fajr == '--:--';

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
