import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:video_player/video_player.dart';

import '../../../../app/shell/app_shell.dart';
import '../../../../core/services/alarm_permissions_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../onboarding/data/onboarding_state.dart';
import '../../../onboarding/presentation/screens/onboarding_screen.dart';
import '../../data/splash_video_provider.dart';

/// The splash beat shown right after the native launch screen hands off to
/// Flutter.
///
/// P3‑50: simplified at the owner's request to just **icon → video** — the
/// old hand-built girih-lattice / name / tagline "first splash" screen was
/// removed. While the video decodes (and on any device that can't decode it)
/// this shows only the app mark on the app's dark ground, which reads as a
/// seamless continuation of the native launch icon rather than a second,
/// different branded screen. The video itself (`assets/branding/
/// splash_intro.mp4`, the owner's AI-generated intro with the Gemini
/// watermark removed) plays once, and a tap skips it. Whether it plays with
/// sound is a Settings switch (`splashVideoSoundProvider`, default on).
///
/// P3‑50: the notification/location permission prompts are requested **after**
/// this splash finishes (see [_proceed]), not from `main()` — so they no
/// longer pop over the video on first launch. Location is asked first.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _navigated = false;
  VideoPlayerController? _video;

  /// Read once in [initState] rather than watched: the splash lasts one
  /// playthrough, and re-reading it mid-play would let a Settings change from
  /// another isolate mute a video that is already running.
  bool _videoSound = true;

  @override
  void initState() {
    super.initState();
    final firstRun = !ref.read(splashFirstRunProvider);
    final shouldPlayVideo = firstRun || ref.read(splashVideoEnabledProvider);
    final reduceMotion = WidgetsBinding
        .instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    final motionOn = ref.read(motionEffectsProvider) && !reduceMotion;
    _videoSound = ref.read(splashVideoSoundProvider);
    if (motionOn && shouldPlayVideo) {
      _initVideo();
    } else {
      // No video: the native splash already showed the icon; lift it now (the
      // Flutter icon below is identical, so there's no visible swap) and,
      // after a brief beat, hand off. Reduced-motion users get an instant
      // hand-off.
      _removeNativeSplash();
      Future<void>.delayed(
        Duration(milliseconds: motionOn ? 600 : 0),
        _proceed,
      );
    }
  }

  bool _nativeSplashRemoved = false;

  /// Lift the OS-drawn native splash exactly once. Idempotent — called from
  /// every path (video ready, no video, video failed, and as a safety net in
  /// [_proceed]) so the splash can never end up stranded on screen.
  void _removeNativeSplash() {
    if (_nativeSplashRemoved) return;
    _nativeSplashRemoved = true;
    FlutterNativeSplash.remove();
  }

  Future<void> _initVideo() async {
    try {
      final c = VideoPlayerController.asset('assets/branding/splash_intro.mp4');
      await c.initialize();
      // P3-57: the owner's setting — the intro can play silently without
      // losing the visual. Volume, not a skipped video.
      await c.setVolume(_videoSound ? 1.0 : 0.0);
      await c.setLooping(false);
      if (!mounted) {
        await c.dispose();
        return;
      }
      c.addListener(_onVideoTick);
      setState(() => _video = c);
      await c.play();
      // Lift the native splash only once the video's FIRST frame has actually
      // been painted (post-frame), so the OS icon hands straight over to the
      // playing video with no blank frame in between — the seamless transition
      // the owner asked for.
      WidgetsBinding.instance.addPostFrameCallback((_) => _removeNativeSplash());
      // Belt-and-braces: `_onVideoTick` should catch the end first, but a
      // decoder that never reports a clean completion must not strand the
      // user on frame one forever.
      Future<void>.delayed(
          c.value.duration + const Duration(seconds: 2), _proceed);
    } catch (_) {
      // Asset missing/undecodable on this device — lift the native splash onto
      // the (identical) Flutter icon, brief hold, then proceed.
      _removeNativeSplash();
      Future<void>.delayed(const Duration(milliseconds: 1500), _proceed);
    }
  }

  void _onVideoTick() {
    final v = _video;
    if (v == null || _navigated) return;
    final value = v.value;
    if (value.duration > Duration.zero &&
        value.position >= value.duration - const Duration(milliseconds: 150)) {
      _proceed();
    }
  }

  void _proceed() {
    if (_navigated || !mounted) return;
    // Safety net: if we somehow reach the hand-off with the native splash
    // still up (e.g. a decoder that never painted a frame), lift it now so it
    // can't cover the app.
    _removeNativeSplash();
    _navigated = true;
    ref.read(splashFirstRunProvider.notifier).markDone();
    final done = ref.read(onboardingCompletedProvider);
    final localeCode = context.locale.languageCode;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => done
            ? AppShell(key: ValueKey(localeCode))
            : const OnboardingScreen(),
      ),
    );
    // P3‑50: request the startup permissions now that the splash is gone —
    // location first (the owner asked for it to be the first prompt), then
    // notifications + exact alarm. Scheduled on the binding (not this
    // widget's context) so it still fires after this screen is disposed.
    //
    // P3‑57: and only after the hand-off has finished *drawing*. A
    // post-frame callback fires on the very next frame, i.e. one frame into
    // the 300ms `MaterialPageRoute` transition, so the OS permission dialog
    // came up over a splash that was still fading out — which is what the
    // owner saw as the splash "not showing completely". The delay is longer
    // than the transition on purpose; nothing depends on these grants
    // arriving in the first second.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_requestStartupPermissions());
    });
  }

  /// Long enough to outlast the `MaterialPageRoute` transition (300ms) plus
  /// the first real frame of the screen behind it, so no permission dialog
  /// can ever overlap the splash video or its hand-off.
  static const _permissionDelay = Duration(milliseconds: 900);

  Future<void> _requestStartupPermissions() async {
    await Future<void>.delayed(_permissionDelay);
    try {
      final loc = await Geolocator.checkPermission();
      if (loc == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
    } catch (_) {
      // best-effort — prayer times fall back to cache without it
    }
    await AlarmPermissionsService.instance.requestStartupPermissions();
  }

  @override
  void dispose() {
    _video?.removeListener(_onVideoTick);
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = _video;
    final videoReady = video != null && video.value.isInitialized;

    return Scaffold(
      backgroundColor: AppColors.night,
      // No AnimatedSwitcher any more: the icon beat is owned by the native
      // splash (held until the video's first frame is painted), so this either
      // shows the video directly or, as a fallback, the same app mark the
      // native splash showed — a clean cut, not a second animated hand-off.
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: videoReady ? _proceed : null,
        child: videoReady
            ? SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: video.value.size.width,
                    height: video.value.size.height,
                    child: VideoPlayer(video),
                  ),
                ),
              )
            : Center(
                child: SizedBox(
                  width: 148,
                  height: 148,
                  child: ClipOval(
                    child: Image.asset(
                      'assets/branding/app_mark.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
