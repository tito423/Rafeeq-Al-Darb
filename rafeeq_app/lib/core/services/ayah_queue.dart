part of 'ayah_audio_service.dart';

/// Queue ownership also guards source loading, including fallback voices.
extension _AyahQueue on AyahAudioService {
  bool _queueIsCurrent(int token) => _queueActive && token == _queueToken;

  bool _mayPlayQueue(int? token) => token == null || _queueIsCurrent(token);

  Future<void> _runQueue(
    List<Ayah> ayahs,
    QuranRepository repo, {
    required String edition,
    Duration gap = Duration.zero,
    String Function(Ayah ayah, int index)? titleFor,
    void Function(int index)? onIndex,
  }) async {
    final token = ++_queueToken;
    _queueActive = true;
    await stopContinuous();
    if (!_queueIsCurrent(token)) return;
    for (var i = 0; i < ayahs.length; i++) {
      if (!_queueIsCurrent(token)) return; // superseded by a newer call/stop
      onIndex?.call(i);
      final started = await _playAyah(
        ayahs[i],
        repo,
        edition: edition,
        queueToken: token,
        title: titleFor?.call(ayahs[i], i),
      );
      if (!_queueIsCurrent(token)) return;
      // Nothing played: wait, then THIS verse again — never the next one.
      if (!started && await _waitForSource(token, ayahs[i--])) continue;
      if (!started) break;
      await _waitForCompletionOrToken(token);
      if (!_queueIsCurrent(token)) return;
      if (gap > Duration.zero) await Future<void>.delayed(gap);
    }
    if (_queueIsCurrent(token)) _queueActive = false;
  }

  /// Returns when the ayah has finished — or when it never will.
  ///
  /// It used to wait for `completed` and nothing else, so a player that
  /// errored, was stopped from outside, or was paused by another app or the
  /// tasmee microphone taking the audio focus left the loop waiting for ever
  /// and the button on «إيقاف». Now an `idle` player (stopped or failed), a
  /// playback error, or a pause that lasts [AyahAudioService._stallLimit] all end the wait.
  Future<void> _waitForCompletionOrToken(int token) async {
    final completer = Completer<void>();
    void done() {
      if (!completer.isCompleted) completer.complete();
    }

    Timer? stall;
    late final StreamSubscription<PlayerState> sub;
    sub = _player.playerStateStream.listen((s) {
      if (!_queueIsCurrent(token) ||
          s.processingState == ProcessingState.completed ||
          s.processingState == ProcessingState.idle) {
        done();
        return;
      }
      if (!s.playing) {
        stall ??= Timer(AyahAudioService._stallLimit, done);
      } else {
        stall?.cancel();
        stall = null;
      }
    }, onError: (Object _) => done());
    await completer.future;
    stall?.cancel();
    await sub.cancel();
  }

  Future<bool> _playAyah(
    Ayah ayah,
    QuranRepository repo, {
    String edition = AyahAudioService.defaultEdition,
    String? title,
    int? queueToken,
  }) async {
    if (!_mayPlayQueue(queueToken)) return false;
    musicOwnsPlayer.value = false;
    try {
      final global = await repo.globalAyahNumber(ayah.surahId, ayah.ayahNumber);
      if (!_mayPlayQueue(queueToken)) return false;
      final tag = _tag(edition, global, ayah, title);

      // A single ayah supersedes continuous recitation *properly* — see the
      // history in `stopContinuous`: stopping only the player left a live
      // completion listener that later jumped to a surah nobody asked for.
      if (continuous.value.active) {
        await stopContinuous();
      }

      if (!_mayPlayQueue(queueToken)) return false;
      await _player.stop();
      if (!_mayPlayQueue(queueToken)) return false;

      final urls = RecitationSource.urlsFor(
        edition: edition,
        surah: ayah.surahId,
        ayah: ayah.ayahNumber,
        globalAyah: global,
      );
      for (final url in urls) {
        if (!_mayPlayQueue(queueToken)) return false;
        try {
          await _player
              .setAudioSource(AudioSource.uri(Uri.parse(url), tag: tag))
              .timeout(AyahAudioService._loadLimit);
          if (!_mayPlayQueue(queueToken)) return false;
          _finish.play(_player);
          AudioFailure.instance.clear();
          debugPrint(
            'recitation from ${Uri.parse(url).host}${Uri.parse(url).path}',
          );
          return true;
        } catch (e) {
          if (!_mayPlayQueue(queueToken)) return false;
          AudioFailure.instance.record(url, e); // the last host wins
        }
      }
      debugPrint('nothing played: ${AudioFailure.instance.last.value}');
    } catch (e) {
      if (!_mayPlayQueue(queueToken)) return false;
      AudioFailure.instance.last.value = e.toString();
      debugPrint('AyahAudioService.play failed: $e');
    }
    if (!_mayPlayQueue(queueToken)) return false;
    return edition == AyahAudioService.defaultEdition
        ? false
        : _playBackupVoice(ayah, repo, title, queueToken: queueToken);
  }
}
