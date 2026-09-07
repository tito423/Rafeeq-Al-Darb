import '../config/app_config.dart';

/// Where one ayah's recitation audio actually comes from.
///
/// The app's reciter list is the alquran.cloud editions catalog (176 Arabic
/// entries in `assets/data/catalogs/audio_editions.json`), but only some of
/// those are genuinely served as per-ayah MP3s. This class maps the ones that
/// are onto **everyayah.com**, and falls back to islamic.network's CDN for the
/// rest, so a reciter is never silently silent.
///
/// everyayah is preferred as the primary source for three concrete reasons:
///
///  1. It addresses files by **surah + ayah** (`002286.mp3`), not by a global
///     ayah index, so a wrong global-numbering lookup cannot point at the
///     wrong verse.
///  2. Every folder below answers HTTP **Range** requests (`206`), which is
///     what makes a paused or interrupted download resume instead of
///     restarting — the behaviour a 286-file surah depends on.
///  3. It is a long-standing, plain static host with no per-request API
///     budget, which matters when a whole-reciter download asks for 6,236
///     files.
///
/// **Every folder name in [_everyAyahFolders] was verified live** (an HTTP
/// range request against a real ayah returned `206`) rather than copied from
/// memory — folder naming there is inconsistent (`MaherAlMuaiqly128kbps` has
/// no underscores while `Husary_128kbps` does), and a wrong guess is a
/// silent 404 for that reciter.
class RecitationSource {
  RecitationSource._();

  /// alquran.cloud edition identifier -> everyayah.com folder.
  ///
  /// Only mappings where the two catalogs unambiguously describe the same
  /// recitation are listed. A reciter that is missing here still works — it
  /// just streams from islamic.network only.
  static const Map<String, String> _everyAyahFolders = {
    'ar.abdulbasitmurattal': 'Abdul_Basit_Murattal_192kbps',
    'ar.abdullahbasfar': 'Abdullah_Basfar_192kbps',
    'ar.abdurrahmaansudais': 'Abdurrahmaan_As-Sudais_192kbps',
    'ar.shaatree': 'Abu_Bakr_Ash-Shaatree_128kbps',
    'ar.ahmedajamy': 'Ahmed_ibn_Ali_al_Ajamy_128kbps',
    'ar.alafasy': 'Alafasy_128kbps',
    'ar.faresabbad': 'Fares_Abbad_64kbps',
    'ar.hanirifai': 'Hani_Rifai_192kbps',
    'ar.hudhaify': 'Hudhaify_128kbps',
    'ar.husary': 'Husary_128kbps',
    'ar.husarymujawwad': 'Husary_Mujawwad_64kbps',
    'ar.mahermuaiqly': 'MaherAlMuaiqly128kbps',
    'ar.minshawi': 'Minshawy_Murattal_128kbps',
    'ar.minshawimujawwad': 'Minshawy_Mujawwad_192kbps',
    'ar.mohamedtablawi': 'Mohammad_al_Tablaway_128kbps',
    'ar.muhammadayyoub': 'Muhammad_Ayyoub_128kbps',
    'ar.muhammadjibreel': 'Muhammad_Jibreel_128kbps',
    'ar.nasseralqatami': 'Nasser_Alqatami_128kbps',
    'ar.saoodshuraym': 'Saood_ash-Shuraym_128kbps',
  };

  /// Whether [edition] has a verified everyayah mirror (the fast, resumable
  /// path). False means it streams from the CDN only — still playable, but
  /// not the preferred source for a big offline download.
  static bool hasVerifiedMirror(String edition) =>
      _everyAyahFolders.containsKey(edition);

  static String? folderFor(String edition) => _everyAyahFolders[edition];

  /// Candidate URLs for one ayah, best first. Callers try them in order and
  /// keep the first that yields a real file, so a gap in one host is covered
  /// by the other instead of leaving the ayah silent.
  ///
  /// [globalAyah] is the 1..6236 index the islamic.network CDN uses;
  /// [surah]/[ayah] are what everyayah uses.
  static List<String> urlsFor({
    required String edition,
    required int surah,
    required int ayah,
    required int globalAyah,
  }) {
    final urls = <String>[];
    final folder = _everyAyahFolders[edition];
    if (folder != null) {
      urls.add(AppConfig.everyAyahUrl(folder, surah, ayah));
    }
    urls.addAll(AppConfig.ayahAudioUrls(edition, globalAyah));
    return urls;
  }

  /// The single best URL for [edition]'s ayah — what streaming playback binds
  /// to when the file is not on disk yet.
  static String primaryUrl({
    required String edition,
    required int surah,
    required int ayah,
    required int globalAyah,
  }) =>
      urlsFor(
        edition: edition,
        surah: surah,
        ayah: ayah,
        globalAyah: globalAyah,
      ).first;
}
