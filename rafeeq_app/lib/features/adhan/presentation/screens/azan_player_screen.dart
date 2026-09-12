import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;

// easy_localization re-exports package:intl, whose `TextDirection` collides
// with dart:ui's (used here for the RTL adhan text) — hide it, same fix as
// azkar_section_screen.dart / ayah_sciences_sheet.dart.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../core/services/adhan_native.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/adhan_presentation_provider.dart' show adhanVideoPlaylistKey;
import '../../data/adhan_video_catalog.dart';
import '../../data/azan_subtitle.dart';
import '../widgets/adhan_scene.dart';

/// The prayer's name in the app's *current* language.
///
/// [AdhanSpec.prayerLabel] is baked in when the alarm is scheduled — it used
/// to be a hardcoded Arabic table, so this line read "Adhan de الظهر" on a
/// French UI. Even localised at schedule time it goes stale the moment the
/// language changes before the alarm fires, and the key does not, so the name
/// is resolved here. The baked label stays as the fallback for a spec whose
/// key this build does not know.
String _prayerName(AdhanSpec spec) {
  const known = {'fajr', 'dhuhr', 'asr', 'maghrib', 'isha'};
  return known.contains(spec.prayerKey)
      ? 'prayer.${spec.prayerKey}'.tr()
      : spec.prayerLabel;
}

/// Why this screen is on: a real prayer alarm, or the settings preview.
///
/// The two differ in exactly two places — who starts the sound, and what
/// "إيقاف" does afterwards — so they share one widget instead of the two
/// near-copies this module used to carry.
enum AzanPlayerMode {
  /// Hosted by `AdhanActivity`, over the lock screen. `AdhanService` is
  /// already playing the adhan before the first Flutter frame is drawn.
  /// Stopping tears down the service and closes the whole Activity.
  live,

  /// Pushed by the Adhan settings screen. This screen starts the sound
  /// itself, and stopping simply pops back to the settings it came from —
  /// never to the prayer tab, which is where the old preview dumped the user.
  preview,
}

/// The full-screen Azan player: a silent looping video, the adhan audio, and
/// the adhan text as subtitles synced to the audio's real position.
///
/// The audio is played **natively** ([AdhanNative]) in both modes. See that
/// class for why it is not `just_audio`; the short version is that
/// `just_audio_background` allows exactly one player per process and the
/// Quran recitation player already owns it, which is what left this screen
/// mute.
class AzanPlayerScreen extends StatefulWidget {
  /// Everything about this adhan: prayer, mode, which sound, which clip.
  final AdhanSpec spec;

  final AzanPlayerMode playerMode;

  const AzanPlayerScreen({
    super.key,
    required this.spec,
    required this.playerMode,
  });

  @override
  State<AzanPlayerScreen> createState() => _AzanPlayerScreenState();
}

/// 200 ms polls, so ~3 seconds of "the native player never started".
const int _silentPollLimit = 15;

class _AzanPlayerScreenState extends State<AzanPlayerScreen>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _video;

  late final AnimationController _bgController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat(reverse: true);

  List<AzanSubtitle> _subtitles = const [];
  int _activeIndex = -1;
  bool _muted = false;
  bool _closing = false;

  /// Set once the native player reported a real duration, so the subtitle
  /// timeline is laid out against the actual recording rather than a guess.
  Duration? _knownDuration;

  /// Only used when there is genuinely no sound (vibrate/silent mode, or a
  /// sound file that could not be opened) — the text still moves, driven by
  /// wall-clock time, instead of freezing on one phrase.
  DateTime? _silentStart;

  /// Guards the auto-dismiss below: the screen may well be up a tick or two
  /// before the native player reports itself as playing, and dismissing on
  /// that first "not playing yet" would close the adhan the instant it opened.
  bool _sawPlaying = false;

  /// Polls elapsed with no sound at all — after this the screen falls back to
  /// a wall-clock timeline rather than freezing on the first phrase.
  int _silentPolls = 0;

  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _initVideo();
    _start();
  }

  /// The clips to show, in order. One clip loops, as before; with the
  /// playlist switch on, every downloaded clip plays once and the list starts
  /// over. They all sit in the downloads folder under their catalogue names,
  /// so the adhan's own engine can find them without the download registry.
  List<String> _clips = const [];
  int _clipIndex = 0;

  /// The clip fading in over the current one; see [_advanceClip].
  VideoPlayerController? _incoming;
  bool _switching = false;

  Future<List<String>> _playlist(String first) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(adhanVideoPlaylistKey) ?? false)) return [first];
      final dir = File(first).parent.path;
      final all = [
        for (final v in adhanVideoCatalog)
          if (File(p.join(dir, v.fileName)).existsSync()) p.join(dir, v.fileName),
      ];
      final at = all.indexOf(first);
      if (all.length < 2 || at < 0) return [first];
      return [...all.sublist(at), ...all.sublist(0, at)];
    } catch (_) {
      return [first];
    }
  }

  Future<VideoPlayerController?> _open(String path) async {
    try {
      final c = VideoPlayerController.file(File(path));
      await c.initialize();
      await c.setVolume(0); // the adhan is the audio; the clip is scenery
      return c;
    } catch (_) {
      return null;
    }
  }

  Future<void> _initVideo() async {
    final path = widget.spec.videoPath;
    if (path == null || !File(path).existsSync()) return;
    _clips = await _playlist(path);
    final c = await _open(_clips.first);
    if (c == null) return; // gradient fallback — never take the adhan down
    if (_clips.length == 1) {
      await c.setLooping(true);
    } else {
      c.addListener(_watchClipEnd);
    }
    await c.play();
    if (mounted) {
      setState(() => _video = c);
    } else {
      await c.dispose();
    }
  }

  /// A clip is about to end: start the next one underneath and fade it in
  /// over the last ~400 ms, so there is no black frame and no visible cut.
  void _watchClipEnd() {
    final v = _video;
    if (v == null || _switching || !mounted) return;
    final value = v.value;
    if (!value.isInitialized || value.duration == Duration.zero) return;
    if (value.position < value.duration - const Duration(milliseconds: 450)) {
      return;
    }
    _advanceClip();
  }

  Future<void> _advanceClip() async {
    _switching = true;
    final nextIndex = (_clipIndex + 1) % _clips.length;
    final next = await _open(_clips[nextIndex]);
    if (!mounted) {
      await next?.dispose();
      return;
    }
    if (next == null) {
      // An unplayable clip: skip it rather than freezing on the last frame.
      _clipIndex = nextIndex;
      await _video?.seekTo(Duration.zero);
      await _video?.play();
      _switching = false;
      return;
    }
    next.addListener(_watchClipEnd);
    await next.play();
    if (!mounted) {
      await next.dispose();
      return;
    }
    setState(() => _incoming = next);
    _clipIndex = nextIndex;
  }

  void _finishSwitch() {
    final old = _video;
    final next = _incoming;
    if (next == null) return;
    old?.removeListener(_watchClipEnd);
    setState(() {
      _video = next;
      _incoming = null;
    });
    _switching = false;
    old?.dispose();
  }

  Widget _clipView(VideoPlayerController v) => FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: v.value.size.width,
          height: v.value.size.height,
          child: VideoPlayer(v),
        ),
      );

  Future<void> _start() async {
    var sounding = true;
    if (widget.playerMode == AzanPlayerMode.preview) {
      // The live path is already playing (AdhanService started the sound
      // before this Activity was even created); only the preview starts it.
      sounding = await AdhanNative.preview(widget.spec);
    }
    await _loadTimings();
    if (!mounted) return;

    // Lay the text out over a sensible estimate immediately, then re-lay it
    // the moment the native player reports its real duration.
    _rebuildSubtitles(_timings == null
        ? const Duration(minutes: 3)
        : Duration(milliseconds: _timings!.totalMs));
    if (!sounding) _silentStart = DateTime.now();

    _poll = Timer.periodic(const Duration(milliseconds: 200), (_) => _tick());
  }

  Future<void> _tick() async {
    if (!mounted || _closing) return;
    final silentStart = _silentStart;
    if (silentStart != null) {
      final elapsed = DateTime.now().difference(silentStart);
      _syncTo(elapsed);
      if (_subtitles.isNotEmpty && elapsed >= _subtitles.last.endTime) {
        _dismiss();
      }
      return;
    }

    final state = await AdhanNative.state();
    if (!mounted || _closing) return;

    if (state.duration > Duration.zero && state.duration != _knownDuration) {
      _knownDuration = state.duration;
      _rebuildSubtitles(state.duration);
    }
    if (state.muted != _muted) setState(() => _muted = state.muted);
    _syncTo(state.position);

    if (state.playing) {
      _sawPlaying = true;
      _silentPolls = 0;
    } else if (_sawPlaying) {
      // The recording finished (or something else stopped it) — leave exactly
      // the way the Stop button does, so the screen never outlives the adhan.
      _dismiss();
    } else if (++_silentPolls > _silentPollLimit) {
      // Never started at all: a raw resource that is missing, or a custom
      // file the user deleted. Rather than sit on a frozen first phrase,
      // run the text on wall-clock time and end honestly.
      _silentStart = DateTime.now();
    }
  }

  /// This recording's measured speech, when it is one of the bundled ones.
  AdhanTimings? _timings;

  Future<void> _loadTimings() async {
    final asset = widget.spec.assetPath;
    if (asset == null) return;
    try {
      final raw = await rootBundle.loadString('assets/data/catalogs/adhan_phrase_timings.json');
      final all = jsonDecode(raw) as Map<String, dynamic>;
      final entry = all[p.basename(asset)] as Map<String, dynamic>?;
      if (entry != null) _timings = AdhanTimings.fromJson(entry);
    } catch (_) {}
  }

  void _rebuildSubtitles(Duration total) {
    final isFajr = widget.spec.prayerKey == 'fajr';
    final timings = _timings;
    setState(() {
      _subtitles = timings == null
          ? buildAzanSubtitles(isFajr: isFajr, total: total)
          : buildAzanSubtitlesMeasured(isFajr: isFajr, total: total, timings: timings);
    });
  }

  void _syncTo(Duration pos) {
    if (!mounted || _closing) return;
    var idx = -1;
    for (var i = 0; i < _subtitles.length; i++) {
      if (_subtitles[i].contains(pos)) {
        idx = i;
        break;
      }
    }
    // Past the last window (the tail of the recording) — keep the final
    // phrase up rather than blanking the screen.
    if (idx == -1 && _subtitles.isNotEmpty && pos >= _subtitles.last.startTime) {
      idx = _subtitles.length - 1;
    }
    if (idx != _activeIndex) setState(() => _activeIndex = idx);
  }

  Future<void> _onMute() async {
    if (_muted) return;
    setState(() => _muted = true);
    await AdhanNative.mute();
  }

  /// "إيقاف" — and also where a finished recording lands.
  ///
  /// This is the fix for the preview's worst behaviour: it used to
  /// `popUntil((route) => route.isFirst)`, which unwound the navigator all
  /// the way back to the app shell and left the user staring at the prayer
  /// tab. A preview now pops exactly one route, back to the Adhan settings
  /// screen it was opened from; a real alarm closes its own Activity, which
  /// returns the user to the lock screen or whatever app they were in.
  Future<void> _dismiss() async {
    if (_closing) return;
    setState(() => _closing = true);
    _poll?.cancel();
    await AdhanNative.stop();
    if (!mounted) return;
    if (widget.playerMode == AzanPlayerMode.preview) {
      Navigator.of(context).pop();
    } else {
      await AdhanNative.closeAlertScreen();
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    WakelockPlus.disable();
    _bgController.dispose();
    _video?.dispose();
    _incoming?.dispose();
    super.dispose();
  }

  Widget _background() {
    final v = _video;
    if (v != null && v.value.isInitialized) {
      // RepaintBoundary isolates the decoding video surface from the rest of
      // the tree so nothing above it forces the frame to repaint.
      final incoming = _incoming;
      return RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _clipView(v),
            if (incoming != null)
              TweenAnimationBuilder<double>(
                key: ValueKey(incoming),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 400),
                onEnd: _finishSwitch,
                builder: (context, t, child) =>
                    Opacity(opacity: t, child: child),
                child: _clipView(incoming),
              ),
          ],
        ),
      );
    }
    // No clip — which is every audio-only adhan, and every full-screen one
    // whose clip has not been downloaded yet. This used to be a two-colour
    // radial gradient breathing in and out; it is now the painted scene.
    //
    // «يبقى أذان بخلفية إسلامية متحركة وجميلة، حاجة كده كرييتيف من عندك».
    // See `AdhanScene` for why a painted scene and not a clip. `_activeIndex`
    // is the phrase the muezzin is on *right now*, taken from the recording's
    // own measured onsets — the same number the subtitle line uses — so the
    // ring of sound leaves the minaret exactly when he begins the line.
    return AdhanScene(
      prayerKey: widget.spec.prayerKey,
      phraseIndex: _activeIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = (_activeIndex >= 0 && _activeIndex < _subtitles.length)
        ? _subtitles[_activeIndex].text
        : '';
    return PopScope(
      // Back is a real dismissal, not an escape hatch that leaves the adhan
      // playing behind an invisible screen.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _dismiss();
      },
      child: Scaffold(
        backgroundColor: AppColors.night,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 1) The silent looping clip (or the gradient fallback).
            Positioned.fill(child: _background()),
            // 2) Dark scrim, so the text stays legible over any clip.
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  // Lightened once the background became a painted scene
                  // rather than someone's 640×360 clip. The old scrim was
                  // built to make white text survive *any* footage — 0xCC at
                  // the top — and on `AdhanScene` it crushed the sky flat and
                  // turned the sun into a brown smear behind the title. Seen
                  // on emulator-5554; the scene is drawn dark enough at the
                  // top to carry the text on its own, so the scrim only has
                  // to protect the two rows that actually sit on the bright
                  // part: the header and the buttons.
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x8A000000),
                      Color(0x1F000000),
                      Color(0x00000000),
                      Color(0xCC000000),
                    ],
                    stops: [0.0, 0.22, 0.55, 1.0],
                  ),
                ),
              ),
            ),
            // 3) The content layer.
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Column(
                  children: [
                    const Icon(Icons.mosque, size: 44, color: AppColors.gold),
                    const SizedBox(height: 10),
                    Text(
                      'prayer.azan_of'.tr(args: [_prayerName(widget.spec)]),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textHigh,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const _LiveClock(),
                    if (widget.playerMode == AzanPlayerMode.preview) ...[
                      const SizedBox(height: 8),
                      const _PreviewBadge(),
                    ],
                    const Spacer(),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 450),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: ScaleTransition(
                          scale: Tween<double>(
                            begin: 0.92,
                            end: 1.0,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: Text(
                        current,
                        key: ValueKey(current),
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          fontFamily: 'AmiriQuran',
                          fontSize: 40,
                          height: 1.6,
                          fontWeight: FontWeight.bold,
                          color: AppColors.gold,
                          shadows: [
                            Shadow(blurRadius: 18, color: Color(0xFF000000)),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (_muted)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'prayer.muted_now'.tr(),
                          style: const TextStyle(color: AppColors.textMedium),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: (_closing || _muted) ? null : _onMute,
                            icon: Icon(
                              _muted ? Icons.volume_off : Icons.volume_mute,
                            ),
                            label: Text('prayer.mute'.tr()),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textHigh,
                              side: const BorderSide(
                                color: AppColors.nightBorder,
                              ),
                              minimumSize: const Size(0, 52),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _closing ? null : _dismiss,
                            icon: const Icon(Icons.stop_circle_outlined),
                            label: Text('prayer.stop'.tr()),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.error,
                              minimumSize: const Size(0, 52),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Makes it unmistakable that this is the "تجربة" run and not a real prayer
/// call — the screen is otherwise pixel-identical to the real thing, which
/// is the point.
class _PreviewBadge extends StatelessWidget {
  const _PreviewBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
      ),
      child: Text(
        'prayer.preview_badge'.tr(),
        style: const TextStyle(color: AppColors.gold, fontSize: 12),
      ),
    );
  }
}

/// A live HH:mm:ss clock that owns its own 1-second timer and rebuilds *only
/// itself*, so the per-second tick never repaints the video/subtitle Stack
/// above it.
class _LiveClock extends StatefulWidget {
  const _LiveClock();

  @override
  State<_LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<_LiveClock> {
  late Timer _timer;
  String _text = _fmt();

  static String _fmt() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(n.hour)}:${two(n.minute)}:${two(n.second)}';
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _text = _fmt());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _text,
      style: const TextStyle(
        color: AppColors.goldSoft,
        fontSize: 18,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
  }
}
