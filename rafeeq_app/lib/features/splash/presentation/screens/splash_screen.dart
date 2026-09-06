import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:video_player/video_player.dart';

import '../../../../app/shell/app_shell.dart';
import '../../../../core/services/adhan_alarm_service.dart';
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
/// watermark removed) plays with sound, once, and a tap skips it.
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

  @override
  void initState() {
    super.initState();
    final firstRun = !ref.read(splashFirstRunProvider);
    final shouldPlayVideo = firstRun || ref.read(splashVideoEnabledProvider);
    final reduceMotion = WidgetsBinding
        .instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    final motionOn = ref.read(motionEffectsProvider) && !reduceMotion;
    if (motionOn && shouldPlayVideo) {
      _initVideo();
    } else {
      // No video: a brief icon beat, then straight on. Reduced-motion users
      // get an effectively instant hand-off.
      Future<void>.delayed(
        Duration(milliseconds: motionOn ? 600 : 0),
        _proceed,
      );
    }
  }

  Future<void> _initVideo() async {
    try {
      final c = VideoPlayerController.asset('assets/branding/splash_intro.mp4');
      await c.initialize();
      await c.setVolume(1.0);
      await c.setLooping(false);
      if (!mounted) {
        await c.dispose();
        return;
      }
      c.addListener(_onVideoTick);
      setState(() => _video = c);
      await c.play();
      // Belt-and-braces: `_onVideoTick` should catch the end first, but a
      // decoder that never reports a clean completion must not strand the
      // user on frame one forever.
      Future<void>.delayed(
          c.value.duration + const Duration(seconds: 2), _proceed);
    } catch (_) {
      // Asset missing/undecodable on this device — brief icon hold, proceed.
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestStartupPermissions();
    });
  }

  Future<void> _requestStartupPermissions() async {
    try {
      final loc = await Geolocator.checkPermission();
      if (loc == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
    } catch (_) {
      // best-effort — prayer times fall back to cache without it
    }
    await AdhanAlarmService.instance.requestStartupPermissions();
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
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: videoReady ? _proceed : null,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          child: videoReady
              ? SizedBox.expand(
                  key: const ValueKey('video'),
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
                  key: const ValueKey('icon'),
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
      ),
    );
  }
}
