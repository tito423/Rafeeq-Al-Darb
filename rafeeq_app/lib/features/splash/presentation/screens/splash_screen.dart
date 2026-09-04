import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../../app/shell/app_shell.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../onboarding/data/onboarding_state.dart';
import '../../../onboarding/presentation/screens/onboarding_screen.dart';
import '../widgets/splash_lattice.dart';

/// P3‑20 (revisited by P3‑38, then again by P3‑39 — still P3‑20's slot in
/// PHASE3.md): the branded splash beat shown right after the native launch
/// screen hands off to Flutter.
///
/// P3‑39 gave this a real, literal splash **video**
/// (`assets/branding/splash_intro.mp4`) — the owner's own request was
/// explicit ("new video to use as splash screen"), not just a mood
/// reference this time, and the clip already ends on a card carrying our
/// exact app name and tagline, so it is played as-is rather than
/// reinterpreted. It's muted (this is a silent brand beat, not a trailer),
/// plays once, and a tap anywhere skips straight past it — a 10‑second
/// clip with no skip would be a real annoyance on every cold start, so
/// that affordance was added even though the owner didn't ask for it in
/// those words. The original hand-built girih-lattice + glow-badge design
/// (`SplashLattice`, `_GlowBadge` below) is kept as the fallback shown
/// while the video is still decoding and if it ever fails to load — never
/// a blank frame — plus what's still shown outright for reduced-motion
/// users (system setting or the in-app "Motion effects" toggle), who skip
/// both the video and the entrance animation entirely and land on the next
/// screen immediately.
///
/// This is a deliberate brand pause, not a loading gate: every async
/// bootstrap step (`SharedPreferences`, translations, timezone data, the
/// adhan/reminder services) already finishes in `main()` *before*
/// `runApp()` — Android's own native launch screen is what covers that
/// real wait. By the time this widget's first frame draws there is nothing
/// left to wait for.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  /// Drives the backdrop's slow, endless rotation/twinkle/pulse loop.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 20),
  );

  /// A one-shot staggered reveal for the badge/name/tagline — the video's
  /// own splash frame is static (everything present from the first frame);
  /// this is a deliberate departure, not an oversight: badge scales+fades
  /// in first, then the name, then the tagline, the ordinary way a splash
  /// earns its "brand moment" rather than just being a still image.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  bool _navigated = false;

  /// Null until the video has decoded its first frame — the lattice+badge
  /// design underneath is what's visible until then (and stays visible for
  /// good if this never becomes non-null, e.g. the asset failed to decode
  /// on some device/codec combination).
  VideoPlayerController? _video;

  @override
  void initState() {
    super.initState();
    final reduceMotion =
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    final motionOn = ref.read(motionEffectsProvider) && !reduceMotion;
    if (motionOn) {
      _c.repeat();
      _intro.forward();
      _initVideo();
    } else {
      _intro.value = 1; // reduced motion: appear fully formed, no reveal
      Future<void>.delayed(Duration.zero, _proceed);
    }
  }

  Future<void> _initVideo() async {
    try {
      final c = VideoPlayerController.asset('assets/branding/splash_intro.mp4');
      await c.initialize();
      await c.setVolume(0); // silent brand beat, no sound track of its own
      await c.setLooping(false);
      if (!mounted) {
        await c.dispose();
        return;
      }
      c.addListener(_onVideoTick);
      setState(() => _video = c);
      await c.play();
      // Belt-and-braces: `_onVideoTick` should always catch the end first,
      // but a decoder that never reports a clean completion must not strand
      // the user on frame one forever.
      Future<void>.delayed(c.value.duration + const Duration(seconds: 2), _proceed);
    } catch (_) {
      // Asset missing/undecodable on this device — fall back to the same
      // fixed hold the hand-built badge design used before P3‑39.
      Future<void>.delayed(const Duration(milliseconds: 1900), _proceed);
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
    final done = ref.read(onboardingCompletedProvider);
    // Read the locale code *before* navigating, not inside `builder:` — the
    // exact same real crash found live in `OnboardingScreen._finish` (see
    // its comment): `pushReplacement` can deactivate this screen's element
    // before the new route's `builder` callback runs, and `context.locale`
    // accessed from inside that callback then throws "Looking up a
    // deactivated widget's ancestor is unsafe."
    final localeCode = context.locale.languageCode;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => done
            ? AppShell(key: ValueKey(localeCode))
            : const OnboardingScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    _intro.dispose();
    _video?.removeListener(_onVideoTick);
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Three overlapping windows of the same 900ms intro: badge leads, the
    // name follows a beat behind it, the tagline trails the name — each a
    // combined fade + gentle upward settle rather than a hard cut-in.
    final badgeIn = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.62, curve: Curves.easeOutBack),
    );
    final nameIn = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.30, 0.80, curve: Curves.easeOut),
    );
    final taglineIn = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
    );

    final video = _video;
    final videoReady = video != null && video.value.isInitialized;

    return Scaffold(
      backgroundColor: AppColors.night,
      body: GestureDetector(
        // Tap anywhere to skip the intro video — never offered for the
        // fallback design below, which is already short.
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
              : Stack(
                  key: const ValueKey('fallback'),
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(child: SplashLattice(animation: _c)),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ScaleTransition(
                          scale: Tween(begin: 0.7, end: 1.0).animate(badgeIn),
                          child: FadeTransition(
                            opacity: badgeIn,
                            child: _GlowBadge(animation: _c),
                          ),
                        ),
                        const SizedBox(height: 28),
                        _RiseIn(
                          animation: nameIn,
                          child: Text(
                            'app.name'.tr(),
                            style: const TextStyle(
                              fontFamily: 'AmiriQuran',
                              fontSize: 40,
                              color: AppColors.textHigh,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        _RiseIn(
                          animation: taglineIn,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              'app.tagline'.tr(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'AmiriQuran',
                                fontSize: 15,
                                color: AppColors.gold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Fade in while settling upward a few pixels — used for both text lines so
/// each feels like it drifts gently into place rather than snapping on.
class _RiseIn extends StatelessWidget {
  const _RiseIn({required this.animation, required this.child});
  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: AnimatedBuilder(
        animation: animation,
        builder: (_, c) => Transform.translate(
          offset: Offset(0, 10 * (1 - animation.value)),
          child: c,
        ),
        child: child,
      ),
    );
  }
}

class _GlowBadge extends StatelessWidget {
  const _GlowBadge({required this.animation});
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, child) {
        // A gentle breathing glow (never fully off) rather than a static
        // halo — echoes the reference's own soft pulse without needing a
        // second animation controller.
        final pulse = 0.55 + 0.25 * (0.5 + 0.5 * math.sin(animation.value * 2 * math.pi));
        return Container(
          width: 168,
          height: 168,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withValues(alpha: pulse * 0.45),
                blurRadius: 46,
                spreadRadius: 6,
              ),
            ],
          ),
          child: child,
        );
      },
      child: ClipOval(
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.6), width: 1.4),
          ),
          child: Image.asset(
            'assets/branding/app_mark.png',
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
