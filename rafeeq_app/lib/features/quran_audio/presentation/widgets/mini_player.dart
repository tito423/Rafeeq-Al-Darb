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
                          Hero(
                            tag: 'quran-audio-art',
                            child: RecitationCover(
                              title: track.title,
                              artist: track.artist,
                              size: 44,
                              compact: true,
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
