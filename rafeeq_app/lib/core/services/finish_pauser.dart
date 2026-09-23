import 'dart:async';

import 'package:just_audio/just_audio.dart';

/// Starts a single ayah or track, and pauses it once it has played to its
/// end.
///
/// just_audio leaves `playing` true after a source completes. With
/// `handleInterruptions` on, anything that takes the audio focus and gives it
/// back - the adhan, a phone call, the tasmee microphone - then makes the
/// player "resume": the last ayah started again from nothing, minutes after
/// it had finished. Seen on emulator-5554 (3.59.0): stopping the adhan
/// preview replayed 2:137. A finished player is paused, so it is not
/// "playing" any more and there is nothing to resume.
///
/// The watch is bound to the source that was loaded when [play] was called.
/// Continuous recitation and the surah player load their own sources and
/// move on at their own ends; the moment the player holds a different
/// source, the watch lets go instead of pausing something it does not own.
class FinishPauser {
  StreamSubscription<PlayerState>? _sub;

  void play(AudioPlayer player) {
    unawaited(player.play());
    final source = player.audioSource;
    _sub?.cancel();
    late final StreamSubscription<PlayerState> sub;
    sub = player.playerStateStream.listen((s) {
      if (!identical(player.audioSource, source)) {
        sub.cancel();
        return;
      }
      if (s.processingState == ProcessingState.completed && s.playing) {
        sub.cancel();
        unawaited(player.pause());
      }
    }, onError: (Object _) {});
    _sub = sub;
  }
}
