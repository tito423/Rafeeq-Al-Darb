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

/// P3‑20: the branded splash beat shown right after the native launch
/// screen hands off to Flutter — a dark navy field, a slow radial girih
/// lattice, and a glowing gold badge holding **our own crescent+book mark**
/// (not the old app's mosque icon), styled after
/// `design_refs/old_app_frames/frame_01.png` but rebuilt from scratch with
/// this project's own colours/typography (nothing in that frame is
/// QuranFlash-derived — see the warning in PHASE3.md right above P3‑20 —
/// unlike the mushaf-catalog frame a few seconds later in the same video,
/// which this project deliberately does not recreate).
///
/// This is a deliberate brand pause, not a loading gate: every async
/// bootstrap step (`SharedPreferences`, translations, timezone data, the
/// adhan/reminder services) already finishes in `main()` *before*
/// `runApp()` — Android's own native launch screen is what covers that
/// real wait. By the time this widget's first frame draws there is nothing
/// left to wait for, so the only honest reason to hold here at all is the
/// same couple of seconds any app spends on its own logo, and reduced-
/// motion (system setting or the in-app "Motion effects" toggle) skips the
/// hold entirely rather than making the user endure a pointless animation.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 20),
  );
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    final reduceMotion =
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    final motionOn = ref.read(motionEffectsProvider) && !reduceMotion;
    if (motionOn) _c.repeat();
    Future<void>.delayed(
      motionOn ? const Duration(milliseconds: 1400) : Duration.zero,
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.night,
      body: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: SplashLattice(animation: _c)),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _GlowBadge(animation: _c),
              const SizedBox(height: 28),
              Text(
                'app.name'.tr(),
                style: const TextStyle(
                  fontFamily: 'AmiriQuran',
                  fontSize: 40,
                  color: AppColors.textHigh,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 6),
              Padding(
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
            ],
          ),
        ],
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
