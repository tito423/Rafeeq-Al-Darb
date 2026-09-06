import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart' show MediaItem;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';
import '../db/models.dart';
import '../db/quran_repository.dart';
import 'download_foreground_service.dart';
import 'download_manager.dart' show DownloadNotifications;

/// Progress of a surah recitation download.
class RecitationProgress {
  final int done;
  final int total;
  const RecitationProgress(this.done, this.total);

  double get fraction => total == 0 ? 0 : done / total;
  bool get isComplete => total > 0 && done >= total;
}

/// P3‑54: the live state of one surah's recitation download, published through
/// a [ValueNotifier] the service owns (see [AyahAudioService.surahJob]). The
/// state lives in the service, not in a widget — so a `ListView` tile can be
/// recycled/scrolled off and rebuilt, or the whole Downloads screen left and
/// reopened, and it re-attaches to the *same* live state instead of resetting
/// to a stale on-disk snapshot (the exact bug this replaces).
enum RecitationJobStatus { idle, downloading, paused, completed, failed }

class RecitationJob {
  final int done;
  final int total;
  final RecitationJobStatus status;
  const RecitationJob(this.done, this.total, this.status);

  static const idle = RecitationJob(0, 0, RecitationJobStatus.idle);

  double get fraction => total == 0 ? 0 : (done / total).clamp(0.0, 1.0);
  bool get isComplete =>
      status == RecitationJobStatus.completed ||
      (total > 0 && done >= total);
  bool get isActive =>
      status == RecitationJobStatus.downloading ||
      status == RecitationJobStatus.paused;

  RecitationJob withStatus(RecitationJobStatus s) =>
      RecitationJob(done, total, s);
}

/// Live state of a "download the whole reciter" run, published through
/// [AyahAudioService.fullJob]. The 114-surah loop that drives it runs *inside*
/// the service, not inside a widget, so navigating away from the Downloads
/// screen no longer aborts it mid-way.
class FullRecitationState {
  final int doneSurahs;
  final int totalSurahs;
  final int? currentSurahId;
  final bool running;
  const FullRecitationState({
    this.doneSurahs = 0,
    this.totalSurahs = 0,
    this.currentSurahId,
    this.running = false,
  });

  bool get isComplete => totalSurahs > 0 && doneSurahs >= totalSurahs;
  double? get fraction => totalSurahs == 0 ? null : doneSurahs / totalSurahs;
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
  // P3‑47: real-device feedback — recitation downloads "start but never
  // finish" / "hang directly". Root cause: a bare `Dio()` has NO timeouts,
  // so on a stalled/blocked connection every per-ayah request waits forever
  // with no error and no progress — the count sticks at 0 and the UI looks
  // frozen. Sensible timeouts turn a dead connection into a fast, honest
  // failure the loop can move past (or surface), instead of an infinite wait.
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 60),
    sendTimeout: const Duration(seconds: 20),
  ));
  final Map<String, CancelToken> _downloads = {};

  bool get isPlaying => _player.playing;
  Stream<PlayerState> get playerState => _player.playerStateStream;

  /// P3‑35: a plain `Stream<bool>` for UI code that only cares whether
  /// *something* is playing right now (e.g. the ayah card's single
  /// play/stop toggle) — keeps `package:just_audio`'s `PlayerState` type out
  /// of widget files that don't otherwise need it.
  Stream<bool> get isPlayingStream => _player.playerStateStream.map((s) => s.playing);

  // ── Queue playback (P2‑8: memorization repeat-loop + topic playlists) ────

  /// Bumped on every `stopQueue()`/new `playQueue()` call so an in-flight
  /// loop notices it has been superseded and stops advancing instead of
  /// racing a newer one.
  int _queueToken = 0;

  bool get isQueuePlaying => _queueToken != 0;

  /// Plays [ayahs] one after another, waiting for each to finish before
  /// starting the next. Used for both the memorization repeat-loop (the same
  /// ayah repeated N times) and a topic's audio playlist (Stage 6's curated
  /// `topic_tree.dart` ranges, played in order).
  Future<void> playQueue(
    List<Ayah> ayahs,
    QuranRepository repo, {
    String edition = defaultEdition,
    Duration gap = Duration.zero,
    String Function(Ayah ayah, int index)? titleFor,
    void Function(int index)? onIndex,
  }) async {
    final token = ++_queueToken;
    for (var i = 0; i < ayahs.length; i++) {
      if (token != _queueToken) return; // superseded by a newer call/stop
      onIndex?.call(i);
      await play(
        ayahs[i],
        repo,
        edition: edition,
        title: titleFor?.call(ayahs[i], i),
      );
      await _waitForCompletionOrToken(token);
      if (token != _queueToken) return;
      if (gap > Duration.zero) await Future<void>.delayed(gap);
    }
    if (token == _queueToken) _queueToken = 0;
  }

  /// Convenience for the memorization loop: the same ayah, [times] times,
  /// with [gap] of silence between repetitions.
  Future<void> playRepeated(
    Ayah ayah,
    QuranRepository repo, {
    required int times,
    required Duration gap,
    String edition = defaultEdition,
    String? title,
  }) {
    return playQueue(
      List.filled(times, ayah),
      repo,
      edition: edition,
      gap: gap,
      titleFor: title == null ? null : (a, i) => title,
    );
  }

  Future<void> _waitForCompletionOrToken(int token) async {
    final completer = Completer<void>();
    late final StreamSubscription<PlayerState> sub;
    sub = _player.playerStateStream.listen((s) {
      if (token != _queueToken ||
          s.processingState == ProcessingState.completed) {
        sub.cancel();
        if (!completer.isCompleted) completer.complete();
      }
    });
    await completer.future;
  }

  /// Cancels any in-flight `playQueue`/`playRepeated` loop and stops audio.
  Future<void> stopQueue() async {
    _queueToken = 0;
    await stop();
  }

  Future<Directory> _editionDir(String edition) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'recitations', edition));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  File _fileFor(Directory dir, int globalAyah) =>
      File(p.join(dir.path, '$globalAyah.mp3'));

  static bool _looksComplete(File f) => f.existsSync() && f.lengthSync() > 2048;

  /// Every audio source must carry a [MediaItem] tag: `main()` initialises
  /// `just_audio_background`, which throws on any untagged source (that was why
  /// playback silently did nothing).
  MediaItem _tag(String edition, int global, Ayah ayah, String? title) =>
      MediaItem(
        id: '$edition:$global',
        album: 'رفيق الدرب',
        title: title ?? '${ayah.surahId}:${ayah.ayahNumber}',
      );

  /// Plays one ayah, preferring the cached file so a downloaded surah works
  /// offline; otherwise streams and caches in the background for next time.
  Future<void> play(
    Ayah ayah,
    QuranRepository repo, {
    String edition = defaultEdition,
    String? title,
  }) async {
    try {
      final global = await repo.globalAyahNumber(ayah.surahId, ayah.ayahNumber);
      final dir = await _editionDir(edition);
      final file = _fileFor(dir, global);
      final tag = _tag(edition, global, ayah, title);

      await _player.stop();

      if (_looksComplete(file)) {
        await _player.setAudioSource(AudioSource.file(file.path, tag: tag));
        unawaited(_player.play());
        return;
      }

      for (final url in AppConfig.ayahAudioUrls(edition, global)) {
        try {
          await _player
              .setAudioSource(AudioSource.uri(Uri.parse(url), tag: tag));
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

  // ── Whole-surah download (service-owned, observable) ─────────────────────
  //
  // P3‑54: the download orchestration and its progress now live entirely in
  // this singleton service and are published through per-job `ValueNotifier`s,
  // instead of being driven and stored inside the Downloads-screen widgets.
  // That fixes the two real bugs the owner hit:
  //   • the per-surah tile's progress bar looked frozen / only refreshed after
  //     leaving and returning — because the state lived in a `ListView` tile
  //     that gets recycled on scroll. Now every tile re-attaches to the same
  //     live notifier, so a running download shows real-time progress no matter
  //     how the list is scrolled or the screen is left and reopened.
  //   • "download the whole reciter" stopped when you navigated away — because
  //     its 114-surah loop ran inside the card widget with an `if (!mounted)
  //     return;` inside it. The loop now runs in the service and keeps going
  //     (protected by the foreground service) regardless of the UI.

  String _jobKey(String edition, int surah) => '$edition/$surah';

  /// Surah download jobs the user has paused (job key -> paused).
  final Set<String> _paused = {};

  /// Editions whose "download whole reciter" run has been asked to stop.
  final Set<String> _fullCancel = {};

  /// Live per-surah download state, one notifier per (edition, surah), created
  /// lazily and kept for the app session so any rebuilt widget re-attaches to
  /// the same live value.
  final Map<String, ValueNotifier<RecitationJob>> _jobNotifiers = {};

  /// Live "download whole reciter" state, one notifier per edition.
  final Map<String, ValueNotifier<FullRecitationState>> _fullNotifiers = {};

  ValueNotifier<RecitationJob> surahJob(String edition, int surah) =>
      _jobNotifiers.putIfAbsent(
          _jobKey(edition, surah), () => ValueNotifier(RecitationJob.idle));

  ValueNotifier<FullRecitationState> fullJob(String edition) => _fullNotifiers
      .putIfAbsent(edition, () => ValueNotifier(const FullRecitationState()));

  void _setJob(String edition, int surah, RecitationJob job) =>
      surahJob(edition, surah).value = job;

  bool isDownloading(String edition, int surah) =>
      _downloads.containsKey(_jobKey(edition, surah));

  bool isDownloadPaused(String edition, int surah) =>
      _paused.contains(_jobKey(edition, surah));

  void pauseDownload(String edition, int surah) {
    _paused.add(_jobKey(edition, surah));
    final n = surahJob(edition, surah);
    n.value = n.value.withStatus(RecitationJobStatus.paused);
  }

  void resumeDownload(String edition, int surah) {
    _paused.remove(_jobKey(edition, surah));
    final n = surahJob(edition, surah);
    if (n.value.isActive) {
      n.value = n.value.withStatus(RecitationJobStatus.downloading);
    }
  }

  void cancelDownload(String edition, int surah) {
    final key = _jobKey(edition, surah);
    _paused.remove(key);
    _downloads.remove(key)?.cancel('cancelled');
    final n = surahJob(edition, surah);
    n.value = n.value.withStatus(RecitationJobStatus.idle);
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

  /// Seed a surah's live notifier from what's actually on disk — called by the
  /// tile when it first appears. Never clobbers an actively downloading/paused
  /// job (that state is more current than a disk read), so scrolling a tile
  /// back into view mid-download keeps its real progress.
  Future<void> refreshSurahJob(
    String edition,
    int surah,
    int ayahCount,
    QuranRepository repo,
  ) async {
    final n = surahJob(edition, surah);
    if (n.value.isActive) return;
    final p = await surahProgress(surah, ayahCount, repo, edition: edition);
    n.value = RecitationJob(p.done, ayahCount,
        p.isComplete ? RecitationJobStatus.completed : RecitationJobStatus.idle);
  }

  /// Seed the "whole reciter" notifier from disk (done/total surahs) without
  /// starting a run — for the card's first paint. No-op while a run is active.
  Future<void> refreshFullJob(
    String edition,
    List<Surah> surahs,
    QuranRepository repo,
  ) async {
    final n = fullJob(edition);
    if (n.value.running) return;
    var done = 0;
    for (final s in surahs) {
      final p = await surahProgress(s.id, s.ayahsCount, repo, edition: edition);
      if (p.isComplete) done++;
    }
    n.value = FullRecitationState(
        doneSurahs: done, totalSurahs: surahs.length, running: false);
  }

  /// Start (or no-op if already running) a single surah's download. Runs to
  /// completion in the service; the UI just watches [surahJob].
  Future<void> startSurahDownload({
    required String edition,
    required int surah,
    required int ayahCount,
    required QuranRepository repo,
    String? title,
  }) =>
      _downloadSurahInternal(
        edition: edition,
        surah: surah,
        ayahCount: ayahCount,
        repo: repo,
        title: title,
      );

  /// Downloads every ayah of [surah], publishing live progress to [surahJob].
  /// Already-present ayahs are skipped, so an interrupted download resumes
  /// instead of starting over.
  Future<void> _downloadSurahInternal({
    required String edition,
    required int surah,
    required int ayahCount,
    required QuranRepository repo,
    String? title,
  }) async {
    final key = _jobKey(edition, surah);
    if (_downloads.containsKey(key)) return;
    final token = CancelToken();
    _downloads[key] = token;

    // P2‑5: every download posts a live status-bar progress notification whose
    // percentage tracks the in-app progress exactly (same `done/ayahCount`).
    final notifId = 'recite_$key';
    final notifTitle = title ?? 'سورة $surah';
    await DownloadNotifications.instance.ensureInitialized();
    var cancelled = false;
    // P3-46: protects this process from being frozen/killed by the OS while
    // backgrounded during this download (paired release in `finally`).
    await DownloadForegroundServiceBridge.acquire(title: notifTitle);

    try {
      final dir = await _editionDir(edition);
      final first = await repo.globalAyahNumber(surah, 1);
      var done = 0;
      _setJob(edition, surah,
          RecitationJob(done, ayahCount, RecitationJobStatus.downloading));

      for (var i = 0; i < ayahCount; i++) {
        if (token.isCancelled) {
          cancelled = true;
          break;
        }
        // Pause: idle here until resumed or cancelled.
        var wasPaused = false;
        while (_paused.contains(key) && !token.isCancelled) {
          if (!wasPaused) {
            wasPaused = true;
            _setJob(edition, surah,
                RecitationJob(done, ayahCount, RecitationJobStatus.paused));
            await DownloadNotifications.instance.clear(notifId);
          }
          await Future<void>.delayed(const Duration(milliseconds: 400));
        }
        if (wasPaused && !token.isCancelled) {
          _setJob(edition, surah,
              RecitationJob(done, ayahCount, RecitationJobStatus.downloading));
        }
        if (token.isCancelled) {
          cancelled = true;
          break;
        }
        final file = _fileFor(dir, first + i);
        if (_looksComplete(file)) {
          done++;
        } else {
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
        }
        _setJob(edition, surah,
            RecitationJob(done, ayahCount, RecitationJobStatus.downloading));
        await DownloadNotifications.instance.showProgress(
            id: notifId,
            title: notifTitle,
            done: done,
            total: ayahCount,
            detail: '$done / $ayahCount');
      }
    } on DioException {
      // cancelled or network failure — partial files stay for the next resume
      cancelled = true;
    } finally {
      _downloads.remove(key);
      _paused.remove(key);
      final p = await surahProgress(surah, ayahCount, repo, edition: edition);
      final complete = p.done >= ayahCount;
      _setJob(
          edition,
          surah,
          RecitationJob(
              p.done,
              ayahCount,
              complete
                  ? RecitationJobStatus.completed
                  : (cancelled
                      ? RecitationJobStatus.idle
                      : RecitationJobStatus.failed)));
      if (!cancelled && complete) {
        await DownloadNotifications.instance
            .showComplete(id: notifId, title: notifTitle);
      } else {
        await DownloadNotifications.instance.clear(notifId);
      }
      await DownloadForegroundServiceBridge.release();
    }
  }

  /// Download an entire reciter, surah by surah, from inside the service so it
  /// survives the Downloads screen being left. Publishes to [fullJob]; also
  /// drives each surah's own [surahJob] as it goes, so the per-surah tiles show
  /// live progress for whichever surah is currently transferring.
  Future<void> startFullDownload({
    required String edition,
    required List<Surah> surahs,
    required QuranRepository repo,
  }) async {
    final full = fullJob(edition);
    if (full.value.running) return;
    _fullCancel.remove(edition);

    final completed = <int>{};
    for (final s in surahs) {
      final p = await surahProgress(s.id, s.ayahsCount, repo, edition: edition);
      if (p.isComplete) completed.add(s.id);
    }
    full.value = FullRecitationState(
        doneSurahs: completed.length,
        totalSurahs: surahs.length,
        running: true);

    try {
      for (final s in surahs) {
        if (_fullCancel.contains(edition)) break;
        if (!completed.contains(s.id)) {
          full.value = FullRecitationState(
              doneSurahs: completed.length,
              totalSurahs: surahs.length,
              currentSurahId: s.id,
              running: true);
          await _downloadSurahInternal(
            edition: edition,
            surah: s.id,
            ayahCount: s.ayahsCount,
            repo: repo,
            title: '${s.id}. ${s.nameAr}',
          );
          final after =
              await surahProgress(s.id, s.ayahsCount, repo, edition: edition);
          if (after.isComplete) completed.add(s.id);
        }
      }
    } finally {
      _fullCancel.remove(edition);
      full.value = FullRecitationState(
          doneSurahs: completed.length,
          totalSurahs: surahs.length,
          running: false);
    }
  }

  /// Ask the "whole reciter" run to stop after the current ayah, and cancel the
  /// surah currently in flight.
  void cancelFullDownload(String edition) {
    _fullCancel.add(edition);
    final cur = fullJob(edition).value.currentSurahId;
    if (cur != null) cancelDownload(edition, cur);
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
    _fullCancel.add(edition);
    for (final k in _downloads.keys.toList()) {
      if (k.startsWith('$edition/')) _downloads.remove(k)?.cancel('cleared');
    }
    _paused.removeWhere((k) => k.startsWith('$edition/'));
    // Reset the live notifiers for this edition so a "free space" clear is
    // reflected immediately in any recitation tiles/card watching them
    // (they'd otherwise keep showing the pre-clear state until remounted).
    final prefix = '$edition/';
    for (final entry in _jobNotifiers.entries) {
      if (entry.key.startsWith(prefix)) entry.value.value = RecitationJob.idle;
    }
    final full = _fullNotifiers[edition];
    if (full != null) full.value = const FullRecitationState();
  }
}
