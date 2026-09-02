/// Central, secret-free configuration for remote content.
///
/// Every URL here is a real, public endpoint. No credentials live in the
/// client (the old build embedded Cloudflare R2 keys — removed for good).
abstract final class AppConfig {
  /// Mushaf pages as vector SVG, each carrying the `ayahPolygon` hit layer
  /// that `assets/data/mushaf/*_polygons.json` was derived from.
  ///
  /// Source: quranpedia/quran-svg (polygon metadata CC0-1.0; KFQC glyphs free
  /// for digital use), pinned to a commit so page geometry can never drift
  /// away from the bundled polygon assets.
  ///
  /// TODO(release): this default points at GitHub raw, which is fine for
  /// development but is not a CDN and will rate-limit under real traffic.
  /// Mirror `scripts/mushaf_build/<edition>/svg` to our own bucket and ship
  /// production builds with:
  ///   `--dart-define=RAFEEQ_MUSHAF_BASE=https://<bucket>/mushafs`
  static const String mushafPin = 'b91d39e1065b57bdda3e94aca8ecf3575e50e1e6';

  /// Edition used until the reader picks another one.
  static const String defaultMushafEdition = 'hafs_kfqc';

  static const String mushafBase = String.fromEnvironment(
    'RAFEEQ_MUSHAF_BASE',
    defaultValue: 'https://raw.githubusercontent.com/quranpedia/quran-svg/'
        'b91d39e1065b57bdda3e94aca8ecf3575e50e1e6/mushafs',
  );

  /// [sourcePath] is the edition's upstream folder, e.g. 'hafs/kfqc'.
  static String mushafPageUrl(String sourcePath, int page) =>
      '$mushafBase/$sourcePath/svg/${page.toString().padLeft(3, '0')}.svg';

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
  ///
  /// The repo's default branch is `master`, not `main` — this constant
  /// pointed at `/main` for a while (a 404) because nothing actually used it
  /// yet; fixed when `hadithDbUrl` below became the first real user of it.
  static const String contentBaseUrl = String.fromEnvironment(
    'RAFEEQ_CONTENT_BASE',
    defaultValue:
        'https://raw.githubusercontent.com/tito423/rafeeq-api/master',
  );

  /// The offline hadith database (9 collections, ~41k hadiths, built by
  /// `scripts/build_hadith_db.py` from real A7med3bdulBaset/hadith-json
  /// dumps) — downloaded on demand rather than bundled, the same way mushaf
  /// pages and recitations are, given its size (~74 MB uncompressed).
  ///
  /// The hosted file is `hadith.zip` (~17 MB, `DownloadManager.unzipToDatabases`
  /// unpacks it to `hadith.db` on-device) — not `hadith.db` itself, which
  /// this constant pointed at for a while (a 404: only the zip was ever
  /// pushed to the repo) until a real download attempt caught it.
  static const String hadithDbUrl = '$contentBaseUrl/hadith/hadith.zip';

  /// Bump this whenever `hadith.db`'s schema or content changes so devices
  /// that already downloaded the old one re-fetch instead of opening a
  /// stale/incompatible file.
  static const String hadithDbVersion = 'v1';


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
