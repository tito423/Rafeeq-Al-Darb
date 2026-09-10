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

  /// P3‑53: raster (image-scan) mushaf pages, hosted first-party on the R2
  /// content bucket under `mushaf/<imagePath>/NNN.<ext>` (e.g. the coloured
  /// Tajweed mushaf at `mushaf/tajweed/002.jpg`). Uses [contentBaseUrl] so it
  /// is overridable at build time the same way every other content URL is.
  ///
  /// [ext] defaults to `jpg` (what Tajweed's real scans are). The Warsh and
  /// Qalun editions are palette PNGs — the right encoding for black-on-white
  /// script, and re-encoding them as JPEG made every page ~4x larger with
  /// ringing artifacts on the letterforms — so they declare
  /// `"image_ext": "png"` in `editions.json` and land here as `png`.
  static String mushafImageUrl(String imagePath, int page,
          {String ext = 'jpg'}) =>
      '$contentBaseUrl/mushaf/$imagePath/${page.toString().padLeft(3, '0')}.$ext';

  /// One downloadable Quran translation, gzipped JSON keyed "surah:ayah".
  /// Rehosted first-party from api.alquran.cloud — see
  /// `scripts/r2_upload_quran_translations.py`. The six translations bundled
  /// in `quran_sciences.db` never come from here; this is only for the other
  /// languages, fetched on demand when a reader picks one.
  static String quranTranslationUrl(String lang) =>
      '$contentBaseUrl/quran/translations/$lang.json.gz';

  /// Ayah-level recitation (real CDN by islamic.network).
  static const String quranAudioBase =
      'https://cdn.islamic.network/quran/audio';

  /// everyayah.com — the **primary** per-ayah recitation host (see
  /// `RecitationSource` for which reciters are mirrored there and why it is
  /// preferred over the CDN below). Files are addressed by surah+ayah, and
  /// every folder answers HTTP Range requests, which is what makes an
  /// interrupted download resume rather than restart.
  static const String quranAudioBackupBase = 'https://everyayah.com/data';

  /// Prayer times (AlAdhan API).
  static const String aladhanApi = 'https://api.aladhan.com/v1';

  /// Quran text/translations/editions catalog.
  static const String alquranCloudApi = 'https://api.alquran.cloud/v1';

  /// Content origin (catalogs, offline packs). Configurable at build time
  /// via --dart-define.
  ///
  /// Migrated 2026‑09‑03 (P2‑9 follow-up, HOSTING.md) from GitHub raw to a
  /// dedicated Cloudflare R2 bucket (`rafeeq-content`, public r2.dev domain,
  /// free egress — GitHub raw was never meant to serve real download
  /// traffic, see HOSTING.md §2/§5.5). R2 holds only the three folders the
  /// app actually reads (`hadith/hadith.zip`, `books/text/*.json`,
  /// `adhan/video/*.mp4`) — the rest of `tito423/rafeeq-api` (raw per-book
  /// hadith JSON, the abandoned PNG mushaf set, spare adhan mp3s) is build
  /// pipeline / historical cruft, never referenced by this constant, and was
  /// deliberately not mirrored. No credentials of any kind live in the
  /// client — R2 access keys stay in `scripts/.env` (gitignored) and are
  /// only ever used by the one-off migration/upload scripts run from a dev
  /// machine, never shipped in a build.
  static const String contentBaseUrl = String.fromEnvironment(
    'RAFEEQ_CONTENT_BASE',
    defaultValue: 'https://pub-39dbef68a1a845d5ba669b43a59516b9.r2.dev',
  );

  /// The offline hadith database (9 collections, ~41k hadiths, built by
  /// `scripts/build_hadith_db.py` from real A7med3bdulBaset/hadith-json
  /// dumps, plus real per-hadith grading for 4 of the 9 books as of P2‑13 —
  /// see that script's doc) — downloaded on demand rather than bundled, the
  /// same way mushaf pages and recitations are, given its size (~74 MB
  /// uncompressed).
  ///
  /// The hosted file is `hadith.zip` (~16 MB, `DownloadManager.unzipToDatabases`
  /// unpacks it to `hadith.db` on-device) — not `hadith.db` itself, which
  /// this constant pointed at for a while (a 404: only the zip was ever
  /// pushed to the repo) until a real download attempt caught it.
  static const String hadithDbUrl = '$contentBaseUrl/hadith/hadith.zip';

  /// Bump this whenever `hadith.db`'s schema or content changes so devices
  /// that already downloaded the old one re-fetch instead of opening a
  /// stale/incompatible file. Actually enforced (P2‑13): `DownloadTask
  /// .dbVersion` stamps this value next to the extracted file, and
  /// `DbHelper.openDownloaded(expectedVersion: ...)` deletes + treats as
  /// "not downloaded" anything whose stamp doesn't match — before P2‑13 this
  /// constant existed but nothing ever read it, so bumping it did nothing.
  ///
  /// v1 -> v2 (2026‑09‑03, P2‑13): added real `grade`/`grader` columns.
  /// v2 -> v3 (2026‑09‑09): Musnad Ahmad rebuilt from `مسند أحمد - ط الرسالة`
  /// (تحقيق شعيب الأرناؤوط) — 1,374 hadiths in 8 chapters became 27,584 in
  /// 1,061 musnads, 24,530 of them carrying his own ruling — and Sunan
  /// al-Darimi gained 2,642 rulings from حسين سليم أسد الداراني's edition.
  /// 40,943 hadiths -> 67,153; graded 44% -> 67%.
  static const String hadithDbVersion = 'v3';

  /// موسوعة الأحاديث النبوية (hadeethenc.com) — a **separate** collection from
  /// the nine books above, one downloadable pack per language.
  ///
  /// WHY IT EXISTS. The nine collections in `hadith.db` are 67,153 hadiths in
  /// Arabic and nothing translates that corpus into Spanish, French,
  /// Portuguese, Russian or Urdu with a grading anyone would stand behind. An
  /// earlier session told the owner no such source existed; that was wrong.
  /// HadeethEnc publishes a smaller curated corpus where **every** record
  /// carries both a takhrij (تخريج) and a grading (درجة) in the reader's own
  /// language — measured across all 15,498 (hadith, language) rows by
  /// `scripts/build_hadeethenc_packs.py`: 0 ungraded, 0 without takhrij.
  ///
  /// WHY IT IS ALLOWED TO BE REHOSTED. The publisher's own «الشروط
  /// والسياسات» (hadeethenc.com/ar/home, read 2026‑09‑10) permits downloading
  /// and republishing the translations on conditions: no modification,
  /// addition or deletion; clear credit to the publisher and the source;
  /// the version number; and no ads unbefitting the content. This app
  /// modifies nothing, credits the source on the collection screen, on every
  /// hadith and on the Sources screen, and carries no advertising at all.
  /// CLAUDE.md trap #18 — a free file is not automatically free to rehost —
  /// is why those terms were read before a byte was uploaded.
  ///
  /// One pack per language, 1.3–3.5 MB zipped, unpacked to
  /// `hadeethenc_<lang>.db` by the same `unzipToDatabases` path `hadith.zip`
  /// uses. `assets/data/catalogs/hadeethenc.json` lists what is on offer, and
  /// every size in it is the byte count the bucket actually answered with.
  static String hadeethEncUrl(String lang) =>
      '$contentBaseUrl/hadeethenc/$lang.zip';

  /// Same contract as [hadithDbVersion]: stamped beside the extracted file so
  /// a device holding an older pack re-fetches instead of opening it.
  ///
  /// v1 (2026‑09‑10): first packs — 3,574 hadiths across seven languages,
  /// crawled 2026‑09‑09, category titles refetched per language 2026‑09‑10.
  /// v1 -> v2 (2026‑09‑10): معاني الكلمات. The first crawl never stored the
  /// per-hadith glossary, and a second one asking for `words_meanings_ar`
  /// found nothing because on the **Arabic** record that field is
  /// `words_meanings`, unsuffixed. 2,538 of the 3,574 carry one; a pack now
  /// ships it and the detail screen shows it under the hadith.
  static const String hadeethEncVersion = 'v2';


  /// One ayah on everyayah.com: `<folder>/SSSAAA.mp3`, both parts zero-padded
  /// to three digits (so 2:286 is `002286.mp3`). [folder] comes from
  /// `RecitationSource`, whose folder names were each verified live.
  static String everyAyahUrl(String folder, int surah, int ayah) =>
      '$quranAudioBackupBase/$folder/'
      '${surah.toString().padLeft(3, '0')}'
      '${ayah.toString().padLeft(3, '0')}.mp3';

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
