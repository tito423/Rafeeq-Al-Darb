import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart' as bd;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
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

  /// The run is nominally still active but the platform player has gone —
  /// Android released it while the app sat in the background. The verse and
  /// position are still meaningful (they are where to resume from); what is
  /// not true any more is that anything is sounding. Set on app resume by
  /// [AyahAudioService.onAppResumed].
  final bool stalled;

  const ContinuousRecitation({
    this.active = false,
    this.surahId,
    this.ayahNumber,
    this.indexInSurah = 0,
    this.totalInSurah = 0,
    this.buffering = false,
    this.stalled = false,
  });

  static const stopped = ContinuousRecitation();

  ContinuousRecitation copyWith({bool? stalled, bool? buffering}) =>
      ContinuousRecitation(
        active: active,
        surahId: surahId,
        ayahNumber: ayahNumber,
        indexInSurah: indexInSurah,
        totalInSurah: totalInSurah,
        buffering: buffering ?? this.buffering,
        stalled: stalled ?? this.stalled,
      );

  bool isAyah(int surah, int ayah) =>
      active && surahId == surah && ayahNumber == ayah;
}

/// Why a continuous recitation could not start or carry on.
enum ContinuousError {
  /// The verses' audio could not be opened, even after the player itself was
  /// rebuilt. Network, or a source that genuinely is not there.
  loadFailed,
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
  AyahAudioService._() {
    // Registered here rather than in each reader screen so the recovery
    // applies wherever a recitation can be running — the mushaf reader and
    // the Sunan Suwar reader both drive the same service.
    try {
      _lifecycle = AppLifecycleListener(onResume: onAppResumed);
    } catch (_) {
      // No widget binding (a unit test constructing the service): nothing to
      // observe, and playback is not what such a test is exercising.
    }
  }
  static final AyahAudioService instance = AyahAudioService._();

  // ignore: unused_field
  AppLifecycleListener? _lifecycle;

  /// The reciter every fresh install starts on — the owner's choice:
  /// محمد صديق المنشاوي (المجود). It has a verified everyayah mirror
  /// (`Minshawy_Mujawwad_192kbps`, a range request on 002001.mp3 answered 206
  /// on 2026-09-09), so it is a resumable, per-ayah source on day one and not
  /// only a CDN stream.
  static const String defaultEdition = 'ar.minshawimujawwad';

  /// **One** player for the whole app at a time, on purpose. `main()`
  /// initialises `just_audio_background`, whose platform implementation throws
  /// *"just_audio_background supports only a single player instance"* on a
  /// second concurrently-live `AudioPlayer`. Every playback path here — single
  /// ayah, repeat loop, topic playlist, continuous recitation — shares this
  /// one rather than making its own.
  ///
  /// Not `final`, because it can be **replaced**: see [_recreatePlayer]. The
  /// package's own `disposePlayer` clears its `_playerId` (read in
  /// just_audio_background 0.0.1-beta.17, `just_audio_background.dart:143`),
  /// so a new player after a disposed one is allowed — it is only a second
  /// *simultaneous* one that is refused.
  AudioPlayer _player = AudioPlayer();

  /// The player's state, re-broadcast by the service rather than handed out
  /// directly, so a widget that subscribed before a [_recreatePlayer] keeps
  /// receiving events from whichever player is current. Handing out
  /// `_player.playerStateStream` would leave every existing `StreamBuilder`
  /// listening to a dead player.
  final StreamController<PlayerState> _stateOut =
      StreamController<PlayerState>.broadcast();
  StreamSubscription<PlayerState>? _stateBridge;
  bool _bridged = false;

  void _bridgePlayerState() {
    _stateBridge?.cancel();
    _stateBridge = _player.playerStateStream.listen(
      _stateOut.add,
      onError: (Object _) {},
    );
    _bridged = true;
  }

  bool get isPlaying => _player.playing;

  Stream<PlayerState> get playerState {
    if (!_bridged) _bridgePlayerState();
    return _stateOut.stream;
  }

  /// A plain `Stream<bool>` for UI code that only cares whether *something*
  /// is playing right now (e.g. the ayah card's single play/stop toggle) —
  /// keeps `package:just_audio`'s `PlayerState` type out of widget files that
  /// don't otherwise need it.
  Stream<bool> get isPlayingStream =>
      playerState.map((s) => s.playing).distinct();

  /// True when the platform side has gone away under us: the player reports
  /// nothing loaded and nothing playing.
  ///
  /// This is the state the owner hit — «التلاوة بتهنج لو التطبيق راح في
  /// الخلفية فترة طويلة ولما بحاول أضغط أشغّلها مفيش حاجة بتحصل». Android
  /// tears down the `audio_service` foreground service (and with it the
  /// platform player) after a long stretch in the background, while this
  /// isolate lives on believing a recitation is still running: `play()` on a
  /// released player is a silent no-op, and the reader's play button did
  /// nothing at all.
  bool get _playerIsIdle =>
      !_player.playing &&
      (_player.processingState == ProcessingState.idle ||
          _player.processingState == ProcessingState.completed);

  /// Throws away the platform player and builds a fresh one.
  ///
  /// Disposal first is what makes this legal (see [_player]'s note), and it
  /// is awaited so the plugin has really released its id before the new
  /// player asks for one.
  Future<void> _recreatePlayer() async {
    final old = _player;
    await _stateBridge?.cancel();
    _stateBridge = null;
    try {
      await old.dispose();
    } catch (_) {
      // A player that is already gone is exactly the case being recovered
      // from; its disposal failing changes nothing.
    }
    _player = AudioPlayer();
    if (_bridged) _bridgePlayerState();
  }

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
        album: 'app.name'.tr(),
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

      // A single ayah supersedes continuous recitation *properly*. Stopping
      // only the player used to leave `continuous.value.active == true` with
      // its `currentIndexStream`/completion subscriptions still bound to a
      // live token: the transport bar went on claiming a recitation was
      // running while nothing played, and when this one ayah finished the
      // stale completion listener fired `_advanceToNextSurah` and jumped to a
      // surah nobody asked for. Guarded on `active` because `playQueue`
      // already stopped continuous before its loop, and an unguarded call
      // here would stop the player between every verse of the queue.
      if (continuous.value.active) {
        await stopContinuous();
      }

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
      // Silent, invisible caching of an ayah the reader is already hearing —
      // it must never be the thing that raises a permission dialog over the
      // page. The user-initiated whole-surah download still asks.
      await DownloadEngine.ensureInitialized(askForNotifications: false);
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

  // ── Long-form tracks (the recorded ruqyahs) ─────────────────────────────

  /// Plays one long recording — a file if it has been downloaded, otherwise
  /// streamed from [url].
  ///
  /// This goes through the app's single player for the same reason every
  /// other playback path does: `just_audio_background` throws on the second
  /// `AudioPlayer` in the process. A 75-minute ruqyah is exactly the kind of
  /// thing a reader starts and then locks the phone on, so it has to be the
  /// player that owns the notification, not a silent second one.
  ///
  /// Returns false if the source could not be opened, so the caller can say so
  /// instead of leaving a dead play button.
  Future<bool> playTrack({
    required String id,
    required String url,
    required String title,
    String? artist,
    File? localFile,
  }) async {
    try {
      await stopQueue();
      await stopContinuous();
      final tag = MediaItem(
        id: 'track:$id',
        album: 'app.name'.tr(),
        title: title,
        artist: artist,
      );
      if (localFile != null && localFile.existsSync()) {
        await _player.setAudioSource(
          AudioSource.file(localFile.path, tag: tag),
        );
      } else {
        await _player.setAudioSource(AudioSource.uri(Uri.parse(url), tag: tag));
      }
      unawaited(_player.play());
      return true;
    } catch (e) {
      debugPrint('playTrack failed for $id: $e');
      return false;
    }
  }

  /// Whether the player is currently on [id]'s track. Used by a list of
  /// recordings to show the stop button on the right row and only that row.
  bool isTrack(String id) =>
      (_player.sequenceState?.currentSource?.tag as MediaItem?)?.id ==
      'track:$id';

  Stream<Duration> get positionStream => _player.positionStream;

  Duration? get trackDuration => _player.duration;

  Future<void> pauseResumeTrack() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> seekTrack(Duration to) => _player.seek(to);

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

  /// Set when a recitation could not be started or resumed, so the reader can
  /// **say so** instead of leaving a play button that does nothing. The screen
  /// clears it once it has shown the message.
  final ValueNotifier<ContinuousError?> continuousError =
      ValueNotifier<ContinuousError?>(null);

  /// Bumped on every start/stop so a late async build from a superseded run
  /// cannot hijack the player.
  int _continuousToken = 0;

  StreamSubscription<int?>? _indexSub;
  StreamSubscription<PlayerState>? _completionSub;

  List<Ayah> _continuousAyahs = const [];
  String _continuousEdition = defaultEdition;
  bool _continuousWholeMushaf = true;

  /// The repository the running recitation was started with, kept so the
  /// transport can restart a wedged run without the widget having to hand it
  /// back in. See [continuousPauseResume].
  QuranRepository? _continuousRepo;

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
    _continuousRepo = repo;

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

    // Built fresh on each attempt below: an `AudioSource` is bound to the
    // player it was given to, so the retry after [_recreatePlayer] must not
    // reuse the objects the disposed player already saw.
    List<AudioSource> buildChildren() => [
          for (final a in ayahs)
            () {
              final global = firstGlobal + (a.ayahNumber - 1);
              final tag = _tag(_continuousEdition, global, a, null);
              final file = _fileFor(dir, global);
              return _looksComplete(file)
                  ? AudioSource.file(file.path, tag: tag)
                  : AudioSource.uri(
                      Uri.parse(
                        RecitationSource.primaryUrl(
                          edition: _continuousEdition,
                          surah: a.surahId,
                          ayah: a.ayahNumber,
                          globalAyah: global,
                        ),
                      ),
                      tag: tag,
                    );
            }(),
        ];

    await _cancelContinuousSubs();
    if (token != _continuousToken) return;

    // Two attempts, and the second one is on a **new** player.
    //
    // A `setAudioSource` that throws used to end the recitation outright —
    // `stopContinuous()` and silence, with no way back except killing the
    // app. The common cause is not a bad source but a platform player Android
    // released while the app sat in the background, which throws on every
    // call afterwards. Rebuilding it and loading the same sources again
    // recovers, and a failure that survives a fresh player is a real failure,
    // reported rather than swallowed.
    var loaded = false;
    for (var attempt = 0; attempt < 2 && !loaded; attempt++) {
      if (attempt == 1) {
        await _recreatePlayer();
        if (token != _continuousToken) return;
      }
      try {
        await _player.stop();
        await _player.setAudioSource(
          ConcatenatingAudioSource(children: buildChildren()),
          initialIndex: 0,
        );
        loaded = true;
      } catch (_) {
        // fall through to the retry, then to the report below
      }
    }
    if (token != _continuousToken) return;
    if (!loaded) {
      await stopContinuous();
      continuousError.value = ContinuousError.loadFailed;
      return;
    }

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

  /// Moves a **running** recitation to [ayah] and carries on reading from
  /// there, keeping the reciter and the whole-mushaf setting the current run
  /// was started with.
  ///
  /// This is what "pick a verse while the recitation is playing" has to do.
  /// Before it existed the only per-ayah control reachable mid-recitation was
  /// the sciences sheet's single-ayah play/stop toggle, which stopped the
  /// shared player and left the recitation stranded — the owner's report that
  /// choosing a verse before or after the one sounding "stops the recitation
  /// and it doesn't play".
  ///
  /// Returns false (and changes nothing) when no recitation is running, so a
  /// caller can fall back to single-ayah playback.
  Future<bool> jumpContinuousTo({
    required Ayah ayah,
    required QuranRepository repo,
  }) async {
    if (!continuous.value.active) return false;
    await startContinuous(
      from: ayah,
      repo: repo,
      edition: _continuousEdition,
      wholeMushaf: _continuousWholeMushaf,
    );
    return true;
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
      return;
    }
    // `play()` on a released platform player returns without doing anything
    // and without throwing — the "I press play and nothing happens" the owner
    // reported after a long spell in the background. When the player says it
    // holds nothing, resume by loading the current verse again rather than
    // asking a dead player to play.
    if (_playerIsIdle) {
      final resumed = await _restartFromCurrentVerse();
      if (resumed) return;
    }
    unawaited(_player.play());
  }

  /// Reloads the recitation at the verse it had reached. Returns false when
  /// there is nothing to restart from (no run, or no repository recorded).
  Future<bool> _restartFromCurrentVerse() async {
    final state = continuous.value;
    final repo = _continuousRepo;
    final surah = state.surahId;
    final ayah = state.ayahNumber;
    if (!state.active || repo == null || surah == null || ayah == null) {
      return false;
    }
    final row = await repo.ayah(surah, ayah);
    if (row == null) return false;
    await startContinuous(
      from: row,
      repo: repo,
      edition: _continuousEdition,
      wholeMushaf: _continuousWholeMushaf,
    );
    return true;
  }

  /// Called when the app comes back to the foreground.
  ///
  /// If the state still claims a recitation is running but the platform player
  /// holds nothing, the run is over as far as Android is concerned. Clearing
  /// it here is what makes the reader's recitation button *start* on the next
  /// press instead of toggling off a run that is not running — which is how
  /// the hang presented: one press appeared to do nothing at all.
  void onAppResumed() {
    if (continuous.value.active && _playerIsIdle) {
      continuous.value = continuous.value.copyWith(stalled: true);
    }
  }

  Future<void> stopContinuous() async {
    if (_continuousToken == 0 && !continuous.value.active) return;
    _continuousToken++;
    _continuousRepo = null;
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
      // Four, not two. Both audio hosts are intermittently slow rather than
      // down: probing them on 2026-09-10 produced a 502 to a burst of HEADs,
      // a 403 to one ranged GET, a 21.5-second stall on everyayah, and 206s
      // to everything a minute later. Two attempts against a host like that
      // is what turns a transient blip into «تعذّر إكمال بعض الآيات» —
      // permanently, because nothing ever comes back for the ayah.
      retries: 4,
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

  /// Every reciter that has at least one file on disk.
  ///
  /// Repair used to run against `selectedReciterProvider` only, so a surah
  /// left half-finished under a reciter he had since switched away from was
  /// invisible to it — and the button reported «لا يوجد ما يُصلَح» while the
  /// storage screen still showed the partial download.
  Future<List<String>> editionsWithFiles() async {
    try {
      final base = await getApplicationDocumentsDirectory();
      final root = Directory(p.join(base.path, 'recitations'));
      if (!root.existsSync()) return const [];
      final out = <String>[];
      for (final e in root.listSync()) {
        if (e is! Directory) continue;
        final hasAny = e
            .listSync()
            .whereType<File>()
            .any((f) => f.path.endsWith('.mp3') && _looksComplete(f));
        if (hasAny) out.add(p.basename(e.path));
      }
      return out;
    } catch (_) {
      return const [];
    }
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
    // A job whose tracking was lost — the process was killed mid-download, or
    // a task update never arrived — stays in `_jobs` for ever, and
    // `isDownloading` then reports true and this loop skips the surah in
    // silence. That is what made the button look like it did nothing:
    // «زر إصلاح التحميل ده حرفيًا مالوش لازمة». Repair is an explicit request
    // to start again, so a stale claim is dropped rather than obeyed.
    for (final s in surahs) {
      final key = _jobKey(edition, s.id);
      final job = _jobs[key];
      if (job != null && job.isStale) {
        _jobs.remove(key);
      }
    }
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

    final displayName = title ?? '${'quran.surah'.tr()} $surah';
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
/// How long a download job may go without a single task update before repair
/// treats its claim on the surah as abandoned.
///
/// Not a timeout on the download — the platform queue owns that. This is only
/// about the in-memory bookkeeping that `isDownloading` reads.
const Duration _staleJobAfter = Duration(minutes: 3);

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

  /// When this job last heard anything at all from the platform queue.
  DateTime _lastHeard = DateTime.now();

  /// Nothing has settled for [_staleJobAfter]. The claim this job holds on
  /// its surah is then treated as abandoned by repair — see
  /// `repairPartialDownloads`.
  bool get isStale => DateTime.now().difference(_lastHeard) > _staleJobAfter;

  void track(String taskId) {
    _outstanding.add(taskId);
    _lastHeard = DateTime.now();
  }

  void settle(_AyahAttempt attempt, {required bool succeeded}) {
    _lastHeard = DateTime.now();
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
