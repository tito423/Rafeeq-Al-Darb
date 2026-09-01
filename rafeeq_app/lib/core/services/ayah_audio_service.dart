import 'dart:async';

import 'package:just_audio/just_audio.dart';

import '../config/app_config.dart';
import '../db/models.dart';
import '../db/quran_repository.dart';

/// Streams a single ayah from the real islamic.network audio CDN
/// (e.g. cdn.islamic.network/quran/audio/128/ar.alafasy/`<globalAyah>`.mp3).
class AyahAudioService {
  AyahAudioService._();
  static final AyahAudioService instance = AyahAudioService._();

  final AudioPlayer _player = AudioPlayer();
  bool get isPlaying => _player.playing;

  /// Plays [ayah]. [editionIdentifier] is e.g. "ar.alafasy" (from the real
  /// audio_editions catalog). Falls back to the 64kbps variant when needed.
  Future<void> play(Ayah ayah, QuranRepository repo,
      {String editionIdentifier = 'ar.alafasy'}) async {
    try {
      final global = await repo.globalAyahNumber(ayah.surahId, ayah.ayahNumber);
      await _player.stop();
      for (final url in AppConfig.ayahAudioUrls(editionIdentifier, global)) {
        try {
          await _player.setUrl(url);
          unawaited(_player.play());
          return;
        } catch (_) {
          // try next variant
        }
      }
    } catch (_) {
      // ignore — the UI shows a snackbar via the caller when playback fails
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
  }
}