import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart' show MediaItem;

import '../../../core/services/ayah_audio_service.dart';
import '../../../core/utils/http_status_probe.dart';
import '../../../core/config/content_mirrors.dart';
import 'surah_fallback.dart';

/// One thing the player can play: a downloaded surah, a streamed one, or a
/// file imported from the device.
class PlayerTrack {
  final String id;
  final String title;
  final String artist;
  final String? album;
  final String? url;
  final String? filePath;

  /// Where [url] is the app's own mirror, the public origin behind it.
  final String? fallbackUrl;

  const PlayerTrack({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    this.url,
    this.filePath,
    this.fallbackUrl,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'url': url,
        'filePath': filePath,
        'fallbackUrl': fallbackUrl,
      };

  factory PlayerTrack.fromJson(Map<String, dynamic> j) => PlayerTrack(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        artist: j['artist'] as String? ?? '',
        album: j['album'] as String?,
        url: j['url'] as String?,
        filePath: j['filePath'] as String?,
        fallbackUrl: j['fallbackUrl'] as String?,
      );

  bool get isLocal =>
      (filePath != null && File(filePath!).existsSync()) ||
      (url?.startsWith('content://') ?? false);

  /// This track from its public origin only (the mirror failed).
  PlayerTrack originOnly() => PlayerTrack(
      id: id, title: title, artist: artist, album: album, url: fallbackUrl);

  AudioSource toSource({bool origin = false}) {
    // Every source needs a MediaItem: `just_audio_background` throws on an
    // untagged one, and it is what the lock screen and the notification show.
    final tag = MediaItem(id: 'qa:$id', title: title, artist: artist, album: album);
    return (filePath != null && File(filePath!).existsSync())
        ? AudioSource.file(filePath!, tag: tag)
        : AudioSource.uri(
            Uri.parse(origin && fallbackUrl != null ? fallbackUrl! : url!),
            tag: tag);
  }
}

enum SleepMode { off, timer, endOfTrack }

enum PlayerNotice { substituted, waiting, failed }

/// The player of «تحميل تلاوات القرآن».
///
/// It drives the app's **one** `AudioPlayer` (see `AyahAudioService.player`)
/// rather than a second one — `just_audio_background` refuses a second live
/// player — and gives it back the moment anything else in the app plays:
/// `musicOwnsPlayer` turns false, this stops listening, and the queue is kept
/// so play picks up where it was.
class QuranAudioPlayer extends ChangeNotifier {
  QuranAudioPlayer._() {
    AyahAudioService.instance.musicOwnsPlayer.addListener(_onOwnership);
  }
  static final QuranAudioPlayer instance = QuranAudioPlayer._();

  static const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  List<PlayerTrack> _queue = const [];
  int _index = 0;
  bool _shuffle = false;
  LoopMode _loop = LoopMode.off;
  double _speed = 1.0;
  SleepMode _sleepMode = SleepMode.off;
  DateTime? _sleepAt;
  Timer? _sleepTimer;
  final List<StreamSubscription<dynamic>> _subs = [];

  AudioPlayer get _player => AyahAudioService.instance.player;

  bool get active =>
      AyahAudioService.instance.musicOwnsPlayer.value && _queue.isNotEmpty;
  List<PlayerTrack> get queue => _queue;
  int get index => _index;
  PlayerTrack? get current =>
      _queue.isEmpty ? null : _queue[_index.clamp(0, _queue.length - 1)];
  bool get shuffle => _shuffle;
  LoopMode get loop => _loop;
  double get speed => _speed;
  SleepMode get sleepMode => _sleepMode;
  DateTime? get sleepAt => _sleepAt;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration> get bufferedStream => _player.bufferedPositionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get stateStream => AyahAudioService.instance.playerState;
  /// just_audio keeps `playing` true after the last track ends; the player
  /// then showed a pause button over a finished queue and the disc kept
  /// turning. A completed queue is not playing.
  bool get playing =>
      active && _player.playing && _player.processingState != ProcessingState.completed;
  ProcessingState get stateNow => _player.processingState;

  Future<bool> playQueue(List<PlayerTrack> tracks, {int start = 0}) async {
    if (tracks.isEmpty) return false;
    final player = await AyahAudioService.instance.claimForMusic();
    _queue = List.unmodifiable(tracks);
    _original = _queue;
    _index = start.clamp(0, tracks.length - 1);
    _substituted.clear();
    _cancelHold();
    _attach(player);
    notifyListeners();
    if (await _startAt(_index)) return true;
    _holdAt(_index);
    // Held, not failed: the reader has been told and it will start by
    // itself. False only when the queue is a single imported file with no
    // backup at all, so the screen can still show the plain failure.
    return waitingIndex != null;
  }

  /// Loads the queue at [i] and plays; when that surah cannot be opened,
  /// walks its backups ([_nextStep]) until something plays or nothing is
  /// left. Every step either spends a URL or the one substitution a surah
  /// is allowed, so the walk always ends.
  Future<bool> _startAt(int i) async {
    final player = _player;
    _loading = true;
    try {
      while (true) {
        try {
          await player.setAudioSources(
            [for (final t in _queue) t.toSource()],
            initialIndex: i,
          );
          _index = i;
          await player.setLoopMode(_loop);
          if (_shuffle) await player.shuffle();
          await player.setShuffleModeEnabled(_shuffle);
          await player.setSpeed(_speed);
          unawaited(player.play());
          lastFailure = null;
          return true;
        } catch (e) {
          // Kept so the snackbar can say WHAT failed if nothing is left.
          final url = _queue[i].url ?? _queue[i].filePath ?? '';
          lastFailure = (url: url, error: e, status: await httpStatusOf(url));
          final next = _nextStep(i, answered: lastFailure?.status != null);
          if (next == null) return false;
          i = next;
        }
      }
    } finally {
      _loading = false;
    }
  }

  /// The next thing to try after surah [i] failed, as a queue index (the
  /// queue may have been rewritten at [i]), or null when nothing is left.
  ///  1. its public origin, if it came from the app's own mirror;
  ///  2. the same surah in another voice ([SurahFallback]), once;
  ///  then nothing more here — the caller HOLDS on this surah ([_holdAt]).
  ///
  /// [answered]: a server replied (404, 403…) — this file is the problem,
  /// and another voice may stand in. No reply means no connection: only a
  /// copy already on the phone can help then, and the rest is waiting.
  int? _nextStep(int i, {required bool answered}) {
    final t = _queue[i];
    PlayerTrack? replacement;
    final mirrors = t.isLocal || t.url == null ? const <String>[] : ContentMirrors.of(t.url!);
    if (mirrors.length > 1) {
      // The app's bucket failed: the same bytes on its GitHub mirror, with
      // the origin still behind them.
      replacement = PlayerTrack(
          id: t.id, title: t.title, artist: t.artist, album: t.album,
          url: mirrors[1], fallbackUrl: t.fallbackUrl);
    } else if (t.fallbackUrl != null && !t.isLocal) {
      replacement = t.originOnly();
    } else if (_substituted.add(t.id)) {
      replacement = SurahFallback.forTrack(t, localOnly: !answered && !t.isLocal);
      if (replacement == null) _substituted.remove(t.id);
      if (replacement != null) {
        onNotice?.call(PlayerNotice.substituted, t.title, replacement.artist);
      }
    }
    if (replacement != null) {
      _queue = List.unmodifiable([..._queue]..[i] = replacement);
      notifyListeners();
      return i;
    }
    // Never on to the next surah: «مفيش حاجة اسمها تخطي». The caller holds.
    return null;
  }

  /// A surah that failed while the queue was already playing — the next one
  /// in «تشغيل الكل» — goes through the same backups as a first tap does.
  Future<void> _recover() async {
    if (_loading || !active) return;
    final failed = _player.currentIndex ?? _index;
    final t = _queue[failed];
    final answered =
        t.isLocal || await httpStatusOf(t.url ?? '') != null;
    final next = _nextStep(failed, answered: answered);
    if (next == null || !await _startAt(next)) _holdAt(failed);
  }

  bool _loading = false;
  final Set<String> _substituted = {};
  List<PlayerTrack> _original = const [];

  /// The surah the player is holding on because nothing answered for it,
  /// or null. It is retried every [_retryAfter] and at once when the
  /// network comes back — the reader's own recitation first.
  int? waitingIndex;
  Timer? _retryTimer;
  StreamSubscription<List<ConnectivityResult>>? _netSub;
  static const _retryAfter = Duration(seconds: 20);

  void _cancelHold() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _netSub?.cancel();
    _netSub = null;
    waitingIndex = null;
  }

  void _holdAt(int i) {
    final t = _queue[i];
    if (!_isSurah(t) && t.isLocal) {
      // An imported file that will not open is not coming back by waiting.
      onNotice?.call(PlayerNotice.failed, t.title, '');
      return;
    }
    _cancelHold();
    waitingIndex = i;
    _index = i;
    onNotice?.call(PlayerNotice.waiting, t.title, '');
    notifyListeners();
    Future<void> retry() async {
      if (waitingIndex != i || _loading) return;
      _cancelHold();
      // Back to what the reader chose, and its backups again from the top.
      _queue = List.unmodifiable([..._queue]..[i] = _original[i]);
      _substituted.remove(_original[i].id);
      notifyListeners();
      if (!await _startAt(i)) _holdAt(i);
    }

    // Periodic: a retry dropped because a load was still running must not
    // be the last one (the same fault held continuous recitation for good).
    _retryTimer = Timer.periodic(_retryAfter, (_) => unawaited(retry()));
    _netSub = Connectivity().onConnectivityChanged.listen((r) {
      if (r.any((c) => c != ConnectivityResult.none)) unawaited(retry());
    });
  }

  static bool _isSurah(PlayerTrack t) => RegExp(r'^m\d+-s\d+$').hasMatch(t.id);

  /// Set once by the app shell to put these in front of the reader: which
  /// voice is standing in, which surah was passed over, or that nothing
  /// could be played. (surah title, voice).
  static void Function(PlayerNotice kind, String surah, String voice)? onNotice;

  /// The last failure of [playQueue], or null after a successful start.
  /// [status] is what the server answers a HEAD for the same file: the
  /// player itself reports only «(0) Source error», whether the file is
  /// missing or the phone is offline.
  ({String url, Object error, int? status})? lastFailure;



  void _attach(AudioPlayer player) {
    for (final s in _subs) {
      s.cancel();
    }
    _subs
      ..clear()
      ..add(player.currentIndexStream.listen((i) {
        if (!active || i == null || i == _index) return;
        _index = i;
        notifyListeners();
      }))
      ..add(player.positionDiscontinuityStream.listen((d) {
        if (_sleepMode != SleepMode.endOfTrack) return;
        if (d.reason != PositionDiscontinuityReason.autoAdvance) return;
        player.pause();
        _sleepMode = SleepMode.off;
        notifyListeners();
      }))
      ..add(player.playerStateStream.listen((_) => notifyListeners()))
      // Once the queue is playing, a bad source arrives on errorStream as a
      // value (just_audio 0.10) — not as an error on any other stream.
      ..add(player.errorStream.listen((_) => unawaited(_recover())));
  }

  void _onOwnership() {
    if (AyahAudioService.instance.musicOwnsPlayer.value) return;
    // Something else is playing now: a held surah must not burst in on it.
    _cancelHold();
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    notifyListeners();
  }

  Future<void> togglePlay() async {
    if (!active) {
      if (_queue.isNotEmpty) await playQueue(_queue, start: _index);
      return;
    }
    if (_player.processingState == ProcessingState.completed) {
      // Play again from the top of the queue.
      await _player.seek(Duration.zero, index: 0);
      unawaited(_player.play());
      return;
    }
    _player.playing ? await _player.pause() : unawaited(_player.play());
  }

  Future<void> next() async {
    if (active && _player.hasNext) await _player.seekToNext();
  }

  /// A few seconds in, "previous" restarts the surah, the way every music
  /// player does; at its start it goes to the one before.
  Future<void> previous() async {
    if (!active) return;
    if (_player.position > const Duration(seconds: 3) || !_player.hasPrevious) {
      await _player.seek(Duration.zero);
    } else {
      await _player.seekToPrevious();
    }
  }

  Future<void> seek(Duration to) async {
    if (active) await _player.seek(to);
  }

  Future<void> skip(Duration by) async {
    if (!active) return;
    var to = _player.position + by;
    final duration = _player.duration;
    if (to < Duration.zero) to = Duration.zero;
    if (duration != null && to > duration) to = duration;
    await _player.seek(to);
  }

  Future<void> jumpTo(int i) async {
    if (!active) {
      await playQueue(_queue, start: i);
      return;
    }
    await _player.seek(Duration.zero, index: i);
    if (!_player.playing) unawaited(_player.play());
  }

  Future<void> toggleShuffle() async {
    _shuffle = !_shuffle;
    notifyListeners();
    if (!active) return;
    if (_shuffle) await _player.shuffle();
    await _player.setShuffleModeEnabled(_shuffle);
  }

  Future<void> cycleLoop() async {
    _loop = switch (_loop) {
      LoopMode.off => LoopMode.all,
      LoopMode.all => LoopMode.one,
      LoopMode.one => LoopMode.off,
    };
    notifyListeners();
    if (active) await _player.setLoopMode(_loop);
  }

  Future<void> setSpeed(double value) async {
    _speed = value;
    notifyListeners();
    if (active) await _player.setSpeed(value);
  }

  void setSleep(SleepMode mode, {Duration? after}) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepMode = mode;
    _sleepAt = null;
    if (mode == SleepMode.timer && after != null) {
      _sleepAt = DateTime.now().add(after);
      _sleepTimer = Timer(after, () {
        if (active) _player.pause();
        _sleepMode = SleepMode.off;
        _sleepAt = null;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  Future<void> stop() async {
    if (active) await _player.stop();
    setSleep(SleepMode.off);
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _queue = const [];
    _index = 0;
    AyahAudioService.instance.musicOwnsPlayer.value = false;
    notifyListeners();
  }
}
