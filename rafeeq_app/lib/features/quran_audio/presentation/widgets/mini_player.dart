import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/quran_audio_player.dart';
import '../player_screen.dart';
import 'audio_common.dart';

/// The bar that follows the recitation around every screen of the section.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = QuranAudioPlayer.instance;
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final track = player.current;
        if (!player.active || track == null) return const SizedBox.shrink();
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: Material(
              color: AppColors.nightSurface,
              elevation: 8,
              shadowColor: Colors.black54,
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => QuranAudioPlayerScreen.open(context),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StreamBuilder<Duration>(
                      stream: player.positionStream,
                      builder: (context, pos) => StreamBuilder<Duration?>(
                        stream: player.durationStream,
                        builder: (context, dur) {
                          final total = dur.data?.inMilliseconds ?? 0;
                          final at = pos.data?.inMilliseconds ?? 0;
                          return LinearProgressIndicator(
                            minHeight: 3,
                            value: total <= 0 ? 0 : (at / total).clamp(0.0, 1.0),
                            color: AppColors.gold,
                            backgroundColor: AppColors.nightBorder,
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
                      child: Row(
                        children: [
                          // «خلي الرمز الأيقوني في كارت المشغل الصغير يبقى
                          // انيمتد بصريًا». Bars that move while the audio
                          // plays and settle when it pauses.
                          Hero(
                            tag: 'quran-audio-art',
                            child: Stack(
                              children: [
                                RecitationCover(
                                  title: track.title,
                                  artist: track.artist,
                                  size: 44,
                                  compact: true,
                                ),
                                Positioned.fill(
                                  child: _EqualizerOverlay(playing: player.playing),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  track.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textHigh,
                                  ),
                                ),
                                Text(
                                  track.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMedium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StreamBuilder<PlayerState>(
                            stream: player.stateStream,
                            builder: (context, _) {
                              final busy = player.playing &&
                                  (player.stateNow == ProcessingState.loading ||
                                      player.stateNow ==
                                          ProcessingState.buffering);
                              return IconButton(
                                iconSize: 34,
                                color: AppColors.gold,
                                onPressed: player.togglePlay,
                                icon: busy
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2.4),
                                      )
                                    : Icon(player.playing
                                        ? Icons.pause_circle_filled_rounded
                                        : Icons.play_circle_fill_rounded),
                              );
                            },
                          ),
                          IconButton(
                            color: AppColors.textMedium,
                            onPressed: player.stop,
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Four gold bars over the cover's lower half, each rising and falling on its
/// own phase while [playing]; they ease down to a low rest when paused, so
/// the stopped state reads as stopped rather than frozen mid-motion.
class _EqualizerOverlay extends StatefulWidget {
  final bool playing;
  const _EqualizerOverlay({required this.playing});

  @override
  State<_EqualizerOverlay> createState() => _EqualizerOverlayState();
}

class _EqualizerOverlayState extends State<_EqualizerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.playing) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant _EqualizerOverlay old) {
    super.didUpdateWidget(old);
    if (widget.playing && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.playing && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            painter: _BarsPainter(t: _c.value, playing: widget.playing),
          ),
        ),
      );
}

class _BarsPainter extends CustomPainter {
  final double t;
  final bool playing;
  const _BarsPainter({required this.t, required this.playing});

  static const _phases = [0.0, 0.35, 0.7, 0.15];

  @override
  void paint(Canvas canvas, Size size) {
    final barW = size.width * 0.1;
    final gap = size.width * 0.06;
    final total = _phases.length * barW + (_phases.length - 1) * gap;
    var x = (size.width - total) / 2;
    final base = size.height * 0.86;
    final paint = Paint()..color = AppColors.gold.withValues(alpha: 0.92);
    // A dark wash behind the bars so they read over any cover.
    canvas.drawRRect(
      RRect.fromLTRBR(x - gap, size.height * 0.38, x + total + gap,
          size.height * 0.92, const Radius.circular(4)),
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );
    for (final phase in _phases) {
      final wave = playing
          ? 0.5 + 0.5 * math.sin(2 * math.pi * (t + phase) * (1 + phase))
          : 0.15;
      final h = size.height * (0.12 + 0.34 * wave);
      canvas.drawRRect(
        RRect.fromLTRBR(x, base - h, x + barW, base, Radius.circular(barW / 2)),
        paint,
      );
      x += barW + gap;
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) => old.t != t || old.playing != playing;
}
