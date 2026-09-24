import 'dart:async';

import 'ayah_audio_service.dart';

/// One sound at a time, across the whole app.
///
/// «دور على اي ميزة في التطبيق ممكن تعمل كونفلكت مع اي حاجة تانية واظبطهم»
/// (2026-09-24). Every recitation, the Qur'an audio player and the recorded
/// ruqyahs already share ONE player (`AyahAudioService.player`), so they
/// replace each other by construction. What did not go through it could
/// sound on top of it:
///
///  * the book reader - the phone's TTS engine, or the open Arabic voice on
///    its own native MediaPlayer (`VoicePlayerChannel`, which takes no audio
///    focus). A recitation started while a page was being read, or the
///    reverse, played both at once;
///  * the tasmee' microphone stopped the player but not a running continuous
///    recitation's listeners (the thing `stopContinuous` exists for), and not
///    the book reader.
///
/// (The adhan needs nothing here: its native player takes exclusive audio
/// focus, and just_audio pauses for it.)
///
/// A speaker outside the shared player registers its stop while it talks.
/// The moment the shared player starts playing - any of its many paths -
/// every registered speaker is stopped; and a speaker, when it starts,
/// calls [silenceAll] first. The watch lives here, not inside
/// `AyahAudioService`, which is at its length ceiling.
class AudioExclusive {
  AudioExclusive._();

  static final Set<Future<void> Function()> _speakers = {};
  static StreamSubscription<bool>? _watch;

  static void speakerStarted(Future<void> Function() stop) {
    _speakers.add(stop);
    _watch ??= AyahAudioService.instance.isPlayingStream.listen((playing) {
      if (playing) unawaited(silenceSpeakers());
    });
  }

  static void speakerStopped(Future<void> Function() stop) =>
      _speakers.remove(stop);

  /// Stops every registered speaker. Safe to call when none is talking.
  static Future<void> silenceSpeakers() async {
    final now = [..._speakers];
    _speakers.clear();
    for (final stop in now) {
      try {
        await stop();
      } catch (_) {
        // A speaker that fails to stop is already silent enough to go on.
      }
    }
  }

  /// Everything, before a microphone records or a speaker starts talking:
  /// the shared player's queue, a continuous recitation WITH its listeners,
  /// the Qur'an audio player, and every other speaker.
  static Future<void> silenceAll() async {
    final audio = AyahAudioService.instance;
    await audio.stopQueue();
    await audio.stopContinuous();
    audio.musicOwnsPlayer.value = false;
    await silenceSpeakers();
  }
}
