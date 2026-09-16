import 'dart:async';
import 'dart:math' as math;
// easy_localization re-exports package:intl, whose TextDirection collides
// with the dart:ui enum the caption below needs.
import 'dart:ui' as ui;
import '../../../../core/services/notification_router.dart';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../../app/rafeeq_app.dart';
import '../../../../app/shell/app_shell.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../onboarding/data/onboarding_state.dart';
import '../../../onboarding/presentation/screens/onboarding_screen.dart';
import '../../data/splash_video_provider.dart';
import '../widgets/splash_lattice.dart';

/// The splash beat shown right after the native launch screen hands off to
/// Flutter.
///
/// TWO BEATS: the app's own first splash, then the video.
///
/// P3‑50 had cut the first one — the girih-lattice backdrop with the glowing
/// badge, the name and the tagline — down to a bare app mark. The owner asked
/// for it back, as it was: «رجع الاسبلاش اسكرين الاولى بنفس الاعدادات اللي
/// اتفقنا عليها مسبقا». [SplashLattice] and the staggered badge → name →
/// tagline reveal are restored from that commit unchanged, with one
/// correction kept: the badge draws `app_mark_circle.png`, the emblem already
/// cut to its own circle, not the old `app_mark.png` whose grey plate
/// survived at a `ClipOval`'s tangents and read as a grey rim on his Honor.
///
/// It is held for [_firstSplashHold] — long enough for its own 900 ms
/// stagger to finish and be seen — and the video takes over after that. The
/// video (`assets/branding/splash_intro.mp4`, his own clip with the Gemini
/// watermark removed and its soundtrack back in) plays once, and a tap skips
/// it. Whether its sound is heard is [splashVideoSoundProvider], off until
/// the owner asks for it — see [SplashWordmark] for why the clip was cut and
/// re-captioned.
///
/// P3‑50: the notification/location permission prompts are requested **after**
/// this splash finishes (see [_proceed]), not from `main()` — so they no
/// longer pop over the video on first launch. Location is asked first.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  bool _navigated = false;
  VideoPlayerController? _video;

  /// Drives the backdrop's slow, endless rotation/twinkle/pulse loop.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 20),
  );

  /// The one-shot staggered reveal of badge → name → tagline.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  /// How long the first splash is held before the video is allowed to take
  /// over. The stagger above finishes at 900 ms; this leaves the finished
  /// composition on screen for a beat rather than cutting away the instant
  /// the last word lands.
  static const _firstSplashHold = Duration(milliseconds: 1700);

  /// When this screen started, so the hold is measured from the same instant
  /// however long the video took to decode.
  final DateTime _startedAt = DateTime.now();

  /// What is left of [_firstSplashHold] right now.
  Duration get _holdRemaining {
    final gone = DateTime.now().difference(_startedAt);
    final left = _firstSplashHold - gone;
    return left.isNegative ? Duration.zero : left;
  }

  /// Set when the app was cold-started by tapping a notification. The splash
  /// is then skipped outright — the owner asked for exactly that: «خلي أول
  /// ما أضغط على الإشعار يفتح شاشته مباشرة حتى لو التطبيق كان مقفول وخليه
  /// يعمل إسكيب ساعتها للاسبلاش». A four-second logo animation between a
  /// tap and the thing tapped is the wrong trade every time.
  String? _launchPayload;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The first splash is the app's own screen, drawn immediately: lift the
    // OS one onto it rather than holding it until the video has decoded.
    WidgetsBinding.instance.addPostFrameCallback((_) => _removeNativeSplash());
    _checkNotificationLaunch();
    final firstRun = !ref.read(splashFirstRunProvider);
    final shouldPlayVideo = firstRun ||
        (ref.read(splashVideoEnabledProvider) &&
            splashAwayLongEnough(ref.read(sharedPrefsProvider)));
    final reduceMotion = WidgetsBinding
        .instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    final motionOn = ref.read(motionEffectsProvider) && !reduceMotion;
    if (motionOn) {
      _c.repeat();
      _intro.forward();
    } else {
      // Reduced motion: the composition is still drawn, just already settled.
      _intro.value = 1;
    }
    if (motionOn && shouldPlayVideo) {
      _initVideo();
    } else {
      // No video: the first splash IS the splash. It still gets its full
      // beat, so the app does not flash a half-drawn brand moment on its way
      // past. Reduced-motion users get an instant hand-off.
      _removeNativeSplash();
      Future<void>.delayed(
        motionOn ? _firstSplashHold : Duration.zero,
        _proceed,
      );
    }
  }

  /// Asks the plugin whether a notification tap is what started this process.
  /// If so, hand off immediately instead of running the intro.
  Future<void> _checkNotificationLaunch() async {
    final payload = await NotificationRouter.instance.takeLaunchPayload();
    if (payload == null || !mounted) return;
    _launchPayload = payload;
    _proceed();
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
      // The clip carries its soundtrack again, and whether it is heard is the
      // owner's switch, off by default — see [splashVideoSoundProvider]. Read
      // once, here, rather than watched: a toggle flipped mid-intro must not
      // make the voice start halfway through a sentence.
      await c.setVolume(ref.read(splashVideoSoundProvider) ? 1 : 0);
      await c.setLooping(false);
      if (!mounted) {
        await c.dispose();
        return;
      }
      c.addListener(_onVideoTick);
      // The first splash gets its beat before the video is allowed on screen.
      // Waiting here rather than delaying `_initVideo` means the decode has
      // already happened when the hold ends, so the cut is instant.
      await Future<void>.delayed(_holdRemaining);
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _video = c);
      // The intro is a *foreground* moment. Started while the app is not in
      // front of the reader — a cold start behind the lock screen, or behind
      // the adhan alert, which runs in its own task — it played its ten-second
      // soundtrack with no screen to show for it and nothing to stop it:
      // «اشتغل صوت الاسبلاش في الخلفية ومش عرفت اوقفه». Reproduced on the
      // owner's Honor with the display off: `dumpsys audio` reported this
      // player's own track `state:started` for twelve consecutive seconds
      // while `mWakefulness=Dozing`.
      if (!_isForeground) {
        await _abandonIntro(c);
        return;
      }
      await c.play();
      // Belt-and-braces: `_onVideoTick` should catch the end first, but a
      // decoder that never reports a clean completion must not strand the
      // user on frame one forever.
      Future<void>.delayed(
          c.value.duration + const Duration(seconds: 2), _proceed);
    } catch (_) {
      // Asset missing/undecodable on this device — the first splash is already
      // on screen and stays, for its own beat, then hands off.
      _removeNativeSplash();
      Future<void>.delayed(_holdRemaining + const Duration(milliseconds: 400),
          _proceed);
    }
  }

  /// Whether the app is actually in front of the reader right now.
  ///
  /// Null before the first lifecycle message counts as "not yet": a missed
  /// brand moment costs nothing, and a wrong guess plays music over a prayer.
  bool get _isForeground =>
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  /// End the intro without letting another frame of it be heard, and hand off.
  Future<void> _abandonIntro(VideoPlayerController c) async {
    c.removeListener(_onVideoTick);
    try {
      await c.setVolume(0);
      await c.pause();
    } catch (_) {
      // A controller disposed from under us (a racing lifecycle change) has
      // already stopped, which is all this was for.
    }
    if (mounted && identical(_video, c)) setState(() => _video = null);
    await c.dispose();
    _removeNativeSplash();
    _proceed();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    final c = _video;
    if (c == null) return;
    // Leaving the foreground ends the intro outright rather than pausing it:
    // a ten-second jingle that resumes when the reader comes back is the same
    // surprise, just later.
    _abandonIntro(c);
  }

  void _onVideoTick() {
    final v = _video;
    if (v == null || _navigated) return;
    final value = v.value;
    if (value.duration > Duration.zero &&
        value.position >= value.duration - const Duration(milliseconds: 150)) {
      _proceed();
      return;
    }
    // Repaint ONLY while the wordmark is fading in. This listener fires on
    // every position update; rebuilding the whole splash on each of them for
    // seven seconds would be a waste, and rebuilding on none of them is why
    // the caption never appeared at all the first time.
    final t = _captionT;
    if (t != _caption && mounted) setState(() => _caption = t);
  }

  void _proceed() {
    if (_navigated || !mounted) return;
    // Safety net: if we somehow reach the hand-off with the native splash
    // still up (e.g. a decoder that never painted a frame), lift it now so it
    // can't cover the app.
    _removeNativeSplash();
    _navigated = true;
    ref.read(splashFirstRunProvider.notifier).markDone();
    markAppActiveNow(ref.read(sharedPrefsProvider));
    final done = ref.read(onboardingCompletedProvider);
    final localeCode = context.locale.languageCode;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => done
            ? AppShell(key: ValueKey(localeCode))
            : const OnboardingScreen(),
      ),
    );
    // A notification tap that started the app cold: route it now that there is
    // a navigator to push onto. `_proceed` has already replaced the splash, so
    // the card lands on top of the app rather than on top of the splash.
    final payload = _launchPayload;
    if (payload != null) {
      _launchPayload = null;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => NotificationRouter.route(payload),
      );
    }

    // The startup permission prompts used to fire from here. They do not
    // any more: timed on a fresh install, the dialog landed on top of the
    // ONBOARDING screen while the user was choosing a mushaf, not on the
    // splash. `AppShell` asks for them now — see
    // `AlarmPermissionsService.requestStartupGrants`.
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _c.dispose();
    _intro.dispose();
    _video?.removeListener(_onVideoTick);
    _video?.dispose();
    super.dispose();
  }

  /// The wordmark's fade as the last frame painted it. Updated from the
  /// video's own position by [_onVideoTick].
  double _caption = 0;

  /// How far into its fade the wordmark is, 0 → 1.
  ///
  /// The source clip faded its own text in over its last ~1.5 s and this
  /// reproduces that, driven by the video's real position rather than a timer
  /// that could drift away from it.
  double get _captionT {
    final v = _video;
    if (v == null || !v.value.isInitialized) return 0;
    final total = v.value.duration.inMilliseconds;
    if (total <= 0) return 0;
    final pos = v.value.position.inMilliseconds;
    const fade = 1500;
    final start = total - fade;
    if (pos <= start) return 0;
    return ((pos - start) / fade).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    // Three overlapping windows of the same 900 ms intro: badge leads, the
    // name follows a beat behind it, the tagline trails the name — each a
    // combined fade and gentle upward settle rather than a hard cut-in.
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
        behavior: HitTestBehavior.opaque,
        onTap: videoReady ? _proceed : null,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          child: videoReady
            ? SizedBox.expand(
                key: const ValueKey('video'),
                child: FittedBox(
                  fit: BoxFit.cover,
                  // The wordmark sits INSIDE the video's own coordinate space,
                  // not on the screen: the video is drawn with BoxFit.cover, so
                  // a caption positioned against the screen would drift away
                  // from the icon on every other aspect ratio. In here it is
                  // scaled and cropped with the artwork, exactly as the burnt-in
                  // text was.
                  child: SizedBox(
                    width: video.value.size.width,
                    height: video.value.size.height,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        VideoPlayer(video),
                        Positioned(
                          left: 0,
                          right: 0,
                          top: video.value.size.height * 0.60,
                          child: SplashWordmark(progress: _caption),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : Stack(
                key: const ValueKey('first'),
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

/// «قُرْآنِي رَفِيقُ دَرْبِي» — the wordmark the intro ends on.
///
/// The clip the owner supplied burned these two lines in itself, with the
/// tashkeel wrong on both words of the name («قَرْأَنْي … دُرَبِّي») and «الى»
/// for «إلى» underneath. Pixels cannot be re-pointed: `delogo` over the band
/// left a smeared rectangle where the clouds lost their detail, which is worse
/// than the mistake. So the clip is cut at 7 s — the icon is settled and the
/// band below it is clean sky — and the app draws the line itself, in
/// AmiriQuran, which sets Arabic vowel marks properly.
///
/// Sizes and positions were measured off the original frames: the title band
/// sat at y 787-903 of 1280 and the subtitle at y 930-975, both centred.
class SplashWordmark extends StatelessWidget {
  /// 0 → 1 across the fade.
  final double progress;

  const SplashWordmark({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    if (progress <= 0) return const SizedBox.shrink();
    return Opacity(
      opacity: progress.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, 14 * (1 - progress)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // scaleDown, not a fixed size: the line must never be clipped by
            // a narrower frame, and Amiri's advance width is not something to
            // guess at.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
              'قُرْآنِي رَفِيقُ دَرْبِي',
              textAlign: TextAlign.center,
              textDirection: ui.TextDirection.rtl,
              // NOT AmiriQuran, though it is bundled and sets vowel marks
              // beautifully: it is a QURANIC face, so it draws the final yaa
              // without its dots and floats the marks high above the line —
              // seen on the emulator, «قرآني» came out as «قرآنی» with the
              // damma adrift. The app's own UI face sets modern Arabic.
              style: TextStyle(
                fontSize: 66,
                fontWeight: FontWeight.w700,
                height: 1.45,
                color: AppColors.goldSoft,
                shadows: [
                  Shadow(
                    color: AppColors.gold.withValues(alpha: 0.55),
                    blurRadius: 26,
                  ),
                  const Shadow(color: Colors.black54, blurRadius: 10),
                ],
              ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'رفيق المسلم في رحلته إلى الجنة',
              textAlign: TextAlign.center,
              textDirection: ui.TextDirection.rtl,
              style: const TextStyle(
                fontSize: 30,
                height: 1.5,
                color: Colors.white,
                shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
              ),
            ),
          ],
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
          // `app_mark_circle.png`, NOT `app_mark.png`: the old file is the
          // emblem on a light grey square plate, and under this `ClipOval`
          // the plate survived at the oval's tangents - a grey rim around the
          // badge, seen on the owner's Honor. This one is already cut to the
          // emblem's own circle on transparency.
          child: Image.asset(
            'assets/branding/app_mark_circle.png',
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
