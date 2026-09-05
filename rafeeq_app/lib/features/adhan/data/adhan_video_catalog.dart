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
  final String nameAr;
  final String nameEn;
  final int approxSizeBytes;

  const AdhanVideoOption({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.approxSizeBytes,
  });

  /// `adhan/video/<id>.mp4` on the content host (override-able via
  /// `--dart-define=RAFEEQ_CONTENT_BASE=…`).
  String get url => '${AppConfig.contentBaseUrl}/adhan/video/$id.mp4';

  String get fileName => 'adhan_video_$id.mp4';

  /// [DownloadManager] id (distinct namespace from books / hadith).
  String get downloadId => 'adhan_video_$id';
}

/// Provenance line shown wherever a clip is offered.
const adhanVideoSourceLabel =
    'المصدر: Pixabay — رخصة Pixabay (استخدام حر، بلا نسب)';

/// Sizes are the real byte counts of the hosted `_tiny` mp4s (measured
/// 2026-09-02 with `curl`).
const List<AdhanVideoOption> adhanVideoCatalog = [
  AdhanVideoOption(
    id: 'haram_makkah',
    nameAr: 'الحرم المكي',
    nameEn: 'The Grand Mosque, Makkah',
    approxSizeBytes: 2307544,
  ),
  AdhanVideoOption(
    id: 'kaaba',
    nameAr: 'الكعبة المشرفة',
    nameEn: 'The Kaaba',
    approxSizeBytes: 3981671,
  ),
  AdhanVideoOption(
    id: 'madina_nabawi',
    nameAr: 'المسجد النبوي',
    nameEn: "The Prophet's Mosque, Madinah",
    approxSizeBytes: 5515868,
  ),
  // P3‑47: 'mosque_prayer' (داخل المسجد) removed at the owner's request.
  AdhanVideoOption(
    id: 'mosque_ottoman',
    nameAr: 'مسجد عثماني',
    nameEn: 'An Ottoman-style mosque',
    approxSizeBytes: 1717259,
  ),
  // P3‑48: six more curated copyright-free clips (Pixabay Content License —
  // free for commercial use, no attribution required) sourced + uploaded to
  // R2 (adhan/video/<id>.mp4, head_object-verified) to reach the owner's
  // requested set of 10 beautiful Islamic-scene backgrounds. Sizes are the
  // real uploaded byte counts.
  AdhanVideoOption(
    id: 'kaaba_tawaf',
    nameAr: 'الحرم والكعبة',
    nameEn: 'The Haram & the Kaaba',
    approxSizeBytes: 5396917,
  ),
  AdhanVideoOption(
    id: 'haram_makkah2',
    nameAr: 'ساحات الحرم المكي',
    nameEn: 'The Grand Mosque courtyards',
    approxSizeBytes: 17359517,
  ),
  AdhanVideoOption(
    id: 'kaaba_close',
    nameAr: 'الكعبة المشرّفة عن قرب',
    nameEn: 'The Kaaba, up close',
    approxSizeBytes: 2491506,
  ),
  AdhanVideoOption(
    id: 'madina_haram',
    nameAr: 'رحاب المسجد النبوي',
    nameEn: "The Prophet's Mosque grounds",
    approxSizeBytes: 12626797,
  ),
  AdhanVideoOption(
    id: 'mosque_minaret',
    nameAr: 'مئذنة مسجد',
    nameEn: 'A mosque minaret',
    approxSizeBytes: 16592826,
  ),
  AdhanVideoOption(
    id: 'mosque_view',
    nameAr: 'رحاب مسجد',
    nameEn: 'A mosque',
    approxSizeBytes: 5109120,
  ),
];

AdhanVideoOption? adhanVideoById(String? id) {
  if (id == null) return null;
  for (final v in adhanVideoCatalog) {
    if (v.id == id) return v;
  }
  return null;
}
