import 'package:just_audio/just_audio.dart';

class AdhanPlayerController {
  static final AudioPlayer _player = AudioPlayer();
  static bool _isMuted = false;
  static double _originalVolume = 1.0;

  static AudioPlayer get player => _player;

  static Future<void> pause() async {
    await _player.pause();
  }

  static Future<void> stop() async {
    await _player.stop();
  }

  static Future<void> mute() async {
    if (!_isMuted) {
      _originalVolume = _player.volume;
      await _player.setVolume(0.0);
      _isMuted = true;
    }
  }

  static Future<void> unmute() async {
    if (_isMuted) {
      await _player.setVolume(_originalVolume);
      _isMuted = false;
    }
  }

  static Future<void> setSource(String path) async {
    await _player.setAudioSource(AudioSource.uri(Uri.parse(path)));
  }

  static Future<void> play() async {
    await _player.play();
  }
}