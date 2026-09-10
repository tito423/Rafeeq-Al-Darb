import '../../../core/config/app_config.dart';

/// A licence-clean background clip for the **video-mode** Adhan (P2‑7).
///
/// All five are from Pixabay under the **Pixabay Content License** (free for
/// commercial use, no attribution required — https://pixabay.com/service/license/).
/// The app downloads the chosen clip on demand (it is **not** bundled — a few
/// MB each) and plays it **muted + looped** behind the karaoke Adhan text;
/// the sound is always the user's chosen adhan recording, composited at
/// playback time, never muxed.
class AdhanVideoOption {
  final String id;
  final int approxSizeBytes;

  /// The clip's real pixel size, read off the hosted file with ffmpeg by
  /// `scripts/probe_adhan_videos.py`. Shown in the picker so a choice is an
  /// informed one, and asserted by `test/adhan_video_catalog_test.dart` —
  /// which is the only thing that stops a 360p clip being offered again.
  final int width;
  final int height;

  /// Measured duration in seconds. The clip is looped, so a short one loops
  /// more often; worth seeing before downloading 17 MB.
  final double seconds;

  const AdhanVideoOption({
    required this.id,
    required this.approxSizeBytes,
    required this.width,
    required this.height,
    required this.seconds,
  });

  /// True when the clip is taller than it is wide — which is the shape of the
  /// screen it will be drawn on, so it is scaled least and cropped least.
  bool get isPortrait => height > width;

  /// «1080×1920» as a left-to-right run, so it does not reverse inside an
  /// Arabic line (trap #16).
  String get sizeLabel => '$width×$height';

  /// What the clip shows — «الحرم المكي», "The Grand Mosque, Makkah". This is a
  /// description, not a place's name, so it is translated outright; it was an
  /// Arabic and an English field, and every other language got the English.
  String get labelKey => 'adhan_video.$id';

  /// `adhan/video/<id>.mp4` on the content host (override-able via
  /// `--dart-define=RAFEEQ_CONTENT_BASE=…`).
  String get url => '${AppConfig.contentBaseUrl}/adhan/video/$id.mp4';

  String get fileName => 'adhan_video_$id.mp4';

  /// [DownloadManager] id (distinct namespace from books / hadith).
  String get downloadId => 'adhan_video_$id';
}

/// Provenance line shown wherever a clip is offered, in the reader's own
/// language — `adhan_video.source`.
const adhanVideoSourceLabelKey = 'adhan_video.source';

/// Sizes are the real byte counts of the hosted `_tiny` mp4s (measured
/// 2026-09-02 with `curl`).
/// Ordered HD-first, and the first entry is the default
/// (`adhan_presentation_provider.dart` falls back to `adhanVideoCatalog.first`).
///
/// THE OWNER'S COMPLAINT, MEASURED — AND WHAT MEASURING IT FOUND.
/// «الفيديو بتاع الأذان لما بيشتغل بتبقى جودته سيئة جدًا».
/// `scripts/probe_adhan_videos.py` read every hosted clip with ffmpeg: three
/// of the ten were standard definition, and the 640×360 one was
/// `adhanVideoCatalog.first`, i.e. the default. On a 1080×2400 phone,
/// `azan_player_screen._background()` draws the clip with `BoxFit.cover`, so
/// that clip was being scaled **6.7×**. The background he saw out of the box
/// was the worst file in the set.
///
/// Then `scripts/contact_sheet_adhan_videos.py` pulled four frames from
/// across each clip and they were looked at (§1.3, §1.4) — and the resolution
/// turned out to be the smaller problem. **Six of the ten were not what the
/// app said they were**, and `adhan_video_content.json` records each one:
///
///     mosque_view     «رحاب مسجد»                  the flag of Pakistan
///     kaaba_close     «الكعبة المشرّفة عن قرب»      gold «محمد» calligraphy
///     kaaba_tawaf     «الحرم والكعبة»              the same calligraphy
///     kaaba           «الكعبة المشرفة»             a cartoon 3-D animation
///     haram_makkah2   «ساحات الحرم المكي»          the same cartoon
///     madina_haram    «رحاب المسجد النبوي»         an Ottoman mosque above a
///                                                  Turkish city
///
/// The only three that matched their labels were the three SD ones. This is
/// §1.1's failure mode exactly — a catalogue written from uploads nobody
/// opened — and it is the same shape as the eight mushaf editions whose pages
/// were never there.
///
/// WHAT WAS DONE. Five clips are gone: the two cartoon ones, the flag, and
/// the two that duplicated another clip's content at lower quality. The five
/// that remain are labelled for **what they actually show**, verified frame by
/// frame. The two genuine Haram clips are 640×360 and are offered last rather
/// than dropped — a real picture of the Masjid al-Haram at 360p is still the
/// Masjid al-Haram, and dropping it would leave an adhan screen with no Makkah
/// and no Madinah in it at all. Their resolution is on the row, so the choice
/// is an informed one.
///
/// STILL MISSING, AND SAID SO. No HD footage of the two Harams was sourced
/// this session: Pixabay and Pexels both answer 403 without an API key,
/// Mixkit's licence text is loaded by JavaScript and could not be read (trap
/// #18 — an unreadable licence is a no), and archive.org's CC-licensed video
/// for this subject is hour-long broadcast footage, not background loops.
///
/// Every number below is measured — `adhan_video_probe.json`.
const List<AdhanVideoOption> adhanVideoCatalog = [
  AdhanVideoOption(
    id: 'madina_haram',
    approxSizeBytes: 12626797,
    width: 1080,
    height: 1920,
    seconds: 18.75,
  ),
  AdhanVideoOption(
    id: 'mosque_minaret',
    approxSizeBytes: 16592826,
    width: 2560,
    height: 1440,
    seconds: 9.4,
  ),
  AdhanVideoOption(
    id: 'kaaba_close',
    approxSizeBytes: 2491506,
    width: 1920,
    height: 1080,
    seconds: 17.27,
  ),
  AdhanVideoOption(
    id: 'haram_makkah',
    approxSizeBytes: 2307544,
    width: 640,
    height: 360,
    seconds: 20.78,
  ),
  AdhanVideoOption(
    id: 'madina_nabawi',
    approxSizeBytes: 5515868,
    width: 640,
    height: 360,
    seconds: 49.32,
  ),
];

AdhanVideoOption? adhanVideoById(String? id) {
  if (id == null) return null;
  for (final v in adhanVideoCatalog) {
    if (v.id == id) return v;
  }
  return null;
}
