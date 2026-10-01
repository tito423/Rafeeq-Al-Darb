import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';
import '../config/content_mirrors.dart';

/// The app's own copy of the recitations, on GitHub (R7).
///
/// Owner, 2026-10-02: «مش هنقدر نعتمد على سيرفيرات التحميل الخارجية», and
/// for where: «GitHub بس، ببلاش». `scripts/github_mirror_recitations.py`
/// copies every file byte for byte to `tito423/rafeeq-recitations`:
///   `ayah-<everyayah folder>-p<N>/SSSAAA.mp3` (seven parts, see [ayahPartStarts])
///   `surah-<mp3quran moshaf id>/SSS.mp3`
///
/// WHICH sets are there is data, not code: `config/recitation_mirrors.json`
/// on R2 (and on the content-mirror release), written by that script only
/// after every file of a set is on GitHub with the byte count the source
/// served. So nothing is tried before it resolves, and a set finished after
/// a release is used without a new APK. The copy goes first; the original
/// host stays behind it as the fallback.
class RecitationMirrors {
  RecitationMirrors._();
  static final RecitationMirrors instance = RecitationMirrors._();

  static const repo = 'tito423/rafeeq-recitations';

  /// First surah of each ayah part: a GitHub release holds at most 1000
  /// files, so a 6,236-ayah set is split by surah into parts of at most
  /// 996 (Hafs counts). Must equal AYAH_PART_STARTS in the script.
  static const ayahPartStarts = [1, 7, 16, 25, 37, 53, 80];

  Set<String> _ayah = const {};
  Set<int> _surah = const {};
  int _version = 0;

  bool hasAyah(String folder) => _ayah.contains(folder);
  bool hasSurah(int moshafId) => _surah.contains(moshafId);

  static int partOf(int surah) {
    var part = 1;
    for (var i = 0; i < ayahPartStarts.length; i++) {
      if (surah >= ayahPartStarts[i]) part = i + 1;
    }
    return part;
  }

  static String _pad(int n) => n.toString().padLeft(3, '0');

  static String ayahUrl(String folder, int surah, int ayah) =>
      'https://github.com/$repo/releases/download/'
      'ayah-$folder-p${partOf(surah)}/${_pad(surah)}${_pad(ayah)}.mp3';

  static String surahUrl(int moshafId, int surah) =>
      'https://github.com/$repo/releases/download/surah-$moshafId/${_pad(surah)}.mp3';

  static const _path = 'config/recitation_mirrors.json';

  Future<File> _cacheFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/recitation_mirrors.json');
  }

  /// The cached list at once, then the published one. Called at launch.
  Future<void> load() async {
    try {
      final f = await _cacheFile();
      if (f.existsSync()) apply(await f.readAsString());
    } catch (e) {
      debugPrint('recitation mirrors cache: $e');
    }
    try {
      final body = await ContentMirrors.fetchFirst<String>(
        '${AppConfig.contentBaseUrl}/$_path',
        (u) async => (await Dio().get<String>(u,
                options: Options(
                  responseType: ResponseType.plain,
                  receiveTimeout: const Duration(seconds: 20),
                )))
            .data!,
        accept: (b) => b.trimLeft().startsWith('{'),
      );
      if (apply(body)) await (await _cacheFile()).writeAsString(body);
    } catch (e) {
      debugPrint('recitation mirrors fetch: $e');
    }
  }

  /// Takes a published list; only a newer one, for this repository and
  /// this part layout, is applied. Public for tests.
  bool apply(String json) {
    try {
      final j = jsonDecode(json) as Map<String, dynamic>;
      final v = (j['version'] as num?)?.toInt() ?? 0;
      if (v <= _version || j['repo'] != repo) return false;
      final parts = (j['ayahPartStarts'] as List?)?.cast<num>().map((n) => n.toInt()).toList();
      if (!listEquals(parts, ayahPartStarts)) return false;
      _ayah = {...(j['ayah'] as List? ?? const []).cast<String>()};
      _surah = {...(j['surah'] as List? ?? const []).map((n) => (n as num).toInt())};
      _version = v;
      return true;
    } catch (_) {
      return false;
    }
  }
}
