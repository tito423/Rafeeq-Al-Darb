/// Central, secret-free configuration for remote content.
///
/// Every URL here is a real, public endpoint. No credentials live in the
/// client (the old build embedded Cloudflare R2 keys — removed for good).
abstract final class AppConfig {
  /// Real Madani mushaf page images (King Fahd Complex scans, 1024px),
  /// served by the Quran Android project CDN.
  static const String mushafImageBase =
      'https://android.quran.com/data/width1024';

  /// Ayah-level recitation (real CDN by islamic.network).
  static const String quranAudioBase =
      'https://cdn.islamic.network/quran/audio';

  /// Backup ayah audio (per-reciter folders).
  static const String quranAudioBackupBase = 'https://everyayah.com/data';

  /// Prayer times (AlAdhan API).
  static const String aladhanApi = 'https://api.aladhan.com/v1';

  /// Quran text/translations/editions catalog.
  static const String alquranCloudApi = 'https://api.alquran.cloud/v1';

  /// Content origin (catalogs, offline packs). Configurable at build time
  /// via --dart-define. The staging folder in this repo is what gets
  /// published to this location.
  static const String contentBaseUrl = String.fromEnvironment(
    'RAFEEQ_CONTENT_BASE',
    defaultValue:
        'https://raw.githubusercontent.com/tito423/rafeeq-api/main',
  );

  static String mushafImageUrl(int page) =>
      '$mushafImageBase/page${page.toString().padLeft(3, '0')}.png';

  /// [editionIdentifier] e.g. "ar.alafasy". Tries 128kbps then 64kbps.
  static List<String> ayahAudioUrls(String editionIdentifier, int globalAyah) =>
      [
        '$quranAudioBase/128/$editionIdentifier/$globalAyah.mp3',
        '$quranAudioBase/64/$editionIdentifier/$globalAyah.mp3',
      ];

  /// Full-surah recitation server (mp3quran catalog provides base paths).
  static String surahAudioUrl(String serverBase, String folder, int surah) {
    final s = surah.toString().padLeft(3, '0');
    return 'https://$serverBase/$folder/$s.mp3';
  }
}
