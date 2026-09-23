import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart' show MediaItem;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'download_engine.dart';
import 'surah_playlist.dart';

import '../db/models.dart';
import 'continuous_recitation.dart';
export 'continuous_recitation.dart';
import '../db/quran_repository.dart';
import 'audio_failure.dart';
import 'finish_pauser.dart';
import 'recitation_source.dart';

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

  /// The reciter a reader starts on until he picks one — the owner's choice,
  /// changed 2026-09-23 from المنشاوي المجوّد to محمد صديق المنشاوي
  /// **(مرتّل)**: «تمام يبقى اختار المرتل». The same shaykh, at the pace the
  /// app's own uses need — following the highlighted ayah, hifz and tasmee —
  /// with files a third the size (1.67 GB for the mushaf against 4.93), and
  /// the one of the two mirrored on the app's own bucket, so the default
  /// path has R2 in front of everyayah. A reader who CHOSE the mujawwad keeps
  /// it: only an explicit choice is saved, and this is only the fallback.
  static const String defaultEdition = 'ar.minshawi';

  /// Every recitation in the reader streams, and has since 3.17.0: «شيل خيار
  /// تحميل التلاوات على الجهاز ده خالص وخليه دايما من الـ API آية بآية عشان
  /// التطبيق يبقى خفيف». Whole-surah downloads for listening live in
  /// «تحميل تلاوات القرآن» (`QuranAudioLibrary`) and are not tied to a mushaf.
  ///
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

  final _finish = FinishPauser(); // plays; pauses at the end - see its doc
  /// The shared player, for «تحميل تلاوات القرآن»'s player — which has to use
  /// this one rather than its own, see [_player]. Take it through
  /// [claimForMusic] so whatever else was playing is stopped properly first.
  AudioPlayer get player => _player;

  /// True while the Qur'an audio player owns [player]. Every other playback
  /// path clears it, which is how that player knows it has been superseded.
  final ValueNotifier<bool> musicOwnsPlayer = ValueNotifier(false);

  Future<AudioPlayer> claimForMusic() async {
    await stopQueue();
    await stopContinuous();
    musicOwnsPlayer.value = true;
    return _player;
  }

  Stream<PlayerState> get playerState {
    if (!_bridged) _bridgePlayerState();
    return _stateOut.stream;
  }

  /// A plain `Stream<bool>` for UI code that only cares whether *something*
  /// is playing right now (e.g. the ayah card's single play/stop toggle) —
  /// keeps `package:just_audio`'s `PlayerState` type out of widget files that
  /// don't otherwise need it.
  Stream<bool> get isPlayingStream => playerState
      // just_audio keeps `playing` true once a source has played to its end,
      // so «تلاوة الآية» stayed on «إيقاف» after the verse finished:
      // «زرار تلاوة الآية يتبدل لما الآية تخلص تلاوة».
      .map((s) => s.playing && s.processingState != ProcessingState.completed)
      .distinct();

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
  /// [edition] is REQUIRED on purpose. It used to default to
  /// [defaultEdition], and the memorisation loop took that default while the
  /// rest of the app passed `selectedReciterProvider` - so every repeat came
  /// out in al-Minshawi's voice whoever the reader had chosen.
  Future<void> playQueue(
    List<Ayah> ayahs,
    QuranRepository repo, {
    required String edition,
    Duration gap = Duration.zero,
    String Function(Ayah ayah, int index)? titleFor,
    void Function(int index)? onIndex,
  }) async {
    await stopContinuous();
    final token = ++_queueToken;
    for (var i = 0; i < ayahs.length; i++) {
      if (token != _queueToken) return; // superseded by a newer call/stop
      onIndex?.call(i);
      final started = await play(
        ayahs[i],
        repo,
        edition: edition,
        title: titleFor?.call(ayahs[i], i),
      );
      // Nothing could be loaded: waiting for it to "complete" would wait for
      // ever, and «استمع» would stay «إيقاف» (the owner's al-Baqarah 3,
      // 2026-09-23).
      if (!started) break;
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
    required String edition,
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

  /// Returns when the ayah has finished — or when it never will.
  ///
  /// It used to wait for `completed` and nothing else, so a player that
  /// errored, was stopped from outside, or was paused by another app or the
  /// tasmee microphone taking the audio focus left the loop waiting for ever
  /// and the button on «إيقاف». Now an `idle` player (stopped or failed), a
  /// playback error, or a pause that lasts [_stallLimit] all end the wait.
  Future<void> _waitForCompletionOrToken(int token) async {
    final completer = Completer<void>();
    void done() {
      if (!completer.isCompleted) completer.complete();
    }

    Timer? stall;
    late final StreamSubscription<PlayerState> sub;
    sub = _player.playerStateStream.listen((s) {
      if (token != _queueToken ||
          s.processingState == ProcessingState.completed ||
          s.processingState == ProcessingState.idle) {
        done();
        return;
      }
      if (!s.playing) {
        stall ??= Timer(_stallLimit, done);
      } else {
        stall?.cancel();
        stall = null;
      }
    }, onError: (Object _) => done());
    await completer.future;
    stall?.cancel();
    await sub.cancel();
  }

  static const _stallLimit = Duration(seconds: 20);

  /// How long one source may take to load before the next host is tried.
  /// `setAudioSource` on a host that accepts the connection and then sends
  /// nothing does not throw; it waits.
  static const _loadLimit = Duration(seconds: 20);

  /// Cancels any in-flight `playQueue`/`playRepeated` loop and stops audio.
  Future<void> stopQueue() async {
    _queueToken = 0;
    await stop();
  }

  /// Every audio source must carry a [MediaItem] tag: `main()` initialises
  /// `just_audio_background`, which throws on any untagged source.
  MediaItem _tag(String edition, int global, Ayah ayah, String? title) =>
      MediaItem(
        id: '$edition:$global',
        album: 'app.name'.tr(),
        title: title ?? '${ayah.surahId}:${ayah.ayahNumber}',
      );

  // ── Single-ayah playback ────────────────────────────────────────────────

  /// Plays one ayah — from the device when it is downloaded, otherwise from
  /// the network, trying each host in turn. True when playback started.
  Future<bool> play(
    Ayah ayah,
    QuranRepository repo, {
    String edition = defaultEdition,
    String? title,
  }) async {
    musicOwnsPlayer.value = false;
    try {
      final global = await repo.globalAyahNumber(ayah.surahId, ayah.ayahNumber);
      final tag = _tag(edition, global, ayah, title);

      // A single ayah supersedes continuous recitation *properly* — see the
      // history in `stopContinuous`: stopping only the player left a live
      // completion listener that later jumped to a surah nobody asked for.
      if (continuous.value.active) {
        await stopContinuous();
      }

      await _player.stop();

      final urls = RecitationSource.urlsFor(
        edition: edition,
        surah: ayah.surahId,
        ayah: ayah.ayahNumber,
        globalAyah: global,
      );
      for (final url in urls) {
        try {
          await _player
              .setAudioSource(AudioSource.uri(Uri.parse(url), tag: tag))
              .timeout(_loadLimit);
          _finish.play(_player);
          AudioFailure.instance.clear();
          debugPrint('recitation from ${Uri.parse(url).host}${Uri.parse(url).path}');
          return true;
        } catch (e) {
          AudioFailure.instance.record(url, e); // the last host wins
        }
      }
      debugPrint('nothing played: ${AudioFailure.instance.last.value}');
    } catch (e) {
      AudioFailure.instance.last.value = e.toString();
      debugPrint('AyahAudioService.play failed: $e');
    }
    return false;
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
    musicOwnsPlayer.value = false;
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
      _finish.play(_player);
      return true;
    } catch (e) {
      debugPrint('playTrack failed for $id: $e');
      return false;
    }
  }

  /// Whether the player is currently on [id]'s track. Used by a list of
  /// recordings to show the stop button on the right row and only that row.
  bool isTrack(String id) =>
      (_player.sequenceState.currentSource?.tag as MediaItem?)?.id ==
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

  /// The surah whose verses are loaded in the player right now.
  int? _loadedSurahId;

  /// The reciter of the running recitation.
  String get continuousEdition => _continuousEdition;

  /// Moves a running recitation to another reciter, at the verse it had
  /// reached. Does nothing when no recitation is running.
  Future<void> switchReciter(String edition) async {
    final state = continuous.value;
    final repo = _continuousRepo;
    if (!state.active || repo == null) return;
    if (state.surahId == null || state.ayahNumber == null) return;
    if (edition == _continuousEdition) return;
    final row = await repo.ayah(state.surahId!, state.ayahNumber!);
    if (row == null) return;
    await startContinuous(
      from: row,
      repo: repo,
      edition: edition,
      wholeMushaf: _continuousWholeMushaf,
    );
  }

  /// Starts continuous recitation from [from], reading to the end of its
  /// surah and — when [wholeMushaf] is true — straight on into the next one.
  Future<void> startContinuous({
    required Ayah from,
    required QuranRepository repo,
    String edition = defaultEdition,
    bool wholeMushaf = true,
  }) async {
    _queueToken = 0; // supersede any repeat-loop/playlist run
    musicOwnsPlayer.value = false;

    // «لو التلاوة شغّالة وأنا رجعت لآيات في الخلف أو اخترت سورة تانية ينتقل
    // بسرعة». The surah being read is already in the player as one playlist of
    // all its verses, so moving to another verse of it is a seek — no
    // playlist rebuilt, no first-verse round trip to the host. Only a different
    // surah, reciter or a dead player loads again.
    final current = continuous.value;
    if (current.active &&
        !current.stalled &&
        edition == _continuousEdition &&
        wholeMushaf == _continuousWholeMushaf &&
        from.surahId == _loadedSurahId &&
        !_playerIsIdle) {
      final i = _continuousAyahs.indexWhere((a) => a.ayahNumber == from.ayahNumber);
      if (i >= 0) {
        try {
          await _player.seek(Duration.zero, index: i);
          if (!_player.playing) unawaited(_player.play());
          return;
        } catch (_) {
          // fall through to a full load
        }
      }
    }

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

    // The WHOLE surah (a jump back is a seek), basmala first: `SurahPlaylist`.
    final plan = SurahPlaylist.plan(all, surahId, startAyahNumber);
    final ayahs = _continuousAyahs = plan.ayahs;
    final firstGlobal = await repo.globalAyahNumber(surahId, 1);
    if (token != _continuousToken) return;

    // Built fresh on each attempt below: an `AudioSource` is bound to the
    // player it was given to, so the retry after [_recreatePlayer] must not
    // reuse the objects the disposed player already saw. [host] picks which
    // of the reciter's hosts every verse comes from — 0 is everyayah where it
    // mirrors the reciter, the last is islamic.network's CDN.
    List<AudioSource> buildChildren({int host = 0}) => [
          for (var k = 0; k < ayahs.length; k++)
            () {
              final a = ayahs[k];
              final global = firstGlobal + (a.ayahNumber - 1);
              final isBasmala = plan.isBasmalaAt(k);
              final urls = RecitationSource.urlsFor(
                edition: _continuousEdition,
                surah: isBasmala ? 1 : a.surahId,
                ayah: isBasmala ? 1 : a.ayahNumber,
                globalAyah: isBasmala ? 1 : global,
              );
              return AudioSource.uri(
                Uri.parse(urls[host.clamp(0, urls.length - 1)]),
                tag: _tag(_continuousEdition, global, a, null),
              );
            }(),
        ];

    await _cancelContinuousSubs();
    if (token != _continuousToken) return;

    // Three attempts. The second is on a **new** player: the common cause of
    // a throw is not a bad source but a platform player Android released
    // while the app sat in the background. The third asks the reciter's other
    // host for every verse, so one host refusing is not the end of the
    // recitation.
    var loaded = false;
    for (var attempt = 0; attempt < 3 && !loaded; attempt++) {
      if (attempt == 1) {
        await _recreatePlayer();
        if (token != _continuousToken) return;
      }
      try {
        await _player.stop();
        // just_audio 0.10: a playlist is a list of sources handed to the
        // player, not a ConcatenatingAudioSource (deprecated).
        await _player
            .setAudioSources(
              buildChildren(host: attempt == 2 ? 1 : 0),
              initialIndex: plan.initialIndex,
            )
            .timeout(_loadLimit);
        loaded = true;
      } catch (e) {
        // Retry, then report — but keep the reason, so the message can name
        // the host rather than only that something went wrong.
        AudioFailure.instance.recordContinuous(
            _continuousEdition, ayahs.first, firstGlobal, attempt, e);
      }
    }
    if (token != _continuousToken) return;
    if (loaded) AudioFailure.instance.clear();
    if (loaded) _loadedSurahId = surahId;
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
      final lead = plan.lead;
      continuous.value = ContinuousRecitation(
        active: true,
        surahId: a.surahId,
        ayahNumber: a.ayahNumber,
        basmala: plan.isBasmalaAt(index),
        indexInSurah: (index - lead).clamp(0, _continuousAyahs.length),
        totalInSurah: _continuousAyahs.length - lead,
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
    _loadedSurahId = null;
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

  // ── The per-ayah downloads that were removed ────────────────────────────

  static const _kLegacyPurgedKey = 'recitation.legacy_ayah_files_purged_v1';

  /// Deletes, once, the per-ayah files earlier builds downloaded, and cancels
  /// whatever of those downloads the platform still held.
  ///
  /// The option is gone and nothing reads those files any more, so leaving
  /// them would be hundreds of megabytes the app can neither use nor show —
  /// the emulator carried 280 MB of them. Everything under
  /// `documents/recitations/` was written by that feature and nothing else.
  Future<int> purgeLegacyAyahFiles() async {
    var freed = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kLegacyPurgedKey) ?? false) return 0;
      await DownloadEngine.purgeLegacyRecitationTasks();
      final base = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(base.path, 'recitations'));
      if (dir.existsSync()) {
        for (final f in dir.listSync(recursive: true)) {
          if (f is File) freed += f.lengthSync();
        }
        await dir.delete(recursive: true);
      }
      await prefs.setBool(_kLegacyPurgedKey, true);
    } catch (_) {
      // Tried again on the next launch.
    }
    return freed;
  }

  /// Test/teardown hook — the singleton normally lives for the app session.
  Future<void> dispose() async {
    await _cancelContinuousSubs();
    await _player.dispose();
  }
}
