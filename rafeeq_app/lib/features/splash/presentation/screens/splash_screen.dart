import 'dart:async';
import 'dart:ui' show ImageFilter;
import '../../../../core/services/notification_router.dart';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../../app/rafeeq_app.dart';
import '../../../../app/shell/app_shell.dart';
import '../../../onboarding/data/onboarding_state.dart';
import '../../data/splash_video_provider.dart';
import '../../../onboarding/presentation/screens/permissions_intro_screen.dart';

/// The colour the OS paints at launch, and the colour of the intro's first
/// frame — `#2B516B`, the clip's own median pixel. Kept beside the native
/// splash configuration in `pubspec.yaml`; change one and change the other.
const splashGround = Color(0xFF2B516B);


/// The splash beat shown right after the native launch screen hands off to
/// Flutter.
///
/// P3‑50: simplified at the owner's request to just **icon → video** — the
/// old hand-built girih-lattice / name / tagline "first splash" screen was
/// removed. While the video decodes (and on any device that can't decode it)
/// this shows only the app mark on the app's dark ground, which reads as a
/// seamless continuation of the native launch icon rather than a second,
/// different branded screen. The video itself (`assets/branding/
/// splash_intro.mp4`) plays once, and a tap skips it. Whether its sound is
/// heard is [splashVideoSoundProvider], off until the owner asks for it.
///
/// WHICH CLIP. «اقصد الاسبلاش اللي فيها رعد وبرق وسحب وفيها فيديو رفيق الدرب
/// اللي جيمناي عمله قبل اللي خذفناها» — the earlier of his two Gemini clips,
/// kept in `design_refs/gemini_splash_video/source.mp4`: the storm, the badge
/// rising out of the cloud, and its own burnt-in «رَفِيقُ الدَّرْبِ». It runs
/// its full 10.01 s and needs nothing drawn over it, because unlike the
/// second clip its Arabic is set correctly. The Gemini sparkle at
/// 577-622 x 1136-1184 was removed with `delogo`, checked at 1.0 s, 5.0 s and
/// 9.5 s.
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
    // THE SPLASH IS NOT THE RGB BACKDROP.
    //
    // This read `motionEffectsProvider` - «تشغيل الخلفية المتحركة في ثيم
    // RGB» - so a reader who turned the RGB theme's moving gradient off
    // silently lost the splash clip as well, and got `splashGround`
    // (0xFF2B516B) and nothing else: «الاسبلاش اسكرين راحت خالص ومش شغال
    // وبدالها شاشة زرقا صامتة». Two unrelated settings on one switch. The
    // clip answers to its own setting, `splashVideoEnabledProvider`, and to
    // the system's reduce-motion, which is the only other thing entitled to
    // silence it.
    final reduceMotion = WidgetsBinding
        .instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    final wantsVideo = ref.read(splashVideoEnabledProvider);
    final shouldPlayVideo = wantsVideo &&
        (firstRun || splashAwayLongEnough(ref.read(sharedPrefsProvider)));
    final motionOn = !reduceMotion;
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
      return;
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
        // FIRST RUN: splash -> every permission, explained on one page ->
        // onboarding. «كلها ورا بعضها مباشرة» rather than a system dialog
        // landing on top of whatever the reader had started doing.
        builder: (_) => done
            ? AppShell(key: ValueKey(localeCode))
            : const PermissionsIntroScreen(),
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

  @override
  Widget build(BuildContext context) {
    final video = _video;
    final videoReady = video != null && video.value.isInitialized;

    return Scaffold(
      // The same colour the OS just painted — see the native splash block in
      // `pubspec.yaml`. The window, this screen and the clip's first frame are
      // one colour, so nothing flashes between them.
      backgroundColor: splashGround,
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
            // NOTHING is drawn over the clip any more. It carries its own
            // wordmark, and this one is set correctly — «رَفِيقُ الدَّرْبِ»
            // over «رفيق المسلم في رحلته إلى الجنة», with «إلى» spelled
            // properly. The caption the app used to paint existed only
            // because the OTHER clip burned in the wrong tashkeel.
            ? _WholeClip(
                size: video.value.size,
                child: VideoPlayer(video),
              )
            // THE CLIP'S OWN FIRST FRAME while it decodes — not the app mark,
            // and not a flat colour either.
            //
            // The mark is gone because the boot used to show a badge twice at
            // two different sizes: the OS's and then the app's. Measured on a
            // release build here, what replaced it was about three seconds of
            // flat colour before the video appeared — honest, but empty. A
            // still of frame one fills that with the storm the clip opens on,
            // so the video does not start: it *moves*.
            : const _WholeClip(
                size: _clipSize,
                child: Image(
                  image: _firstFrame,
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                ),
              ),
      ),
    );
  }
}

const _firstFrame = AssetImage('assets/branding/splash_first_frame.jpg');

/// `splash_intro.mp4` and its first frame are both 720x1280 (measured).
const _clipSize = Size(720, 1280);

/// The intro is a portrait clip; the screen is whatever the owner holds.
///
/// `BoxFit.cover` alone was right for a phone upright and wrong for every
/// other shape: recorded on the owner's Xiaomi held sideways (2026-09-26),
/// cover scaled the clip to the screen's WIDTH and cut the emblem's top and
/// the whole wordmark away. The same happens on a portrait tablet (3:4 is
/// wider than 9:16).
///
/// So when the screen is wider than the clip, the clip is shown whole at the
/// screen's height, and the band either side is the clip's own storm - the
/// first frame, covering, blurred and dimmed so it reads as ground rather than
/// as a second copy of the picture. On an upright phone (narrower than the
/// clip) nothing changes: cover trims a sliver of sky at the sides, as before.
class _WholeClip extends StatelessWidget {
  const _WholeClip({required this.size, required this.child});

  final Size size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final media = SizedBox(
        width: size.width,
        height: size.height,
        child: child,
      );
      final wider = box.maxWidth / box.maxHeight > size.width / size.height;
      if (!wider) {
        return SizedBox.expand(
          child: FittedBox(fit: BoxFit.cover, child: media),
        );
      }
      return Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: const Image(
              image: _firstFrame,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          ),
          const ColoredBox(color: Color(0x59000000)),
          FittedBox(fit: BoxFit.contain, child: media),
        ],
      );
    });
  }
}
