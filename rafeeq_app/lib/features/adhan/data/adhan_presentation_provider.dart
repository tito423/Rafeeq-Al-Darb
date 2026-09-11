import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/rafeeq_app.dart';
import '../../../core/services/download_manager.dart';
import 'adhan_video_catalog.dart';

/// How the full-screen Adhan looks: just the karaoke text on the animated
/// gradient ([audioOnly], the default), or that text over a muted looping
/// mosque video ([video]). The Adhan **sound** is identical either way (P2‑7).
enum AdhanPresentation { audioOnly, video }

/// Read by the adhan screen itself, which runs in its own engine and reads
/// SharedPreferences directly rather than through this provider.
const adhanVideoPlaylistKey = 'adhan_video_playlist_v1';

class AdhanPresentationState {
  final AdhanPresentation mode;

  /// Which [adhanVideoCatalog] clip is selected for [video] mode.
  final String videoId;

  /// Play every downloaded clip one after another, as one film, instead of
  /// looping the chosen one — «الخمس فيديوهات يشتغلوا ورا بعض كأنهم مدمجين».
  final bool playlist;

  const AdhanPresentationState({
    required this.mode,
    required this.videoId,
    this.playlist = false,
  });

  AdhanPresentationState copyWith({
    AdhanPresentation? mode,
    String? videoId,
    bool? playlist,
  }) =>
      AdhanPresentationState(
        mode: mode ?? this.mode,
        videoId: videoId ?? this.videoId,
        playlist: playlist ?? this.playlist,
      );
}

class AdhanPresentationNotifier extends StateNotifier<AdhanPresentationState> {
  AdhanPresentationNotifier(this._prefs)
      : super(AdhanPresentationState(
          mode: (_prefs.getString(_modeKey) == 'video')
              ? AdhanPresentation.video
              : AdhanPresentation.audioOnly,
          // A saved id that is no longer in the catalogue falls back to the
          // default rather than to nothing. Three SD clips were dropped when
          // the owner reported the adhan background looked bad (see
          // `adhan_video_catalog.dart`), and a device that had one of them
          // selected must land on a clip that exists, not on a blank
          // selection whose download button does nothing.
          videoId: _validId(_prefs.getString(_videoKey)),
          playlist: _prefs.getBool(adhanVideoPlaylistKey) ?? false,
        ));

  static String _validId(String? saved) =>
      adhanVideoById(saved) != null ? saved! : adhanVideoCatalog.first.id;

  final SharedPreferences _prefs;
  static const _modeKey = 'adhan_presentation_v1';
  static const _videoKey = 'adhan_video_id_v1';

  Future<void> setMode(AdhanPresentation mode) async {
    state = state.copyWith(mode: mode);
    await _prefs.setString(
        _modeKey, mode == AdhanPresentation.video ? 'video' : 'audio');
  }

  Future<void> setPlaylist(bool value) async {
    state = state.copyWith(playlist: value);
    await _prefs.setBool(adhanVideoPlaylistKey, value);
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
