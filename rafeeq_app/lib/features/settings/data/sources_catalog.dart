/// Every content source the app uses, credited, with a link.
///
/// §1.2 of CLAUDE.md: "Every content source gets credited on the Sources
/// screen with a link." That makes this list an obligation, not decoration -
/// which is exactly why it should not have been living inside the widget that
/// happens to draw it, where nothing else could read or check it.
library;

import '../../ruqyah/data/ruqyah_catalog.dart';

class SourceEntry {
  final String host;
  final String url;

  /// What this source actually provides — an i18n key.
  final String roleKey;

  const SourceEntry(this.host, this.url, this.roleKey);
}


/// (section title key, sources) — grouped by what part of the app they feed.
// Not `const`: the ruqyah group is built from `ruqyahRecordings`, so the
// credits list can never fall out of step with what the app actually ships.
final sourceGroups = <(String, List<SourceEntry>)>[
  (
    'about.src_quran',
    [
      SourceEntry('quran.com', 'https://quran.com', 'about.src_qurancom'),
      SourceEntry('api.alquran.cloud', 'https://alquran.cloud',
          'about.src_alquran'),
      SourceEntry('quranpedia/quran-svg',
          'https://github.com/quranpedia/quran-svg', 'about.src_svg'),
      SourceEntry('archive.org', 'https://archive.org', 'about.src_archive'),
    ]
  ),
  // Each scanned printing, named with the item it came from and the rights
  // position that item actually states — not "archive.org" as a single line
  // covering five different books with five different licences.
  //
  // The licences are the ones recorded when each printing was built
  // (`scripts/build_mushaf_from_pdf.py`, `r2_upload_mushaf_printings.py`),
  // each read off the item or the volume's own back matter. Trap #18 is why
  // they are read rather than assumed: a free scan is not automatically free
  // to rehost, and one candidate printing was dropped for exactly that.
  //
  // Only the five printings that actually ship appear here. `editions.json`
  // is the list; a printing built in `scripts/` but not shipped (the Nastaliq
  // setting) is not credited, because the app does not carry it.
  (
    'about.src_mushaf_printings',
    [
      SourceEntry('مصحف التجويد الملوّن',
          'https://github.com/Imomzoda8/tajweed-quran-images',
          'about.src_ed_tajweed'),
      SourceEntry('المصحف المذهّب (Smart Mushaf)',
          'https://archive.org/details/smartmushaf', 'about.src_ed_gold'),
      SourceEntry('مصحف قطر', 'https://archive.org/details/QuranMushafQatar',
          'about.src_ed_qatar'),
      SourceEntry(
          'مصحف دولة الكويت',
          'https://archive.org/details/'
              'HQ23AlQuranAlKareemMushafDolatUlKuwaitWww.Quranpdf.blogspot.in',
          'about.src_ed_kuwait'),
      SourceEntry('مصحف المدينة — الطبعة الليلية',
          'https://archive.org/details/QuranMadina35685363568hNight',
          'about.src_ed_madinah_night'),
    ]
  ),
  (
    'about.src_audio',
    [
      SourceEntry('everyayah.com', 'https://everyayah.com', 'about.src_everyayah'),
      SourceEntry('cdn.islamic.network', 'https://islamic.network',
          'about.src_islamicnetwork'),
      SourceEntry('mp3quran.net', 'https://mp3quran.net', 'about.src_mp3quran'),
    ]
  ),
  (
    'about.src_hadith',
    [
      SourceEntry('sunnah.com', 'https://sunnah.com', 'about.src_sunnah'),
      SourceEntry('المكتبة الشاملة', 'https://shamela.ws', 'about.src_shamela'),
      // Named separately from Shamela itself: these are the two edited
      // editions the app's hadith gradings actually come from, and a grading
      // is only worth anything if the reader can see whose it is.
      SourceEntry('مسند أحمد — ط الرسالة', 'https://shamela.ws/book/25794',
          'about.src_musnad_arnaut'),
      SourceEntry('سنن الدارمي — ت حسين أسد', 'https://shamela.ws/book/21795',
          'about.src_darimi_asad'),
      // موسوعة الأحاديث النبوية — the separate multilingual collection. Its
      // own republication terms require clear credit to the publisher and
      // the source; this row is part of meeting them, alongside the credit
      // on the collection screen and on every hadith it shows.
      SourceEntry('hadeethenc.com', 'https://hadeethenc.com',
          'about.src_hadeethenc'),
    ]
  ),
  (
    'about.src_quotes',
    [
      // The books the sayings are taken from are already credited by their
      // own catalogue entries; this row is the picture behind them. Only
      // public-domain and CC0 files were taken, and each file's licence,
      // author and Commons page is in `assets/data/quote_backgrounds.json`.
      SourceEntry('Wikimedia Commons', 'https://commons.wikimedia.org',
          'about.src_commons'),
    ]
  ),
  (
    'about.src_prayer',
    [
      SourceEntry('api.aladhan.com', 'https://aladhan.com', 'about.src_aladhan'),
    ]
  ),
  // The channel list is a list of links, and a link needs no permission. The
  // avatars are a different matter: they are mirrored onto this project's own
  // bucket so the grid is not a page of grey squares offline, and a mirrored
  // image is a copy of someone else's file. Credited here for that reason.
  (
    'channels.title',
    [
      SourceEntry('YouTube', 'https://www.youtube.com', 'about.src_youtube'),
    ]
  ),
  (
    'ruqyah.title',
    [
      // Each recording is credited to the archive.org item it came from, by
      // name, so provenance is visible in the app and not only in a script.
      // Only the ones that have a public page. The owner's own file has no
      // URL to credit, so it is not listed with a fabricated one.
      for (final r in ruqyahRecordings)
        if (r.sourceUrl.isNotEmpty)
          SourceEntry(r.reciterAr, r.sourceUrl, 'about.src_ruqyah'),
    ]
  ),
];
