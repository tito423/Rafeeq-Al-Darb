import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart' show MediaItem;
import 'package:video_player/video_player.dart';

import '../../../../core/services/adhan_alarm_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/adhan_text.dart';

/// The full-screen Adhan view — launched over the lock screen by Android's
/// `fullScreenIntent` (mode [AdhanMode.full]), or by tapping the ordinary
/// notification for any mode. The actual Adhan **sound** is already playing
/// natively (see `adhan_alarm_service.dart`); this screen does not start a
/// second playback. It shows the Adhan text karaoke-style, timed against the
/// real duration of that recording, and gives Stop/Mute controls that act on
/// the same notification the Stop/Mute notification actions do.
class AdhanFullScreenScreen extends StatefulWidget {
  final String prayerKey;
  final String prayerLabel;

  /// The exact notification id this Adhan is firing under (a real daily
  /// alarm or a QA [AdhanAlarmService.scheduleTest] one) — Stop/Mute act on
  /// this id specifically, never a recomputed guess.
  final int notificationId;

  /// The raw payload string this screen was opened with — re-posted as-is
  /// when muting, so the still-ongoing silenced notification can reopen this
  /// same screen if tapped again.
  final String rawPayload;

  /// Asset path of the recording actually playing, used only to read its
  /// real [Duration] for pacing the karaoke — never played again here. Null
  /// for a custom adhan (no bundled asset to probe); a reasonable estimated
  /// duration is used instead, honestly, since we cannot read it without a
  /// second decode of a file we don't control the format of ahead of time.
  final String? previewAsset;

  /// P2‑7 — local path of a downloaded, licence-clean mosque clip. When set
  /// (and the file exists), it plays **muted + looped** behind the karaoke
  /// text instead of the animated gradient. The adhan **sound** is unchanged
  /// (still played natively by `adhan_alarm_service.dart`). Null / missing
  /// file → the gradient, honestly.
  final String? videoPath;

  const AdhanFullScreenScreen({
    super.key,
    required this.prayerKey,
    required this.prayerLabel,
    required this.notificationId,
    required this.rawPayload,
    this.previewAsset,
    this.videoPath,
  });

  @override
  State<AdhanFullScreenScreen> createState() => _AdhanFullScreenScreenState();
}

class _AdhanFullScreenScreenState extends State<AdhanFullScreenScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bgController;
  late final List<AdhanLine> _lines;
  late final List<Duration> _lineStarts;
  Duration _totalDuration = const Duration(minutes: 3);
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  bool _muted = false;
  bool _stopped = false;

  VideoPlayerController? _video;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    _lines = adhanLines(isFajr: widget.prayerKey == 'fajr');
    _lineStarts = [];
    _initVideo();
    _probeDurationThenStart();
  }

  Future<void> _initVideo() async {
    final path = widget.videoPath;
    if (path == null || !File(path).existsSync()) return;
    try {
      final c = VideoPlayerController.file(File(path));
      await c.initialize();
      await c.setVolume(0); // sound comes from the adhan recording, not this
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

  Future<void> _probeDurationThenStart() async {
    final asset = widget.previewAsset;
    if (asset != null) {
      final probe = AudioPlayer();
      try {
        // `main()` initialises just_audio_background, which requires every
        // audio source — even one only probed for its Duration, never
        // played — to carry a MediaItem tag (see ayah_audio_service.dart).
        final d = await probe.setAsset(
          asset,
          tag: MediaItem(id: 'adhan-probe', title: widget.prayerLabel),
        );
        if (d != null && d > Duration.zero) _totalDuration = d;
      } catch (_) {
        // keep the fallback estimate
      } finally {
        await probe.dispose();
      }
    }
    _computeLineStarts();
    _startTicker();
  }

  void _computeLineStarts() {
    final weights = _lines.map((l) => l.text.length * l.repeat).toList();
    final totalWeight = weights.fold<int>(0, (a, b) => a + b);
    var acc = 0;
    for (final w in weights) {
      final ms = totalWeight == 0
          ? 0
          : (_totalDuration.inMilliseconds * acc / totalWeight).round();
      _lineStarts.add(Duration(milliseconds: ms));
      acc += w;
    }
  }

  void _startTicker() {
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted || _muted || _stopped) return;
      setState(() => _elapsed += const Duration(milliseconds: 200));
    });
  }

  int get _activeLine {
    var idx = 0;
    for (var i = 0; i < _lineStarts.length; i++) {
      if (_elapsed >= _lineStarts[i]) idx = i;
    }
    return idx;
  }

  Future<void> _onStop() async {
    setState(() => _stopped = true);
    _ticker?.cancel();
    await AdhanAlarmService.instance.stopById(widget.notificationId);
    if (!mounted) return;
    // A fullScreenIntent launch over the lock screen can deliver its
    // notification-response more than once (observed on the emulator: one
    // extra `onNewIntent` shortly after the screen wakes), stacking a second
    // copy of this same route on top of the first. A plain pop would only
    // close one of them, leaving the alert looking stuck. Clearing back to
    // the app's root — like a real alarm app returning to its dashboard —
    // closes every stacked copy in one tap, however many there are.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// One-way, like a real alarm's mute — there is no native "un-mute" once
  /// the loud notification has been replaced by the silent one.
  Future<void> _onMute() async {
    if (_muted) return;
    setState(() => _muted = true);
    await AdhanAlarmService.instance.muteById(
      widget.notificationId,
      widget.rawPayload,
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _bgController.dispose();
    _video?.dispose();
    super.dispose();
  }

  /// Background layer: the muted looping mosque clip when ready, else the
  /// original animated gradient. A dark scrim goes on top for text contrast.
  Widget _background() {
    final v = _video;
    if (v != null && v.value.isInitialized) {
      return Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: v.value.size.width,
              height: v.value.size.height,
              child: VideoPlayer(v),
            ),
          ),
          // top + bottom scrim so the prayer name / karaoke text stays legible
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xCC000000), Color(0x55000000), Color(0xDD000000)],
                stops: [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ],
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
    final showFajrPhrase =
        widget.prayerKey == 'fajr' && _lineStarts.isNotEmpty;
    return PopScope(
      // Blocks the back gesture/button so the alert can't be swiped away
      // without addressing it — but must allow the pop the Stop button
      // itself performs once pressed, or Stop would visibly do nothing.
      canPop: _stopped,
      child: Scaffold(
        backgroundColor: AppColors.night,
        body: Stack(
          children: [
            Positioned.fill(child: _background()),
            SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Icon(Icons.mosque, size: 56, color: AppColors.gold),
                  const SizedBox(height: 12),
                  Text(
                    'prayer.alarm_for'.tr(),
                    style: const TextStyle(color: AppColors.textMedium, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.prayerLabel,
                    style: const TextStyle(
                      color: AppColors.textHigh,
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (showFajrPhrase)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'prayer.fajr_phrase'.tr(),
                        style: const TextStyle(color: AppColors.goldSoft, fontSize: 16),
                      ),
                    ),
                  const Spacer(),
                  ..._lines.asMap().entries.map((entry) {
                    final i = entry.key;
                    final line = entry.value;
                    final active = i == _activeLine && !_stopped;
                    return AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 250),
                      style: TextStyle(
                        fontFamily: 'AmiriQuran',
                        fontSize: active ? 30 : 20,
                        color: active ? AppColors.gold : AppColors.textLow,
                        fontWeight: active ? FontWeight.bold : FontWeight.normal,
                        height: 1.8,
                      ),
                      child: Text(line.text, textAlign: TextAlign.center),
                    );
                  }),
                  const Spacer(),
                  if (_muted)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'prayer.mute'.tr(),
                        style: const TextStyle(color: AppColors.textMedium),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: (_stopped || _muted) ? null : _onMute,
                          icon: Icon(_muted ? Icons.volume_off : Icons.volume_mute),
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
                          onPressed: _onStop,
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
