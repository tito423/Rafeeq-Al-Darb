import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/shell/app_shell.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../onboarding/data/onboarding_state.dart';
import '../../../onboarding/presentation/screens/onboarding_screen.dart';
import '../widgets/splash_lattice.dart';

/// P3‑20 (later revisited, still P3‑20's slot in PHASE3.md): the branded
/// splash beat shown right after the native launch screen hands off to
/// Flutter — a dark navy field, a slow radial girih lattice, and a glowing
/// gold badge holding **our own crescent+book mark** (not the old app's
/// mosque icon). **Inspired by** the reference video's own splash frame
/// (`design_refs/old_app_frames/frame_01.png`), deliberately not a
/// reproduction of it — nothing in that frame is QuranFlash-derived (see
/// the warning in PHASE3.md right above P3‑20, unlike the mushaf-catalog
/// frame a few seconds later in the same video, which this project
/// deliberately does not recreate), but the video's own frame is one flat,
/// static image; this adds three things of its own instead of just
/// matching it: a second lattice layer counter-rotating against the first
/// (`SplashLattice`), a huge, soft echo of the app's own icon-crescent
/// silhouette breathing in the backdrop, and a staggered fade/scale/rise
/// entrance for the badge, name, and tagline instead of everything simply
/// being present in frame one.
///
/// This is a deliberate brand pause, not a loading gate: every async
/// bootstrap step (`SharedPreferences`, translations, timezone data, the
/// adhan/reminder services) already finishes in `main()` *before*
/// `runApp()` — Android's own native launch screen is what covers that
/// real wait. By the time this widget's first frame draws there is nothing
/// left to wait for, so the only honest reason to hold here at all is the
/// same couple of seconds any app spends on its own logo (long enough now
/// to let the staggered entrance actually play out and settle), and
/// reduced-motion (system setting or the in-app "Motion effects" toggle)
/// skips the hold *and* the entrance entirely — everything just appears
/// fully formed — rather than making the user endure a pointless
/// animation.
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

  @override
  void initState() {
    super.initState();
    final reduceMotion =
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    final motionOn = ref.read(motionEffectsProvider) && !reduceMotion;
    if (motionOn) {
      _c.repeat();
      _intro.forward();
    } else {
      _intro.value = 1; // reduced motion: appear fully formed, no reveal
    }
    Future<void>.delayed(
      motionOn ? const Duration(milliseconds: 1900) : Duration.zero,
      _proceed,
    );
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

    return Scaffold(
      backgroundColor: AppColors.night,
      body: Stack(
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
