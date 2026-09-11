import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart' show MediaItem;

import '../../../core/services/ayah_audio_service.dart';

/// One thing the player can play: a downloaded surah, a streamed one, or a
/// file imported from the device.
class PlayerTrack {
  final String id;
  final String title;
  final String artist;
  final String? album;
  final String? url;
  final String? filePath;

  const PlayerTrack({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    this.url,
    this.filePath,
  });

  bool get isLocal =>
      (filePath != null && File(filePath!).existsSync()) ||
      (url?.startsWith('content://') ?? false);

  AudioSource toSource() {
    // Every source needs a MediaItem: `just_audio_background` throws on an
    // untagged one, and it is what the lock screen and the notification show.
    final tag = MediaItem(id: 'qa:$id', title: title, artist: artist, album: album);
    return (filePath != null && File(filePath!).existsSync())
        ? AudioSource.file(filePath!, tag: tag)
        : AudioSource.uri(Uri.parse(url!), tag: tag);
  }
}

enum SleepMode { off, timer, endOfTrack }

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
  bool get playing => active && _player.playing;
  ProcessingState get stateNow => _player.processingState;

  Future<bool> playQueue(List<PlayerTrack> tracks, {int start = 0}) async {
    if (tracks.isEmpty) return false;
    final player = await AyahAudioService.instance.claimForMusic();
    _queue = List.unmodifiable(tracks);
    _index = start.clamp(0, tracks.length - 1);
    _attach(player);
    notifyListeners();
    try {
      await player.setAudioSource(
        ConcatenatingAudioSource(
          children: [for (final t in tracks) t.toSource()],
        ),
        initialIndex: _index,
      );
      await player.setLoopMode(_loop);
      if (_shuffle) await player.shuffle();
      await player.setShuffleModeEnabled(_shuffle);
      await player.setSpeed(_speed);
      unawaited(player.play());
      return true;
    } catch (_) {
      return false;
    }
  }

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
      ..add(player.playerStateStream.listen((_) => notifyListeners()));
  }

  void _onOwnership() {
    if (AyahAudioService.instance.musicOwnsPlayer.value) return;
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
