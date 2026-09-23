
import '../../features/quran_audio/data/ayah_recitation_library.dart';
import '../config/app_config.dart';

/// Where one ayah's recitation audio actually comes from.
///
/// The app's reciter list comes from the alquran.cloud editions catalog (175
/// named Arabic entries in `assets/data/catalogs/audio_editions.json`), but
/// only some of those are genuinely served as per-ayah MP3s anywhere. This
/// class maps the ones that are onto **everyayah.com**, and
/// `recitersProvider` shows the reader exactly that set.
///
/// It used to fall back to islamic.network's CDN "so a reciter is never
/// silently silent". Measured on 2026-09-23, that sentence was false: a range
/// request for `1.mp3` on that CDN returned **403 AccessDenied** for 157 of
/// the 175, and 200 for only 18 — which are the same reciters this map
/// already had. So the fallback covered nothing the primary did not, and the
/// 157 others were offered in the picker and played nothing at all. That is
/// the owner's «التلاوة في التلاوة المستمرة مش شغالة بعد ما اختار القارئ»,
/// and the same silence in hifz «استمع», which reads the same setting.
/// The CDN stays as a second URL for the mapped reciters; it is no longer
/// treated as a source that makes an unmapped reciter listable.
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
    // 2026-09-23. The owner's «التلاوة مش شغالة بعد ما اختار القارئ» was this
    // map being 19 entries long while the picker offered 175 reciters: the
    // fallback host answers **403 AccessDenied** for everything it does not
    // hold, so 157 of those 175 had no source at all and picking one was
    // silence. These eighteen were read off everyayah's own directory index
    // and matched by the reciter's ARABIC name, not by a fuzzy transliteration
    // score — a wrong match here would put one shaykh's voice under another's
    // name. Each folder was range-checked at BOTH 001001 and 114006 (206,
    // audio/mpeg); `Ibrahim_Akhdar_64kbps` is listed in that index and 404s,
    // so the 32 kbps folder is the one used.
    'ar.abdulbasitmujawwad': 'Abdul_Basit_Mujawwad_128kbps',
    'ar.abdullahalmatrood': 'Abdullah_Matroud_128kbps',
    'ar.abdullahawadaljuhani': 'Abdullaah_3awwaad_Al-Juhaynee_128kbps',
    'ar.alihajjajsouissi': 'Ali_Hajjaj_AlSuesy_128kbps',
    'ar.aymanswoaid': 'Ayman_Sowaid_64kbps',
    'ar.azizalili': 'aziz_alili_128kbps',
    'ar.ibrahimalakhdar': 'Ibrahim_Akhdar_32kbps',
    'ar.khaledalqahtani': 'Khaalid_Abdullaah_al-Qahtaanee_192kbps',
    'ar.khalifaaltunaiji': 'khalefa_al_tunaiji_64kbps',
    'ar.mahmoudalialbanna': 'mahmoud_ali_al_banna_32kbps',
    'ar.muhammadabdulkareem': 'Muhammad_AbdulKareem_128kbps',
    'ar.mustafaismail': 'Mustafa_Ismail_48kbps',
    'ar.nabilarrifai': 'Nabil_Rifa3i_48kbps',
    'ar.parhizgar': 'Parhizgar_48kbps',
    'ar.sahlyasin': 'Sahl_Yassin_128kbps',
    'ar.salahalbudair': 'Salah_Al_Budair_128kbps',
    'ar.yasseraldossari': 'Yasser_Ad-Dussary_128kbps',
    'ar.yassersalama': 'Yaser_Salamah_128kbps',
  };

  /// Every edition that has a verified per-ayah source, and the folder it
  /// lives in. This IS the reciter list the app offers
  /// (`recitersProvider` filters by it), so a typo in a key here silently
  /// removes a shaykh from the picker — `reciter_sources_test.dart` checks
  /// every key against the editions catalogue.
  static Map<String, String> get verifiedMirrors =>
      Map.unmodifiable(_everyAyahFolders);

  /// Whether [edition] has a verified everyayah mirror. False now also means
  /// the app has no way to play it at all, which is why such an edition is
  /// not listed to the reader.
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
    final local =
        AyahRecitationLibrary.instance.localFile(edition, surah, ayah);
    if (local != null) return [Uri.file(local.path).toString()];

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
