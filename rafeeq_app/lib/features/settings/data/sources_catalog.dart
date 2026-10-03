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
      // The ayah text and the font it is drawn in, since 2026-09-25
      // (scripts/build_quran_text_kfgqpc.py; licence in
      // assets/fonts/KFGQPC-HAFS-LICENSE.txt).
      const SourceEntry('مجمع الملك فهد لطباعة المصحف الشريف',
          'https://qurancomplex.gov.sa', 'about.src_kfgqpc'),
      // The i'rab tab since 2026-09-26: Shamela 23584, its 27 damaged sections
      // transcribed from the printed edition and the rest checked against it
      // (scripts/build_irab_daas_final.py; CONTENT-LICENSES.md).
      const SourceEntry('المكتبة الشاملة — إعراب القرآن الكريم (الدعاس)',
          'https://shamela.ws/book/23584', 'about.src_irab_daas'),
      // Where al-Da'as's own commentary is wrong in all four copies, the
      // fix is taken from these named books (scripts/irab_daas_quran_
      // corrections.json), read on tafsir.app on 2026-09-26.
      const SourceEntry('tafsir.app — الجدول، إعراب درويش، الإعراب الميسر',
          'https://tafsir.app', 'about.src_irab_check'),
      const SourceEntry('quran.com', 'https://quran.com', 'about.src_qurancom'),
      const SourceEntry('api.alquran.cloud', 'https://alquran.cloud',
          'about.src_alquran'),
      const SourceEntry('quran/quran_android (mushaf images + ayahinfo)',
          'https://github.com/quran/quran_android', 'about.src_svg'),
      const SourceEntry('archive.org', 'https://archive.org', 'about.src_archive'),
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
  // The four SCANNED printings were removed on 2026-09-20: none carried ayah
  // coordinates of its own, so their highlight was fitted rather than known.
  // The one printing that ships is the vector Madinah edition, credited above
  // with its source, `quranpedia/quran-svg`, which publishes the pages and the
  // ayah polygons together.
  (
    'about.src_audio',
    [
      const SourceEntry('everyayah.com', 'https://everyayah.com', 'about.src_everyayah'),
      const SourceEntry('cdn.islamic.network', 'https://islamic.network',
          'about.src_islamicnetwork'),
      const SourceEntry('mp3quran.net', 'https://mp3quran.net', 'about.src_mp3quran'),
      // The book reader's downloadable voice: the speaker and the corpus
      // (CC BY 4.0) and the phonetiser rules (CC BY-NC 4.0) are Halabi's, the
      // trained models nipponjo's. See CONTENT-LICENSES.md.
      const SourceEntry('Arabic Speech Corpus', 'http://en.arabicspeechcorpus.com/',
          'about.src_asc'),
      const SourceEntry('nipponjo/tts_arabic', 'https://github.com/nipponjo/tts_arabic',
          'about.src_tts_arabic'),
      // «رفيق»'s downloadable voice pack (scripts/publish_rafeeq_voice_pack.py):
      // Meta's recogniser (Apache-2.0), silero VAD (MIT), run by sherpa-onnx
      // (Apache-2.0).
      const SourceEntry('Omnilingual ASR — Meta',
          'https://github.com/facebookresearch/omnilingual-asr',
          'about.src_omnilingual'),
      // «دقة أعلى في العربية» (2026-09-30), CC BY 4.0 - attribution required.
      const SourceEntry('NVIDIA FastConformer Arabic (CC BY 4.0)',
          'https://huggingface.co/nvidia/stt_ar_fastconformer_hybrid_large_pcd_v1.0',
          'about.src_fastconformer_ar'),
      const SourceEntry('Silero VAD', 'https://github.com/snakers4/silero-vad',
          'about.src_silero'),
      const SourceEntry('sherpa-onnx', 'https://github.com/k2-fsa/sherpa-onnx',
          'about.src_sherpa'),
    ]
  ),
  (
    'about.src_hadith',
    [
      const SourceEntry('sunnah.com', 'https://sunnah.com', 'about.src_sunnah'),
      const SourceEntry('المكتبة الشاملة', 'https://shamela.ws', 'about.src_shamela'),
      // The Azhari aqidah shuruh Shamela does not carry (al-Bajuri, Nawawi
      // al-Jawi, al-Qari), 2026-10-03: scripts/build_ketabonline_book.py.
      const SourceEntry('جامع الكتب الإسلامية', 'https://ketabonline.com',
          'about.src_ketabonline'),
      // The adhkar (owner, 2026-09-29): the whole of Hisn al-Muslim, from the
      // MIT-licensed transcription in scripts/azkar_hisn/.
      const SourceEntry('حصن المسلم — asellam/HisnElMuslim',
          'https://github.com/asellam/HisnElMuslim', 'about.src_hisn'),
      // The adhkar recordings (2026-09-29): the book's own site, one mp3 per
      // dhikr, streamed from it and paired word for word
      // (scripts/hisnmuslim_audio_map.py). The site names no reciter.
      const SourceEntry('حصن المسلم — hisnmuslim.com',
          'https://www.hisnmuslim.com', 'about.src_hisn_audio'),
      // The morning / evening adhkar to listen to (2026-10-03, replacing the
      // 2026-09-30 IslamHouse / Internet Archive recordings): Hisn al-Muslim's
      // text voiced in the app - adhkar_recitations.dart.
      const SourceEntry('everyayah.com — مشاري العفاسي',
          'https://everyayah.com/data/Alafasy_128kbps/', 'about.src_adhkar_ayat'),
      const SourceEntry('Google Gemini TTS',
          'https://ai.google.dev/gemini-api/docs/speech-generation',
          'about.src_adhkar_tts'),
      // Named separately from Shamela itself: these are the two edited
      // editions the app's hadith gradings actually come from, and a grading
      // is only worth anything if the reader can see whose it is.
      const SourceEntry('مسند أحمد — ط الرسالة', 'https://shamela.ws/book/25794',
          'about.src_musnad_arnaut'),
      const SourceEntry('سنن الدارمي — ت حسين أسد', 'https://shamela.ws/book/21795',
          'about.src_darimi_asad'),
      // موسوعة الأحاديث النبوية — the separate multilingual collection. Its
      // own republication terms require clear credit to the publisher and
      // the source; this row is part of meeting them, alongside the credit
      // on the collection screen and on every hadith it shows.
      const SourceEntry('hadeethenc.com', 'https://hadeethenc.com',
          'about.src_hadeethenc'),
    ]
  ),
  // «مناسك الحج والعمرة»: every word of the guide is read from this book, so
  // it is credited by name and edition, not folded into the Shamela row.
  (
    'hajj.title',
    [
      // This row was STALE. The guide moved off «التحقيق والإيضاح» لابن باز
      // onto النووي's «الإيضاح» when the rights question was settled, and
      // `hajj.source` was rewritten in all seven locales at the time — but
      // the Sources screen kept crediting the old book, so the app named a
      // source it no longer reads a word from. Corrected on 2026-09-17, in
      // the same pass that took the remaining Ibn Baz mentions out.
      // Since 2026-09-23 the guide reads الفقه المنهجي, not al-Nawawi's
      // «الإيضاح» (which is now a library book like any other) -
      // scripts/build_hajj_guide_book.py.
      const SourceEntry(
          'الفقه المنهجي على مذهب الإمام الشافعي — الخن، البغا، الشربجي',
          'https://shamela.ws/book/6369',
          'hajj.source'),
      // «في المذاهب الأربعة» under each step (2026-09-22), verbatim from
      // al-Jaziri's كتاب الحج — scripts/build_hajj_madhahib.py.
      const SourceEntry(
          'الفقه على المذاهب الأربعة — عبد الرحمن الجزيري',
          'https://shamela.ws/book/9849',
          'hajj.madhahib_title'),
      // «المواقيت اليوم» under the miqat steps (2026-09-23): the ministry's
      // own sentence per miqat, verbatim - assets/data/mawaqit_today.json.
      const SourceEntry(
          'وزارة الحج والعمرة — المواقيت',
          'https://haj.gov.sa/ar/Umrah/Miqaats',
          'hajj.mawaqit_today_title'),
    ]
  ),
  (
    'about.src_quotes',
    [
      // The books the sayings are taken from are already credited by their
      // own catalogue entries; this row is the picture behind them. Only
      // public-domain and CC0 files were taken, and each file's licence,
      // author and Commons page is in `assets/data/quote_backgrounds.json`.
      const SourceEntry('Wikimedia Commons', 'https://commons.wikimedia.org',
          'about.src_commons'),
      // The one photograph behind every adhkar card (2026-10-03).
      const SourceEntry('Wikimedia Commons — Zahrazari, CC BY 4.0',
          'https://commons.wikimedia.org/wiki/File:Vakil_mosque_interior_in_2022.jpg',
          'about.src_azkar_bg'),
      // The Azkar grid and the New Muslim guide draw their card photographs
      // from Unsplash, hotlinked to `images.unsplash.com` — the reader's own
      // device fetches them and nothing is rehosted here, the same position
      // the recitations sit in. Credited because this screen says every
      // source is on it, and this one was not.
      const SourceEntry('Unsplash', 'https://unsplash.com/license',
          'about.src_unsplash'),
      // The history quiz: every question quotes one page of these
      // library books (assets/data/quiz/history_quiz.json and the hosted
      // copy on the bucket).
      const SourceEntry('الفصول في سيرة الرسول ﷺ — ابن كثير',
          'https://shamela.ws/book/9241', 'about.src_quiz'),
      const SourceEntry('تاريخ الخلفاء — السيوطي',
          'https://shamela.ws/book/11995', 'about.src_quiz'),
      const SourceEntry('السيرة النبوية — ابن هشام',
          'https://shamela.ws/book/7450', 'about.src_quiz'),
      const SourceEntry('السيرة النبوية — ابن كثير',
          'https://shamela.ws/book/930', 'about.src_quiz'),
      const SourceEntry('البداية والنهاية — ابن كثير',
          'https://shamela.ws/book/23708', 'about.src_quiz'),
    ]
  ),
  (
    'about.src_prayer',
    [
      const SourceEntry('api.aladhan.com', 'https://aladhan.com', 'about.src_aladhan'),
      // The world city list behind manual prayer location (CC BY 4.0 -
      // attribution is the licence's one condition).
      const SourceEntry('GeoNames (CC BY 4.0)', 'https://www.geonames.org',
          'about.src_geonames'),
    ]
  ),
  // The channel list is a list of links, and a link needs no permission. The
  // avatars are a different matter: they are mirrored onto this project's own
  // bucket so the grid is not a page of grey squares offline, and a mirrored
  // image is a copy of someone else's file. Credited here for that reason.
  (
    'channels.title',
    [
      const SourceEntry('YouTube', 'https://www.youtube.com', 'about.src_youtube'),
    ]
  ),
  // The kids-corner story videos (docs/kids_stories/, CONTENT-LICENSES.md).
  (
    'downloads.cat_kids_stories',
    [
      const SourceEntry('التفسير الميسر — مجمع الملك فهد',
          'https://qurancomplex.gov.sa', 'about.src_kids_muyassar'),
      const SourceEntry('everyayah.com — محمد صدّيق المنشاوي',
          'https://everyayah.com/data/Minshawy_Murattal_128kbps/', 'about.src_kids_minshawi'),
      const SourceEntry('Google Gemini TTS',
          'https://ai.google.dev/gemini-api/docs/speech-generation', 'about.src_kids_tts'),
      const SourceEntry('تفسير ابن كثير، تفسير الطبري، صحيح البخاري',
          'https://sunnah.com/bukhari', 'about.src_kids_more'),
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
