import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';
import '../db/models.dart';
import '../db/quran_repository.dart';

/// Progress of a surah recitation download.
class RecitationProgress {
  final int done;
  final int total;
  const RecitationProgress(this.done, this.total);

  double get fraction => total == 0 ? 0 : done / total;
  bool get isComplete => total > 0 && done >= total;
}

/// Ayah-level recitation: streaming, on-disk caching, and whole-surah
/// downloads.
///
/// Audio is stored one file per ayah rather than one file per surah. A surah
/// MP3 cannot be seeked to a given verse without a timing map, so per-ayah
/// files are what actually lets every ayah bind to its own recitation once the
/// download is finished — including with no network.
class AyahAudioService {
  AyahAudioService._();
  static final AyahAudioService instance = AyahAudioService._();

  static const String defaultEdition = 'ar.alafasy';

  final AudioPlayer _player = AudioPlayer();
  final Dio _dio = Dio();
  final Map<String, CancelToken> _downloads = {};

  bool get isPlaying => _player.playing;
  Stream<PlayerState> get playerState => _player.playerStateStream;

  Future<Directory> _editionDir(String edition) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'recitations', edition));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  File _fileFor(Directory dir, int globalAyah) =>
      File(p.join(dir.path, '$globalAyah.mp3'));

  static bool _looksComplete(File f) => f.existsSync() && f.lengthSync() > 2048;

  /// Plays one ayah, preferring the cached file so a downloaded surah works
  /// offline; otherwise streams and caches in the background for next time.
  Future<void> play(
    Ayah ayah,
    QuranRepository repo, {
    String edition = defaultEdition,
  }) async {
    try {
      final global = await repo.globalAyahNumber(ayah.surahId, ayah.ayahNumber);
      final dir = await _editionDir(edition);
      final file = _fileFor(dir, global);

      await _player.stop();

      if (_looksComplete(file)) {
        await _player.setFilePath(file.path);
        unawaited(_player.play());
        return;
      }

      for (final url in AppConfig.ayahAudioUrls(edition, global)) {
        try {
          await _player.setUrl(url);
          unawaited(_player.play());
          unawaited(_cache(url, file));
          return;
        } catch (_) {
          // try the next bitrate
        }
      }
    } catch (_) {
      // caller surfaces failure; never crash playback
    }
  }

  Future<void> _cache(String url, File dest) async {
    try {
      if (_looksComplete(dest)) return;
      final tmp = File('${dest.path}.part');
      await _dio.download(url, tmp.path);
      if (await tmp.length() > 2048) {
        await tmp.rename(dest.path);
      } else {
        await tmp.delete();
      }
    } catch (_) {
      // best effort
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
  }

  // ── Whole-surah download ─────────────────────────────────────────────────

  String _jobKey(String edition, int surah) => '$edition/$surah';

  bool isDownloading(String edition, int surah) =>
      _downloads.containsKey(_jobKey(edition, surah));

  void cancelDownload(String edition, int surah) {
    _downloads.remove(_jobKey(edition, surah))?.cancel('cancelled');
  }

  /// How many of [surah]'s ayahs are already on disk.
  Future<RecitationProgress> surahProgress(
    int surah,
    int ayahCount,
    QuranRepository repo, {
    String edition = defaultEdition,
  }) async {
    final dir = await _editionDir(edition);
    final first = await repo.globalAyahNumber(surah, 1);
    var done = 0;
    for (var i = 0; i < ayahCount; i++) {
      if (_looksComplete(_fileFor(dir, first + i))) done++;
    }
    return RecitationProgress(done, ayahCount);
  }

  /// Downloads every ayah of [surah]. Already-present ayahs are skipped, so an
  /// interrupted download resumes instead of starting over.
  Future<void> downloadSurah({
    required int surah,
    required int ayahCount,
    required QuranRepository repo,
    String edition = defaultEdition,
    void Function(RecitationProgress)? onProgress,
  }) async {
    final key = _jobKey(edition, surah);
    if (_downloads.containsKey(key)) return;
    final token = CancelToken();
    _downloads[key] = token;

    try {
      final dir = await _editionDir(edition);
      final first = await repo.globalAyahNumber(surah, 1);
      var done = 0;

      for (var i = 0; i < ayahCount; i++) {
        if (token.isCancelled) break;
        final file = _fileFor(dir, first + i);
        if (_looksComplete(file)) {
          done++;
          onProgress?.call(RecitationProgress(done, ayahCount));
          continue;
        }
        for (final url in AppConfig.ayahAudioUrls(edition, first + i)) {
          try {
            final tmp = File('${file.path}.part');
            await _dio.download(url, tmp.path, cancelToken: token);
            if (await tmp.length() > 2048) {
              await tmp.rename(file.path);
              done++;
              break;
            }
            await tmp.delete();
          } on DioException catch (e) {
            if (CancelToken.isCancel(e)) rethrow;
          } catch (_) {
            // try the next bitrate
          }
        }
        onProgress?.call(RecitationProgress(done, ayahCount));
      }
    } on DioException {
      // cancelled or network failure — partial files stay for the next resume
    } finally {
      _downloads.remove(key);
    }
  }

  /// Bytes this reciter's cached audio occupies.
  Future<int> cacheSizeBytes(String edition) async {
    final dir = await _editionDir(edition);
    if (!dir.existsSync()) return 0;
    var total = 0;
    for (final e in dir.listSync()) {
      if (e is File) total += e.lengthSync();
    }
    return total;
  }

  Future<void> clearCache(String edition) async {
    cancelDownloadsFor(edition);
    final dir = await _editionDir(edition);
    if (dir.existsSync()) await dir.delete(recursive: true);
  }

  void cancelDownloadsFor(String edition) {
    for (final k in _downloads.keys.toList()) {
      if (k.startsWith('$edition/')) _downloads.remove(k)?.cancel('cleared');
    }
  }
}
