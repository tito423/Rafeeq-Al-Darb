import 'dart:async';
import 'dart:io';

// easy_localization re-exports package:intl, whose `TextDirection` collides
// with dart:ui's (used here for the RTL adhan text) — hide it, same fix as
// azkar_section_screen.dart / ayah_sciences_sheet.dart.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart' show MediaItem;
import 'package:video_player/video_player.dart';

import '../../../../core/services/adhan_alarm_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/azan_subtitle.dart';

/// P3‑52 — the full-screen Azan player, rebuilt on the "live overlay"
/// architecture the owner asked for (and the one that doesn't hang the app):
///
///   • a **silent looping video** of the Haram/a mosque as the background
///     (`video_player`, `BoxFit.cover`, muted, looped);
///   • the **adhan audio played in parallel** by `just_audio` (the notification
///     that opened this screen is a silent full-screen-intent trigger — see
///     `AdhanAlarmService._detailsFor`'s `full` case — so there's exactly one
///     audio stream, no fragile video+audio muxing);
///   • the **adhan text as synced subtitles** overlaid on top, driven off the
///     audio player's real `positionStream` so each phrase appears exactly
///     when it's being recited, and adapts to any muezzin's pacing;
///   • opens **over the lock screen** (the notification is fullScreenIntent +
///     max priority; `MainActivity` is `showWhenLocked`/`turnScreenOn`).
///
/// Launched by `openAdhanFromPayload` (a live tap, a cold launch, or the
/// resume-time active-notification fallback).
class AdhanFullScreenScreen extends StatefulWidget {
  final String prayerKey;
  final String prayerLabel;

  /// The exact notification id this adhan fired under — Stop/Mute act on it.
  final int notificationId;

  /// The raw payload string, re-posted as-is when muting.
  final String rawPayload;

  /// Bundled adhan Flutter asset for the chosen muezzin (played via just_audio).
  final String? audioAsset;

  /// On-device file of a custom imported adhan (used when [audioAsset] is null).
  final String? audioFilePath;

  /// Local path of a downloaded background clip; plays muted + looped behind
  /// the text. Null/missing → the animated gradient fallback.
  final String? videoPath;

  const AdhanFullScreenScreen({
    super.key,
    required this.prayerKey,
    required this.prayerLabel,
    required this.notificationId,
    required this.rawPayload,
    this.audioAsset,
    this.audioFilePath,
    this.videoPath,
  });

  @override
  State<AdhanFullScreenScreen> createState() => _AdhanFullScreenScreenState();
}

class _AdhanFullScreenScreenState extends State<AdhanFullScreenScreen>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _audio = AudioPlayer();
  VideoPlayerController? _video;

  late final AnimationController _bgController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat(reverse: true);

  List<AzanSubtitle> _subtitles = const [];
  int _activeIndex = -1;
  bool _muted = false;
  bool _stopped = false;
  String _clockText = _fmtNow();

  Timer? _clock;
  Timer? _fallbackTicker;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<PlayerState>? _stateSub;

  static String _fmtNow() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(n.hour)}:${two(n.minute)}:${two(n.second)}';
  }

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _clockText = _fmtNow());
    });
    _initVideo();
    _initAudio();
  }

  Future<void> _initVideo() async {
    final path = widget.videoPath;
    if (path == null || !File(path).existsSync()) return;
    try {
      final c = VideoPlayerController.file(File(path));
      await c.initialize();
      await c.setVolume(0); // audio comes from the adhan player, not the clip
      await c.setLooping(true);
      await c.play();
      if (mounted) {
        setState(() => _video = c);
      } else {
        await c.dispose();
      }
    } catch (_) {
      // fall back to the animated gradient
    }
  }

  Future<void> _initAudio() async {
    Duration? duration;
    try {
      final tag = MediaItem(id: 'adhan-${widget.prayerKey}', title: widget.prayerLabel);
      if (widget.audioAsset != null) {
        duration = await _audio.setAsset(widget.audioAsset!, tag: tag);
      } else if (widget.audioFilePath != null &&
          File(widget.audioFilePath!).existsSync()) {
        duration = await _audio.setFilePath(widget.audioFilePath!, tag: tag);
      }
    } catch (_) {
      duration = null;
    }

    final total = duration ?? const Duration(minutes: 3);
    _subtitles = buildAzanSubtitles(
      isFajr: widget.prayerKey == 'fajr',
      total: total,
    );
    if (mounted) setState(() {});

    final hasAudio = widget.audioAsset != null ||
        (widget.audioFilePath != null && File(widget.audioFilePath!).existsSync());

    if (hasAudio) {
      _posSub = _audio.positionStream.listen((pos) => _syncTo(pos));
      _stateSub = _audio.playerStateStream.listen((s) {
        if (s.processingState == ProcessingState.completed && !_stopped) {
          _dismiss();
        }
      });
      try {
        await _audio.play();
      } catch (_) {}
    } else {
      // No audio source (shouldn't happen — every option is asset or file):
      // still drive the subtitles across an estimated duration so the screen
      // isn't static, then auto-dismiss at the end.
      final start = DateTime.now();
      _fallbackTicker =
          Timer.periodic(const Duration(milliseconds: 200), (t) {
        final pos = DateTime.now().difference(start);
        _syncTo(pos);
        if (pos >= total && !_stopped) _dismiss();
      });
    }
  }

  void _syncTo(Duration pos) {
    if (!mounted || _stopped) return;
    var idx = -1;
    for (var i = 0; i < _subtitles.length; i++) {
      if (_subtitles[i].contains(pos)) {
        idx = i;
        break;
      }
    }
    // Past the last window (tail of the recording) — keep the final phrase up.
    if (idx == -1 && _subtitles.isNotEmpty && pos >= _subtitles.last.startTime) {
      idx = _subtitles.length - 1;
    }
    if (idx != _activeIndex) setState(() => _activeIndex = idx);
  }

  void _onMute() {
    if (_muted) return;
    setState(() => _muted = true);
    _audio.setVolume(0);
  }

  Future<void> _dismiss() async {
    if (_stopped) return;
    setState(() => _stopped = true);
    try {
      await _audio.stop();
    } catch (_) {}
    // Also clear the triggering notification so it (and any lingering native
    // sound for non-full modes) goes away.
    await AdhanAlarmService.instance.stopById(widget.notificationId);
    if (!mounted) return;
    // A fullScreenIntent launch can deliver more than once; popUntil clears
    // any stacked copies in one go.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  void dispose() {
    _clock?.cancel();
    _fallbackTicker?.cancel();
    _posSub?.cancel();
    _stateSub?.cancel();
    _bgController.dispose();
    _audio.dispose();
    _video?.dispose();
    super.dispose();
  }

  Widget _background() {
    final v = _video;
    if (v != null && v.value.isInitialized) {
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: v.value.size.width,
          height: v.value.size.height,
          child: VideoPlayer(v),
        ),
      );
    }
    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, _) {
        final t = _bgController.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.3 + 0.15 * t),
              radius: 1.3,
              colors: [
                Color.lerp(
                    AppColors.primaryContainer, AppColors.nightSurface, t)!,
                AppColors.night,
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = (_activeIndex >= 0 && _activeIndex < _subtitles.length)
        ? _subtitles[_activeIndex].text
        : '';
    return PopScope(
      canPop: _stopped,
      child: Scaffold(
        backgroundColor: AppColors.night,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 1) The silent looping video (or gradient fallback).
            Positioned.fill(child: _background()),
            // 2) Dark gradient scrim for legibility over the video.
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xCC000000),
                      Color(0x55000000),
                      Color(0xE6000000),
                    ],
                    stops: [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),
            // 3) The content layer.
            SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  children: [
                    // Top: prayer name + live clock.
                    Icon(Icons.mosque, size: 44, color: AppColors.gold),
                    const SizedBox(height: 10),
                    Text(
                      'prayer.azan_of'.tr(args: [widget.prayerLabel]),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textHigh,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _clockText,
                      style: const TextStyle(
                        color: AppColors.goldSoft,
                        fontSize: 18,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const Spacer(),
                    // Middle: the current adhan phrase, big, with a soft
                    // fade+scale transition on change.
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 450),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.92, end: 1.0)
                              .animate(anim),
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
                          'prayer.mute'.tr(),
                          style: const TextStyle(color: AppColors.textMedium),
                        ),
                      ),
                    // Bottom: controls.
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: (_stopped || _muted) ? null : _onMute,
                            icon: Icon(
                                _muted ? Icons.volume_off : Icons.volume_mute),
                            label: Text('prayer.mute'.tr()),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textHigh,
                              side: const BorderSide(color: AppColors.nightBorder),
                              minimumSize: const Size(0, 52),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _dismiss,
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
