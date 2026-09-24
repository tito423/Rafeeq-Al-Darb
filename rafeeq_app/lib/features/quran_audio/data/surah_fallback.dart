import '../../../core/config/app_config.dart';
import 'quran_audio_library.dart';
import 'quran_audio_player.dart';

/// What the surah player plays when a surah cannot be had from its own
/// recitation — «دايما حط خطة احتياطية بحيث التطبيق ميعطلش ويقف لأي سبب».
///
/// The per-ayah player already falls through R2 → everyayah → islamic.network.
/// The surah player had R2 (two recitations) → mp3quran and then nothing: a
/// surah mp3quran lists and does not hold — عبدالله البريمي's An-Nas, 404,
/// the one missing file in 801 probes on 2026-09-24 — stopped it dead.
///
/// The backup is the SAME SURAH in ANOTHER VOICE, and the reader is told
/// whose. Rebuilding it ayah by ayah in the chosen shaykh's own voice would
/// mean pairing mp3quran's reciters with everyayah's folders by name, and a
/// wrong pairing puts one shaykh's voice under another's name — the thing
/// this app refuses to do (RecitationSource's note on the same risk).
///
/// In order:
///  1. the surah already downloaded on this phone, in any recitation — so a
///     reader with no network still hears it;
///  2. عبد الباسط عبد الصمد, murattal (mp3quran moshaf 53), from the app's own
///     bucket, where all 114 surahs were counted;
///  3. the same recitation from mp3quran, behind it as `fallbackUrl`.
class SurahFallback {
  SurahFallback._();

  static const _basitMoshaf = 53;
  static const _basitName = 'عبد الباسط عبد الصمد';
  static const _basitOrigin = 'https://server7.mp3quran.net/basit/';

  static final _id = RegExp(r'^m(\d+)-s(\d+)$');

  /// A replacement for [t], or null when [t] is not a surah of a recitation
  /// (an imported device file) or it already IS the last backup.
  /// [localOnly]: no connection — only a copy on the phone is worth offering.
  static PlayerTrack? forTrack(PlayerTrack t, {bool localOnly = false}) {
    final m = _id.firstMatch(t.id);
    if (m == null) return null;
    final moshaf = int.parse(m.group(1)!);
    final surah = int.parse(m.group(2)!);
    final lib = QuranAudioLibrary.instance;
    for (final e in lib.entries) {
      if (e.moshafId == moshaf || !lib.isDownloaded(e.moshafId, surah)) continue;
      return _as(t, surah, e.reciterName,
          filePath: lib.fileFor(e.moshafId, surah).path);
    }
    if (localOnly || moshaf == _basitMoshaf) return null;
    final s = surah.toString().padLeft(3, '0');
    return _as(t, surah, _basitName,
        url: AppConfig.r2SurahUrl('basit_murattal', surah),
        fallbackUrl: '$_basitOrigin$s.mp3');
  }

  /// Keeps [t]'s id, so the list still marks the surah the reader tapped;
  /// the voice actually heard is in the artist line, where the lock screen
  /// and the mini player show it.
  static PlayerTrack _as(PlayerTrack t, int surah, String voice,
          {String? filePath, String? url, String? fallbackUrl}) =>
      PlayerTrack(
        id: t.id,
        title: t.title,
        artist: voice,
        album: t.album,
        url: url,
        filePath: filePath,
        fallbackUrl: fallbackUrl,
      );
}
