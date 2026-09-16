import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/splash_video_provider.dart';

/// The intro, on demand.
///
/// «هل فيه امكانية preview للفيديو من جوه التطبيق» — there was not, and the
/// intro is deliberately hard to summon: it plays on a cold start, and only
/// when the app has been away for [splashAwayThreshold]. That rule is right
/// for a launch animation and useless for judging one, which is why this
/// screen exists.
///
/// It draws exactly what the splash draws — the same clip, nothing over it —
/// so what is seen here is what a real cold start shows, not an approximation
/// of it. The only thing added is a mute button, because the sound is the
/// thing most likely to be under judgement; it starts from
/// [splashVideoSoundProvider] and does not write back to it, so listening once
/// is not the same as switching it on.
class SplashPreviewScreen extends ConsumerStatefulWidget {
  const SplashPreviewScreen({super.key});

  @override
  ConsumerState<SplashPreviewScreen> createState() =>
      _SplashPreviewScreenState();
}

class _SplashPreviewScreenState extends ConsumerState<SplashPreviewScreen>
    with WidgetsBindingObserver {
  VideoPlayerController? _video;
  bool _muted = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _muted = !ref.read(splashVideoSoundProvider);
    _init();
  }

  Future<void> _init() async {
    try {
      final c = VideoPlayerController.asset('assets/branding/splash_intro.mp4');
      await c.initialize();
      await c.setVolume(_muted ? 0 : 1);
      await c.setLooping(false);
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _video = c);
      await c.play();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  /// A preview is a foreground thing: leaving the screen with the app must
  /// not leave a voice playing behind it — the same rule the splash follows.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    _video?.pause();
  }

  Future<void> _replay() async {
    final v = _video;
    if (v == null) return;
    await v.seekTo(Duration.zero);
    await v.play();
  }

  Future<void> _toggleMute() async {
    final v = _video;
    setState(() => _muted = !_muted);
    await v?.setVolume(_muted ? 0 : 1);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = _video;
    final ready = v != null && v.value.isInitialized;

    return Scaffold(
      backgroundColor: AppColors.night,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text('settings.splash_preview'.tr()),
        actions: [
          IconButton(
            tooltip: 'settings.splash_video_sound'.tr(),
            icon: Icon(
              _muted ? Icons.volume_off_outlined : Icons.volume_up_outlined,
            ),
            onPressed: ready ? _toggleMute : null,
          ),
          IconButton(
            tooltip: 'settings.splash_preview_play'.tr(),
            icon: const Icon(Icons.replay),
            onPressed: ready ? _replay : null,
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: _failed
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'errors.generic'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            )
          : !ready
              ? const Center(child: CircularProgressIndicator())
              : SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: v.value.size.width,
                      height: v.value.size.height,
                      child: VideoPlayer(v),
                    ),
                  ),
                ),
    );
  }
}
