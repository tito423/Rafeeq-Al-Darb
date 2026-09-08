import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart' as bd;
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart' show MediaItem;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../db/models.dart';
import '../db/quran_repository.dart';
import 'download_engine.dart';
import 'recitation_source.dart';

/// Progress of a surah recitation download.
class RecitationProgress {
  final int done;
  final int total;
  const RecitationProgress(this.done, this.total);

  double get fraction => total == 0 ? 0 : done / total;
  bool get isComplete => total > 0 && done >= total;
}

/// The live state of one surah's recitation download, published through a
/// [ValueNotifier] the service owns (see [AyahAudioService.surahJob]). The
/// state lives in the service, not in a widget — so a `ListView` tile can be
/// recycled/scrolled off and rebuilt, or the whole Downloads screen left and
/// reopened, and it re-attaches to the *same* live state instead of resetting
/// to a stale on-disk snapshot.
enum RecitationJobStatus { idle, downloading, paused, completed, failed }

class RecitationJob {
  final int done;
  final int total;
  final RecitationJobStatus status;
  const RecitationJob(this.done, this.total, this.status);

  static const idle = RecitationJob(0, 0, RecitationJobStatus.idle);

  double get fraction => total == 0 ? 0 : (done / total).clamp(0.0, 1.0);
  bool get isComplete =>
      status == RecitationJobStatus.completed || (total > 0 && done >= total);
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

/// What continuous (ayah-by-ayah, auto-advancing) recitation is doing right
/// now. Watched by the mushaf to highlight and scroll to the verse being
/// recited.
class ContinuousRecitation {
  final bool active;

  /// The verse currently sounding, or null before the first one starts.
  final int? surahId;
  final int? ayahNumber;

  /// Position within the surah being recited, for a progress readout.
  final int indexInSurah;
  final int totalInSurah;

  /// True while the next surah's sources are being prepared, so the UI can
  /// say "جارٍ التحميل" instead of looking frozen between surahs.
  final bool buffering;

  const ContinuousRecitation({
    this.active = false,
    this.surahId,
    this.ayahNumber,
    this.indexInSurah = 0,
    this.totalInSurah = 0,
    this.buffering = false,
  });

  static const stopped = ContinuousRecitation();

  bool isAyah(int surah, int ayah) =>
      active && surahId == surah && ayahNumber == ayah;
}

/// Ayah-level recitation: streaming, on-disk caching, whole-surah downloads,
/// and continuous auto-advancing playback.
///
/// Audio is stored one file per ayah rather than one file per surah. A surah
/// MP3 cannot be seeked to a given verse without a timing map, so per-ayah
/// files are what actually lets every ayah bind to its own recitation once the
/// download is finished — including with no network — and they are also what
/// makes verse-accurate highlighting possible during playback.
class AyahAudioService {
  AyahAudioService._();
  static final AyahAudioService instance = AyahAudioService._();

  static const String defaultEdition = 'ar.alafasy';

  /// **One** player for the whole app, on purpose. `main()` initialises
  /// `just_audio_background`, whose platform implementation throws
  /// *"just_audio_background supports only a single player instance"* on the
  /// second `AudioPlayer` created in the process. Every playback path here —
  /// single ayah, repeat loop, topic playlist, continuous recitation — shares
  /// this instance rather than making its own.
  final AudioPlayer _player = AudioPlayer();

  bool get isPlaying => _player.playing;
  Stream<PlayerState> get playerState => _player.playerStateStream;

  /// A plain `Stream<bool>` for UI code that only cares whether *something*
  /// is playing right now (e.g. the ayah card's single play/stop toggle) —
  /// keeps `package:just_audio`'s `PlayerState` type out of widget files that
  /// don't otherwise need it.
  Stream<bool> get isPlayingStream =>
      _player.playerStateStream.map((s) => s.playing);

  // ── Queue playback (memorization repeat-loop + topic playlists) ─────────

  /// Bumped on every `stopQueue()`/new `playQueue()` call so an in-flight
  /// loop notices it has been superseded and stops advancing instead of
  /// racing a newer one.
  int _queueToken = 0;

  bool get isQueuePlaying => _queueToken != 0;

  /// Plays [ayahs] one after another, waiting for each to finish before
  /// starting the next. Used for both the memorization repeat-loop (the same
  /// ayah repeated N times) and a topic's audio playlist.
  Future<void> playQueue(
    List<Ayah> ayahs,
    QuranRepository repo, {
    String edition = defaultEdition,
    Duration gap = Duration.zero,
    String Function(Ayah ayah, int index)? titleFor,
    void Function(int index)? onIndex,
  }) async {
    await stopContinuous();
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

  // ── Storage layout ──────────────────────────────────────────────────────

  Future<Directory> _editionDir(String edition) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'recitations', edition));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  /// Path relative to the documents directory, in the form
  /// `background_downloader` wants (`BaseDirectory.applicationDocuments` plus
  /// this). Kept in lockstep with [_editionDir] so a file the platform writes
  /// lands exactly where playback looks for it.
  String _editionRelativeDir(String edition) => 'recitations/$edition';

  File _fileFor(Directory dir, int globalAyah) =>
      File(p.join(dir.path, '$globalAyah.mp3'));

  static bool _looksComplete(File f) => f.existsSync() && f.lengthSync() > 2048;

  /// Every audio source must carry a [MediaItem] tag: `main()` initialises
  /// `just_audio_background`, which throws on any untagged source.
  MediaItem _tag(String edition, int global, Ayah ayah, String? title) =>
      MediaItem(
        id: '$edition:$global',
        album: 'رفيق الدرب',
        title: title ?? '${ayah.surahId}:${ayah.ayahNumber}',
      );

  // ── Single-ayah playback ────────────────────────────────────────────────

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

      final urls = RecitationSource.urlsFor(
        edition: edition,
        surah: ayah.surahId,
        ayah: ayah.ayahNumber,
        globalAyah: global,
      );
      for (final url in urls) {
        try {
          await _player.setAudioSource(
            AudioSource.uri(Uri.parse(url), tag: tag),
          );
          unawaited(_player.play());
          // Cache it for next time through the same platform downloader the
          // bulk downloads use, so one ayah listened to online is one ayah
          // that never needs downloading again.
          unawaited(_cacheSingle(edition, global, url));
          return;
        } catch (_) {
          // try the next source
        }
      }
    } catch (_) {
      // caller surfaces failure; never crash playback
    }
  }

  Future<void> _cacheSingle(String edition, int global, String url) async {
    try {
      final dir = await _editionDir(edition);
      if (_looksComplete(_fileFor(dir, global))) return;
      await DownloadEngine.ensureInitialized();
      DownloadEngine.recitationQueue.add(
        bd.DownloadTask(
          url: url,
          filename: '$global.mp3',
          baseDirectory: bd.BaseDirectory.applicationDocuments,
          directory: _editionRelativeDir(edition),
          group: DownloadEngine.groupRecitations,
          updates: bd.Updates.status,
          retries: 1,
        ),
      );
    } catch (_) {
      // best effort — playback already succeeded from the network
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
  }

  // ── Continuous recitation ───────────────────────────────────────────────
  //
  // "Read the whole mushaf, verse after verse, and follow along." The player
  // is fed a `ConcatenatingAudioSource` of one child per ayah, so just_audio
  // advances between verses itself (gapless, no Dart timer deciding when a
  // verse ended) and reports which verse is sounding through
  // `currentIndexStream` — that index is what drives the highlight.
  //
  // The playlist is built **one surah at a time** rather than all 6,236 ayahs
  // at once: each child is a real platform media source, and holding six
  // thousand of them open costs far more memory than it buys. When a surah's
  // playlist completes, the next surah is loaded and playback continues, so
  // the reading is continuous even though the playlist is not one giant list.

  final ValueNotifier<ContinuousRecitation> continuous =
      ValueNotifier(ContinuousRecitation.stopped);

  /// Bumped on every start/stop so a late async build from a superseded run
  /// cannot hijack the player.
  int _continuousToken = 0;

  StreamSubscription<int?>? _indexSub;
  StreamSubscription<PlayerState>? _completionSub;

  List<Ayah> _continuousAyahs = const [];
  String _continuousEdition = defaultEdition;
  bool _continuousWholeMushaf = true;

  bool get isContinuousActive => continuous.value.active;

  /// Starts continuous recitation from [from], reading to the end of its
  /// surah and — when [wholeMushaf] is true — straight on into the next one.
  Future<void> startContinuous({
    required Ayah from,
    required QuranRepository repo,
    String edition = defaultEdition,
    bool wholeMushaf = true,
  }) async {
    _queueToken = 0; // supersede any repeat-loop/playlist run
    final token = ++_continuousToken;
    _continuousEdition = edition;
    _continuousWholeMushaf = wholeMushaf;

    continuous.value = ContinuousRecitation(
      active: true,
      surahId: from.surahId,
      ayahNumber: from.ayahNumber,
      buffering: true,
    );

    await _loadSurahIntoPlayer(
      surahId: from.surahId,
      startAyahNumber: from.ayahNumber,
      repo: repo,
      token: token,
    );
  }

  /// Builds and starts one surah's playlist, beginning at [startAyahNumber].
  Future<void> _loadSurahIntoPlayer({
    required int surahId,
    required int startAyahNumber,
    required QuranRepository repo,
    required int token,
  }) async {
    final all = await repo.ayahsOfSurah(surahId);
    if (token != _continuousToken) return;
    if (all.isEmpty) {
      await stopContinuous();
      return;
    }

    final startIndex = all.indexWhere((a) => a.ayahNumber == startAyahNumber);
    final ayahs = all.sublist(startIndex < 0 ? 0 : startIndex);
    _continuousAyahs = ayahs;

    final dir = await _editionDir(_continuousEdition);
    final firstGlobal = await repo.globalAyahNumber(surahId, 1);
    if (token != _continuousToken) return;

    final children = <AudioSource>[];
    for (final a in ayahs) {
      final global = firstGlobal + (a.ayahNumber - 1);
      final tag = _tag(_continuousEdition, global, a, null);
      final file = _fileFor(dir, global);
      if (_looksComplete(file)) {
        children.add(AudioSource.file(file.path, tag: tag));
      } else {
        children.add(
          AudioSource.uri(
            Uri.parse(
              RecitationSource.primaryUrl(
                edition: _continuousEdition,
                surah: a.surahId,
                ayah: a.ayahNumber,
                globalAyah: global,
              ),
            ),
            tag: tag,
          ),
        );
      }
    }

    await _cancelContinuousSubs();
    if (token != _continuousToken) return;

    try {
      await _player.stop();
      await _player.setAudioSource(
        ConcatenatingAudioSource(children: children),
        initialIndex: 0,
      );
    } catch (_) {
      await stopContinuous();
      return;
    }
    if (token != _continuousToken) return;

    // The highlight source of truth: whichever child just_audio says is
    // playing *is* the verse being recited.
    _indexSub = _player.currentIndexStream.listen((index) {
      if (token != _continuousToken || index == null) return;
      if (index < 0 || index >= _continuousAyahs.length) return;
      final a = _continuousAyahs[index];
      continuous.value = ContinuousRecitation(
        active: true,
        surahId: a.surahId,
        ayahNumber: a.ayahNumber,
        indexInSurah: index,
        totalInSurah: _continuousAyahs.length,
      );
    });

    _completionSub = _player.playerStateStream.listen((s) {
      if (token != _continuousToken) return;
      if (s.processingState != ProcessingState.completed) return;
      unawaited(_advanceToNextSurah(surahId, repo, token));
    });

    unawaited(_player.play());
  }

  /// The surah's playlist ran out — keep reading into the next one, which is
  /// what makes this "continuous" rather than "play one surah".
  Future<void> _advanceToNextSurah(
    int finishedSurahId,
    QuranRepository repo,
    int token,
  ) async {
    if (token != _continuousToken) return;
    if (!_continuousWholeMushaf || finishedSurahId >= 114) {
      await stopContinuous();
      return;
    }
    continuous.value = ContinuousRecitation(
      active: true,
      surahId: finishedSurahId + 1,
      ayahNumber: 1,
      buffering: true,
    );
    await _loadSurahIntoPlayer(
      surahId: finishedSurahId + 1,
      startAyahNumber: 1,
      repo: repo,
      token: token,
    );
  }

  /// Skips to the next / previous verse without waiting for the current one.
  Future<void> continuousNext() async {
    if (!isContinuousActive) return;
    if (_player.hasNext) await _player.seekToNext();
  }

  Future<void> continuousPrevious() async {
    if (!isContinuousActive) return;
    if (_player.hasPrevious) await _player.seekToPrevious();
  }

  Future<void> continuousPauseResume() async {
    if (!isContinuousActive) return;
    if (_player.playing) {
      await _player.pause();
    } else {
      unawaited(_player.play());
    }
  }

  Future<void> stopContinuous() async {
    if (_continuousToken == 0 && !continuous.value.active) return;
    _continuousToken++;
    await _cancelContinuousSubs();
    _continuousAyahs = const [];
    continuous.value = ContinuousRecitation.stopped;
    await stop();
  }

  Future<void> _cancelContinuousSubs() async {
    await _indexSub?.cancel();
    await _completionSub?.cancel();
    _indexSub = null;
    _completionSub = null;
  }

  // ── Whole-surah download (platform-backed, observable) ──────────────────
  //
  // Rebuilt on `background_downloader`. The old engine walked a surah's ayahs
  // one at a time in Dart, awaiting a status-bar notification rebuild after
  // every single file. For سورة البقرة — 286 separate requests — that took
  // minutes and read as a permanent freeze, and any app suspension killed the
  // loop outright. Now every missing ayah is handed to the platform's own
  // downloader at once and run six-at-a-time by DownloadEngine's queue, which
  // keeps going while the app is backgrounded and posts a single grouped
  // notification counting finished files.

  String _jobKey(String edition, int surah) => '$edition/$surah';

  /// Surah download jobs the user has paused (job key -> paused).
  final Set<String> _paused = {};

  /// Editions whose "download whole reciter" run has been asked to stop.
  final Set<String> _fullCancel = {};

  final Map<String, ValueNotifier<RecitationJob>> _jobNotifiers = {};
  final Map<String, ValueNotifier<FullRecitationState>> _fullNotifiers = {};

  /// Live download jobs, by job key.
  final Map<String, _SurahDownloadJob> _jobs = {};

  /// platform taskId -> the attempt it belongs to, so a 404 on one host can
  /// be retried against the next candidate URL instead of losing the ayah.
  final Map<String, _AyahAttempt> _attempts = {};

  StreamSubscription<bd.TaskUpdate>? _downloadUpdates;
  bool _wired = false;

  ValueNotifier<RecitationJob> surahJob(String edition, int surah) =>
      _jobNotifiers.putIfAbsent(
        _jobKey(edition, surah),
        () => ValueNotifier(RecitationJob.idle),
      );

  ValueNotifier<FullRecitationState> fullJob(String edition) => _fullNotifiers
      .putIfAbsent(edition, () => ValueNotifier(const FullRecitationState()));

  void _setJob(String edition, int surah, RecitationJob job) =>
      surahJob(edition, surah).value = job;

  bool isDownloading(String edition, int surah) =>
      _jobs.containsKey(_jobKey(edition, surah));

  bool isDownloadPaused(String edition, int surah) =>
      _paused.contains(_jobKey(edition, surah));

  Future<void> _ensureWired() async {
    if (_wired) return;
    _wired = true;
    await DownloadEngine.ensureInitialized();
    // Via DownloadEngine's broadcast fan-out — see its `updates` doc.
    _downloadUpdates = DownloadEngine.updates.listen(_onDownloadUpdate);
  }

  void _onDownloadUpdate(bd.TaskUpdate update) {
    if (update.task.group != DownloadEngine.groupRecitations) return;
    if (update is! bd.TaskStatusUpdate) return;
    final attempt = _attempts[update.task.taskId];
    if (attempt == null) return;

    switch (update.status) {
      case bd.TaskStatus.enqueued:
      case bd.TaskStatus.running:
      case bd.TaskStatus.waitingToRetry:
      case bd.TaskStatus.paused:
        return; // nothing to settle yet
      case bd.TaskStatus.complete:
        _attempts.remove(update.task.taskId);
        attempt.job?.settle(attempt, succeeded: true);
      case bd.TaskStatus.canceled:
        _attempts.remove(update.task.taskId);
        attempt.job?.settle(attempt, succeeded: false);
      case bd.TaskStatus.notFound:
      case bd.TaskStatus.failed:
        _attempts.remove(update.task.taskId);
        // This host doesn't have the file (or refused it) — fall through to
        // the next candidate URL before giving up on the ayah.
        if (attempt.hasNextUrl) {
          _enqueueAttempt(attempt.advanced());
        } else {
          attempt.job?.settle(attempt, succeeded: false);
        }
    }
  }

  void _enqueueAttempt(_AyahAttempt attempt) {
    final task = bd.DownloadTask(
      url: attempt.url,
      filename: '${attempt.globalAyah}.mp3',
      baseDirectory: bd.BaseDirectory.applicationDocuments,
      directory: _editionRelativeDir(attempt.edition),
      group: DownloadEngine.groupRecitations,
      updates: bd.Updates.status,
      retries: 2,
      displayName: attempt.displayName,
      metaData: '${attempt.edition}|${attempt.globalAyah}',
    );
    attempt.taskId = task.taskId;
    _attempts[task.taskId] = attempt;
    attempt.job?.track(task.taskId);
    DownloadEngine.recitationQueue.add(task);
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
  /// job (that state is more current than a disk read).
  Future<void> refreshSurahJob(
    String edition,
    int surah,
    int ayahCount,
    QuranRepository repo,
  ) async {
    final n = surahJob(edition, surah);
    if (n.value.isActive) return;
    final progress = await surahProgress(
      surah,
      ayahCount,
      repo,
      edition: edition,
    );
    n.value = RecitationJob(
      progress.done,
      ayahCount,
      progress.isComplete
          ? RecitationJobStatus.completed
          : RecitationJobStatus.idle,
    );
  }

  /// Seed the "whole reciter" notifier from disk without starting a run.
  Future<void> refreshFullJob(
    String edition,
    List<Surah> surahs,
    QuranRepository repo,
  ) async {
    final n = fullJob(edition);
    if (n.value.running) return;
    var done = 0;
    for (final s in surahs) {
      final progress = await surahProgress(
        s.id,
        s.ayahsCount,
        repo,
        edition: edition,
      );
      if (progress.isComplete) done++;
    }
    n.value = FullRecitationState(
      doneSurahs: done,
      totalSurahs: surahs.length,
      running: false,
    );
  }

  /// Finds every surah of [edition] that is partly downloaded and resumes it.
  ///
  /// This is what the Downloads screen's "repair" action needs for recitations.
  /// `DownloadManager.resumeAll()` only ever knew about its own tasks (hadith,
  /// books, adhan clips) — recitations run through this service instead, so a
  /// surah left half-finished by a kill, a dropped connection or an OEM freeze
  /// was invisible to repair and stayed stuck until the user found and tapped
  /// that exact surah again. Large surahs are the ones this bites: al-Baqarah
  /// alone is 286 separate files, so it is the most likely to be interrupted
  /// and the most tedious to notice.
  ///
  /// Returns the number of surahs it restarted. Fully-downloaded and
  /// not-started surahs are both left alone — repair resumes real partial
  /// work, it does not start new downloads the user never asked for.
  Future<int> repairPartialDownloads({
    required String edition,
    required List<Surah> surahs,
    required QuranRepository repo,
  }) async {
    var repaired = 0;
    for (final s in surahs) {
      if (isDownloading(edition, s.id)) continue;
      final progress = await surahProgress(
        s.id,
        s.ayahsCount,
        repo,
        edition: edition,
      );
      // Untouched or already complete — nothing to repair.
      if (progress.done == 0 || progress.isComplete) continue;
      _paused.remove(_jobKey(edition, s.id));
      unawaited(
        _downloadSurahInternal(
          edition: edition,
          surah: s.id,
          ayahCount: s.ayahsCount,
          repo: repo,
        ),
      );
      repaired++;
    }
    return repaired;
  }

  /// Start (or no-op if already running) a single surah's download.
  Future<void> startSurahDownload({
    required String edition,
    required int surah,
    required int ayahCount,
    required QuranRepository repo,
    String? title,
  }) => _downloadSurahInternal(
    edition: edition,
    surah: surah,
    ayahCount: ayahCount,
    repo: repo,
    title: title,
  );

  /// Downloads every ayah of [surah] that is not already on disk, publishing
  /// live progress to [surahJob]. Already-present ayahs are skipped, so an
  /// interrupted download resumes instead of starting over.
  Future<void> _downloadSurahInternal({
    required String edition,
    required int surah,
    required int ayahCount,
    required QuranRepository repo,
    String? title,
  }) async {
    final key = _jobKey(edition, surah);
    if (_jobs.containsKey(key)) return;
    await _ensureWired();
    _paused.remove(key);

    final dir = await _editionDir(edition);
    final first = await repo.globalAyahNumber(surah, 1);

    final missing = <int>[]; // ayah numbers (1-based) still needed
    var alreadyDone = 0;
    for (var i = 0; i < ayahCount; i++) {
      if (_looksComplete(_fileFor(dir, first + i))) {
        alreadyDone++;
      } else {
        missing.add(i + 1);
      }
    }

    if (missing.isEmpty) {
      _setJob(
        edition,
        surah,
        RecitationJob(ayahCount, ayahCount, RecitationJobStatus.completed),
      );
      return;
    }

    final job = _SurahDownloadJob(
      edition: edition,
      surah: surah,
      ayahCount: ayahCount,
      done: alreadyDone,
      onProgress: (done, failed) {
        _setJob(
          edition,
          surah,
          RecitationJob(done, ayahCount, RecitationJobStatus.downloading),
        );
      },
    );
    _jobs[key] = job;
    _setJob(
      edition,
      surah,
      RecitationJob(alreadyDone, ayahCount, RecitationJobStatus.downloading),
    );

    final displayName = title ?? 'سورة $surah';
    for (final ayahNumber in missing) {
      final global = first + (ayahNumber - 1);
      _enqueueAttempt(
        _AyahAttempt(
          edition: edition,
          globalAyah: global,
          urls: RecitationSource.urlsFor(
            edition: edition,
            surah: surah,
            ayah: ayahNumber,
            globalAyah: global,
          ),
          displayName: displayName,
          job: job,
        ),
      );
    }

    try {
      await job.whenSettled;
    } finally {
      _jobs.remove(key);
      final progress = await surahProgress(
        surah,
        ayahCount,
        repo,
        edition: edition,
      );
      final complete = progress.done >= ayahCount;
      // Order matters here: `pauseDownload` sets the notifier to `paused` and
      // *then* cancels the job, which is what releases the await above — so
      // without this check the teardown would immediately overwrite the
      // paused state with `idle` and the tile would lose its resume button.
      final RecitationJobStatus status;
      if (complete) {
        status = RecitationJobStatus.completed;
      } else if (_paused.contains(key)) {
        status = RecitationJobStatus.paused;
      } else if (job.cancelled) {
        status = RecitationJobStatus.idle;
      } else {
        status = RecitationJobStatus.failed;
      }
      _setJob(edition, surah, RecitationJob(progress.done, ayahCount, status));
    }
  }

  /// Pause: stop this surah's in-flight transfers. Every finished ayah is
  /// already a complete file on disk, so resuming simply re-scans and asks
  /// for whatever is still missing — at most a handful of in-flight files are
  /// repeated, and each is a few dozen KB.
  void pauseDownload(String edition, int surah) {
    final key = _jobKey(edition, surah);
    _paused.add(key);
    _jobs[key]?.cancel();
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
    _jobs[key]?.cancel();
    final n = surahJob(edition, surah);
    n.value = n.value.withStatus(RecitationJobStatus.idle);
  }

  /// Download an entire reciter, surah by surah, from inside the service so it
  /// survives the Downloads screen being left.
  Future<void> startFullDownload({
    required String edition,
    required List<Surah> surahs,
    required QuranRepository repo,
  }) async {
    final full = fullJob(edition);
    if (full.value.running) return;
    _fullCancel.remove(edition);
    await _ensureWired();

    final completed = <int>{};
    for (final s in surahs) {
      final progress = await surahProgress(
        s.id,
        s.ayahsCount,
        repo,
        edition: edition,
      );
      if (progress.isComplete) completed.add(s.id);
    }
    full.value = FullRecitationState(
      doneSurahs: completed.length,
      totalSurahs: surahs.length,
      running: true,
    );

    try {
      for (final s in surahs) {
        if (_fullCancel.contains(edition)) break;
        if (completed.contains(s.id)) continue;
        full.value = FullRecitationState(
          doneSurahs: completed.length,
          totalSurahs: surahs.length,
          currentSurahId: s.id,
          running: true,
        );
        await _downloadSurahInternal(
          edition: edition,
          surah: s.id,
          ayahCount: s.ayahsCount,
          repo: repo,
          title: '${s.id}. ${s.nameAr}',
        );
        final after = await surahProgress(
          s.id,
          s.ayahsCount,
          repo,
          edition: edition,
        );
        if (after.isComplete) completed.add(s.id);
      }
    } finally {
      _fullCancel.remove(edition);
      full.value = FullRecitationState(
        doneSurahs: completed.length,
        totalSurahs: surahs.length,
        running: false,
      );
    }
  }

  /// Ask the "whole reciter" run to stop, and cancel the surah in flight.
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
    final prefix = '$edition/';
    for (final key in _jobs.keys.toList()) {
      if (key.startsWith(prefix)) _jobs[key]?.cancel();
    }
    _paused.removeWhere((k) => k.startsWith(prefix));
    // Reset the live notifiers for this edition so a "free space" clear is
    // reflected immediately in any recitation tiles/card watching them.
    for (final entry in _jobNotifiers.entries) {
      if (entry.key.startsWith(prefix)) entry.value.value = RecitationJob.idle;
    }
    _fullNotifiers[edition]?.value = const FullRecitationState();
  }

  /// Test/teardown hook — the singleton normally lives for the app session.
  Future<void> dispose() async {
    await _downloadUpdates?.cancel();
    await _cancelContinuousSubs();
    await _player.dispose();
  }
}

/// One ayah's download, and the fallback chain behind it.
///
/// `background_downloader` takes a single URL per task, but an ayah may be
/// available on everyayah and not on the CDN (or the reverse). Holding the
/// candidate list here lets a `notFound` re-enqueue the same ayah against the
/// next host rather than counting it as a permanent failure.
class _AyahAttempt {
  final String edition;
  final int globalAyah;
  final List<String> urls;
  final String displayName;
  final _SurahDownloadJob? job;
  final int urlIndex;

  String? taskId;

  _AyahAttempt({
    required this.edition,
    required this.globalAyah,
    required this.urls,
    required this.displayName,
    required this.job,
    this.urlIndex = 0,
  });

  String get url => urls[urlIndex];
  bool get hasNextUrl => urlIndex + 1 < urls.length;

  _AyahAttempt advanced() => _AyahAttempt(
    edition: edition,
    globalAyah: globalAyah,
    urls: urls,
    displayName: displayName,
    job: job,
    urlIndex: urlIndex + 1,
  );
}

/// Tracks the outstanding ayah transfers of one surah and completes once
/// every one of them has settled (finished, exhausted its fallbacks, or been
/// cancelled).
class _SurahDownloadJob {
  final String edition;
  final int surah;
  final int ayahCount;
  final void Function(int done, int failed) onProgress;

  final Set<String> _outstanding = {};
  final Completer<void> _completer = Completer<void>();

  int done;
  int failed = 0;
  bool cancelled = false;

  /// Set once every ayah has been handed to the queue, so an early gap in the
  /// outstanding set (the first task settling before the last is enqueued)
  /// cannot be mistaken for "all done".
  bool _sealed = false;

  _SurahDownloadJob({
    required this.edition,
    required this.surah,
    required this.ayahCount,
    required this.done,
    required this.onProgress,
  }) {
    // The enqueue loop is synchronous after construction, so sealing on the
    // next microtask is enough to cover it.
    scheduleMicrotask(() {
      _sealed = true;
      _checkDone();
    });
  }

  Future<void> get whenSettled => _completer.future;

  void track(String taskId) => _outstanding.add(taskId);

  void settle(_AyahAttempt attempt, {required bool succeeded}) {
    final id = attempt.taskId;
    if (id != null) _outstanding.remove(id);
    if (succeeded) {
      done++;
    } else {
      failed++;
    }
    onProgress(done, failed);
    _checkDone();
  }

  void cancel() {
    if (cancelled) return;
    cancelled = true;
    final ids = _outstanding.toList();
    _outstanding.clear();
    DownloadEngine.recitationQueue.removeTasksWithIds(ids);
    unawaited(bd.FileDownloader().cancelTasksWithIds(ids));
    _finish();
  }

  void _checkDone() {
    if (_sealed && _outstanding.isEmpty) _finish();
  }

  void _finish() {
    if (!_completer.isCompleted) _completer.complete();
  }
}
