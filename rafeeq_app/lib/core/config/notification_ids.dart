/// Single source of notification IDs, including native foreground services.
/// Gradle exports the native constants to BuildConfig from THIS file.
class NotificationIds {
  static const int media = 1124; // audio_service's fixed media notification
  static const int azkar = 6001;
  static const int prayerStatus = 6100;
  static const int prayerPre = 7100;
  static const int prayerPost = 7200;
  static const int prayerIqama = 7600;
  static const int fasting = 7700;
  static const int quotes = 7500;
  static const int tasbih = 7400;
  static const int sunanLegacy = 8000;
  static const int sunan = 9000;
  static const int adhan = 12000;
  static const int assistant = 13000;
  static const int downloadForeground = 14000;
  static const int downloadItems = 14100;
  static const int downloadProgress = 15000;
  static const int downloadComplete = 16000;
  // Preserve existing shelf IDs; reserve room for 100 million stable shelf IDs.
  static const int shelves = 20000;
  static const int khatma = 1100000000;

  static const int azkarCount = 3;
  static const int prayerStatusCount = 2;
  static const int prayerCount = 5;
  static const int fastingCount = 50;
  static const int quotesCount = 24;
  static const int tasbihCount = 20;
  static const int sunanLegacyCount = 115;
  static const int sunanCount = 1148;
  static const int downloadItemsCount = 90;
  static const int downloadCount = 300;
  static const int shelvesCount = 1000000000;
  static const int khatmaCount = 1000000;

  // Upgrade-only IDs. They are deliberately NOT part of the active ranges.
  static const int legacyKhatma = 7000;
  static const int legacyKhatmaCount = 900;
  static const int legacyDownloadProgress = 4700;
  static const int legacyDownloadForeground = 4800;
  static const int legacyAssistant = 4711;

  static const ranges = <NotificationIdRange>[
    NotificationIdRange('media', media, 1),
    NotificationIdRange('azkar', azkar, azkarCount),
    NotificationIdRange('prayerStatus', prayerStatus, prayerStatusCount),
    NotificationIdRange('prayerPre', prayerPre, prayerCount),
    NotificationIdRange('prayerPost', prayerPost, prayerCount),
    NotificationIdRange('prayerIqama', prayerIqama, prayerCount),
    NotificationIdRange('fasting', fasting, fastingCount),
    NotificationIdRange('quotes', quotes, quotesCount),
    NotificationIdRange('tasbih', tasbih, tasbihCount),
    NotificationIdRange('sunanLegacy', sunanLegacy, sunanLegacyCount),
    NotificationIdRange('sunan', sunan, sunanCount),
    NotificationIdRange('adhan', adhan, 1),
    NotificationIdRange('assistant', assistant, 1),
    NotificationIdRange('downloadForeground', downloadForeground, 1),
    NotificationIdRange('downloadItems', downloadItems, downloadItemsCount),
    NotificationIdRange('downloadProgress', downloadProgress, downloadCount),
    NotificationIdRange('downloadComplete', downloadComplete, downloadCount),
    NotificationIdRange('shelves', shelves, shelvesCount),
    NotificationIdRange('khatma', khatma, khatmaCount),
  ];

  static int shelfId(int shelf, int weekday) {
    if (shelf < 1 || weekday < 1 || weekday > 7) {
      throw ArgumentError('Invalid shelf reminder coordinates');
    }
    final id = shelves + shelf * 10 + weekday;
    if (id >= shelves + shelvesCount) {
      throw StateError('Shelf notification range exhausted');
    }
    return id;
  }

  /// Allocate without hashing collisions. The complete set is re-armed when
  /// it changes, so deleting one plan cannot leave an old ordinal scheduled.
  static Map<String, int> khatmaIds(Iterable<String> ids) {
    final sorted = ids.toSet().toList()..sort();
    if (sorted.length > khatmaCount) {
      throw StateError('Khatma notification range exhausted');
    }
    return {for (var i = 0; i < sorted.length; i++) sorted[i]: khatma + i};
  }
}

class NotificationIdRange {
  final String name;
  final int start;
  final int count;
  const NotificationIdRange(this.name, this.start, this.count);
  int get endExclusive => start + count;
  bool contains(int id) => id >= start && id < endExclusive;
}
