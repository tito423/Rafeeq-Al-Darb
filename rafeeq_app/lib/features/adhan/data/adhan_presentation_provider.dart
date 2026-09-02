import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/rafeeq_app.dart';
import '../../../core/services/download_manager.dart';
import 'adhan_video_catalog.dart';

/// How the full-screen Adhan looks: just the karaoke text on the animated
/// gradient ([audioOnly], the default), or that text over a muted looping
/// mosque video ([video]). The Adhan **sound** is identical either way (P2‑7).
enum AdhanPresentation { audioOnly, video }

class AdhanPresentationState {
  final AdhanPresentation mode;

  /// Which [adhanVideoCatalog] clip is selected for [video] mode.
  final String videoId;

  const AdhanPresentationState({required this.mode, required this.videoId});

  AdhanPresentationState copyWith({AdhanPresentation? mode, String? videoId}) =>
      AdhanPresentationState(
        mode: mode ?? this.mode,
        videoId: videoId ?? this.videoId,
      );
}

class AdhanPresentationNotifier extends StateNotifier<AdhanPresentationState> {
  AdhanPresentationNotifier(this._prefs)
      : super(AdhanPresentationState(
          mode: (_prefs.getString(_modeKey) == 'video')
              ? AdhanPresentation.video
              : AdhanPresentation.audioOnly,
          videoId: _prefs.getString(_videoKey) ?? adhanVideoCatalog.first.id,
        ));

  final SharedPreferences _prefs;
  static const _modeKey = 'adhan_presentation_v1';
  static const _videoKey = 'adhan_video_id_v1';

  Future<void> setMode(AdhanPresentation mode) async {
    state = state.copyWith(mode: mode);
    await _prefs.setString(
        _modeKey, mode == AdhanPresentation.video ? 'video' : 'audio');
  }

  Future<void> setVideo(String videoId) async {
    state = state.copyWith(videoId: videoId);
    await _prefs.setString(_videoKey, videoId);
  }
}

final adhanPresentationProvider = StateNotifierProvider<
    AdhanPresentationNotifier, AdhanPresentationState>((ref) {
  return AdhanPresentationNotifier(ref.watch(sharedPrefsProvider));
});

/// The on-disk path of the selected background clip, or null when the user is
/// on audio-only mode or the chosen clip isn't downloaded yet (in which case
/// the full-screen adhan honestly falls back to the animated gradient).
Future<String?> resolveAdhanVideoPath(AdhanPresentationState state) async {
  if (state.mode != AdhanPresentation.video) return null;
  final opt = adhanVideoById(state.videoId);
  if (opt == null) return null;
  return DownloadManager.instance.registeredPath(opt.downloadId);
}
