import 'dart:async';
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
/// watermark removed) plays once, and a tap skips it. It is SILENT - see
/// [_Wordmark] for why the clip was cut and re-captioned.
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
    with WidgetsBindingObserver {
  bool _navigated = false;
  VideoPlayerController? _video;

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
    _checkNotificationLaunch();
    final firstRun = !ref.read(splashFirstRunProvider);
    final shouldPlayVideo = firstRun ||
        (ref.read(splashVideoEnabledProvider) &&
            splashAwayLongEnough(ref.read(sharedPrefsProvider)));
    final reduceMotion = WidgetsBinding
        .instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    final motionOn = ref.read(motionEffectsProvider) && !reduceMotion;
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
      // The intro is SILENT: its own soundtrack said «قرآني» wrongly and
      // the owner's instruction was «خليه يقرا قراني صح او سيل الصوت خالص» —
      // a voice cannot be re-recorded here, so the track was removed from the
      // asset itself. Muted here as well, belt and braces, so a clip with a
      // track could never start speaking unnoticed.
      await c.setVolume(0);
      await c.setLooping(false);
      if (!mounted) {
        await c.dispose();
        return;
      }
      c.addListener(_onVideoTick);
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
    _video?.removeListener(_onVideoTick);
    _video?.dispose();
    super.dispose();
  }

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
    final video = _video;
    final videoReady = video != null && video.value.isInitialized;

    return Scaffold(
      backgroundColor: AppColors.night,
      // No AnimatedSwitcher any more: the icon beat is owned by the native
      // splash (held until the video's first frame is painted), so this either
      // shows the video directly or, as a fallback, the same app mark the
      // native splash showed — a clean cut, not a second animated hand-off.
      //
      // «the same app mark» is now true. It used to clip `app_mark.png` — the
      // emblem on a light grey square plate — with `ClipOval` and `BoxFit
      // .cover`, while the OS drew that same file unmasked. Recorded on the
      // owner's Honor, the boot read as a grey SQUARE, then a smaller circle
      // lower down with a grey rim (the plate surviving at the oval's
      // tangents), then the intro. Both now draw `app_mark_circle.png`, which
      // is already cut to the emblem's own circle on transparency.
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: videoReady ? _proceed : null,
        child: videoReady
            ? SizedBox.expand(
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
                          child: _Wordmark(progress: _captionT),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : Center(
                child: Image.asset(
                  'assets/branding/app_mark_circle.png',
                  // Sized to the circle the OS actually draws, measured from
                  // a screen recording on the owner's Honor rather than
                  // reasoned about: the native mark lands 248 px wide in a
                  // 612-wide capture and this one landed 324 at 240 dp, both
                  // centred to within 3 px, so 240 x 248/324 is 184.
                  width: 184,
                  height: 184,
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
class _Wordmark extends StatelessWidget {
  /// 0 → 1 across the fade.
  final double progress;

  const _Wordmark({required this.progress});

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
            Text(
              'قُرْآنِي رَفِيقُ دَرْبِي',
              textAlign: TextAlign.center,
              textDirection: ui.TextDirection.rtl,
              style: TextStyle(
                fontFamily: 'AmiriQuran',
                fontSize: 74,
                height: 1.5,
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
