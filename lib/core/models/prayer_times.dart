/// Prayer times model
class PrayerTimes {
  final String fajr;
  final String sunrise;
  final String dhuhr;
  final String asr;
  final String maghrib;
  final String isha;
  final String date;
  final String hijriDate;
  final String city;

  const PrayerTimes({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.date,
    required this.hijriDate,
    required this.city,
  });

  factory PrayerTimes.empty() => const PrayerTimes(
        fajr: '--:--',
        sunrise: '--:--',
        dhuhr: '--:--',
        asr: '--:--',
        maghrib: '--:--',
        isha: '--:--',
        date: '',
        hijriDate: '',
        city: '',
      );

  factory PrayerTimes.fromAlAdhanJson(
    Map<String, dynamic> timings,
    Map<String, dynamic> dateInfo,
    String cityName, {
    Map<String, int>? offsets,
  }) {
    String fmt(String t, String key) {
      if (t.isEmpty) return '--:--';
      // Remove timezone suffix like " (EET)"
      String timeOnly = t.split(' ').first;
      
      if (offsets != null && offsets[key] != null && offsets[key] != 0) {
        try {
          final parts = timeOnly.split(':');
          final h = int.parse(parts[0]);
          final m = int.parse(parts[1]);
          final dt = DateTime(0, 1, 1, h, m).add(Duration(minutes: offsets[key]!));
          timeOnly = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        } catch (_) {}
      }
      return timeOnly;
    }

    final hijri = dateInfo['hijri'];
    final hijriDay = hijri?['day'] ?? '';
    final hijriMonth = hijri?['month']?['ar'] ?? '';
    final hijriYear = hijri?['year'] ?? '';
    final hijriStr = '$hijriDay $hijriMonth $hijriYear';

    final gregorian = dateInfo['gregorian'];
    final gDate = gregorian?['date'] ?? '';

    return PrayerTimes(
      fajr: fmt(timings['Fajr'] ?? '', 'الفجر'),
      sunrise: fmt(timings['Sunrise'] ?? '', 'الشروق'),
      dhuhr: fmt(timings['Dhuhr'] ?? '', 'الظهر'),
      asr: fmt(timings['Asr'] ?? '', 'العصر'),
      maghrib: fmt(timings['Maghrib'] ?? '', 'المغرب'),
      isha: fmt(timings['Isha'] ?? '', 'العشاء'),
      date: gDate,
      hijriDate: hijriStr,
      city: cityName,
    );
  }

  List<PrayerEntry> get prayerList => [
        PrayerEntry('الفجر', fajr, 'fajr'),
        PrayerEntry('الشروق', sunrise, 'sunrise'),
        PrayerEntry('الظهر', dhuhr, 'dhuhr'),
        PrayerEntry('العصر', asr, 'asr'),
        PrayerEntry('المغرب', maghrib, 'maghrib'),
        PrayerEntry('العشاء', isha, 'isha'),
      ];
}

class PrayerEntry {
  final String name;
  final String time;
  final String key;
  const PrayerEntry(this.name, this.time, this.key);
}
