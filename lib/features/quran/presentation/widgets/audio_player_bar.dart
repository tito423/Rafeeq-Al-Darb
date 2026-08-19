import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/audio_service.dart';

class AudioPlayerBar extends ConsumerStatefulWidget {
  final bool isDark;
  final int surahNumber;
  final String surahNameAr;

  const AudioPlayerBar({
    super.key,
    required this.isDark,
    required this.surahNumber,
    required this.surahNameAr,
  });

  @override
  ConsumerState<AudioPlayerBar> createState() => _AudioPlayerBarState();
}

class _AudioPlayerBarState extends ConsumerState<AudioPlayerBar> {
  double? _dragValue;

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  void _showReciterPicker(BuildContext context, String currentId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDark ? AppColors.darkCardBackground : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.record_voice_over_rounded, color: AppColors.accentGold),
                    const SizedBox(width: 10),
                    Text(
                      'اختر القارئ',
                      style: GoogleFonts.amiri(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: widget.isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: kReciters.length,
                    itemBuilder: (context, idx) {
                      final reciter = kReciters[idx];
                      final isSelected = reciter.id == currentId;
                      return ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        tileColor: isSelected
                            ? AppColors.primaryBlue.withValues(alpha: 0.1)
                            : Colors.transparent,
                        leading: CircleAvatar(
                          backgroundColor: isSelected ? AppColors.accentGold : Colors.grey.withValues(alpha: 0.2),
                          child: Icon(
                            Icons.person_rounded,
                            color: isSelected ? AppColors.primaryBlue : Colors.grey,
                          ),
                        ),
                        title: Text(
                          reciter.nameAr,
                          style: GoogleFonts.amiri(
                            fontSize: 16,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                            color: isSelected
                                ? AppColors.accentGold
                                : (widget.isDark ? Colors.white : Colors.black87),
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded, color: AppColors.accentGold)
                            : null,
                        onTap: () {
                          ref.read(selectedReciterProvider.notifier).state = reciter.id;
                          ref.read(audioServiceProvider.notifier).playSurah(
                                surahNumber: widget.surahNumber,
                                reciterId: reciter.id,
                              );
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final audioState = ref.watch(audioServiceProvider);
    final audioService = ref.read(audioServiceProvider.notifier);

    final isActive = audioState.status != AudioStatus.stopped;
    if (!isActive) return const SizedBox.shrink();

    final bg = widget.isDark ? const Color(0xFF1E272E) : Colors.white;
    final textColor = widget.isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface;
    final subtext = widget.isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    final reciter = kReciters.firstWhere(
      (r) => r.id == (audioState.reciterId ?? 'mishary'),
      orElse: () => kReciters.first,
    );

    final currentPos = audioState.position;
    final totalDur = audioState.duration;
    final sliderMax = totalDur.inMilliseconds.toDouble();
    final sliderVal = _dragValue ??
        (sliderMax > 0
            ? currentPos.inMilliseconds.toDouble().clamp(0.0, sliderMax)
            : 0.0);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: widget.isDark ? 0.4 : 0.15),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top row: Reciter avatar + Title + Reciter selector chip + Close
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primaryBlue, AppColors.primaryBlue2],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.headphones_rounded, color: AppColors.accentGold, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.surahNameAr,
                          style: GoogleFonts.scheherazadeNew(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        GestureDetector(
                          onTap: () => _showReciterPicker(context, reciter.id),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                reciter.nameAr,
                                style: GoogleFonts.amiri(fontSize: 12, color: AppColors.accentGold),
                                maxLines: 1,
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_drop_down_rounded, color: AppColors.accentGold, size: 16),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Playback speed pill
                  PopupMenuButton<double>(
                    initialValue: audioState.speed,
                    tooltip: 'سرعة القراءة',
                    onSelected: (spd) => audioService.setSpeed(spd),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${audioState.speed}x',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ),
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 0.75, child: Text('0.75x (بطيء)')),
                      const PopupMenuItem(value: 1.0, child: Text('1.0x (عادي)')),
                      const PopupMenuItem(value: 1.25, child: Text('1.25x (سريع)')),
                      const PopupMenuItem(value: 1.5, child: Text('1.5x (أسرع)')),
                    ],
                  ),
                  const SizedBox(width: 6),
                  // Loop button
                  IconButton(
                    icon: Icon(
                      audioState.isLooping ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                      size: 20,
                      color: audioState.isLooping ? AppColors.accentGold : subtext,
                    ),
                    tooltip: 'تكرار',
                    onPressed: audioService.toggleLoop,
                  ),
                  // Close/Stop button
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 22, color: subtext),
                    tooltip: 'إغلاق المشغل',
                    onPressed: audioService.stop,
                  ),
                ],
              ),

              // Middle: Interactive Progress Slider + Timers
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3.5,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                        activeTrackColor: AppColors.accentGold,
                        inactiveTrackColor: AppColors.primaryBlue.withValues(alpha: 0.15),
                        thumbColor: AppColors.accentGold,
                        overlayColor: AppColors.accentGold.withValues(alpha: 0.2),
                      ),
                      child: Slider(
                        min: 0.0,
                        max: sliderMax > 0 ? sliderMax : 1.0,
                        value: sliderVal,
                        onChanged: (val) {
                          setState(() => _dragValue = val);
                        },
                        onChangeEnd: (val) {
                          audioService.seek(Duration(milliseconds: val.toInt()));
                          setState(() => _dragValue = null);
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(currentPos),
                            style: GoogleFonts.outfit(fontSize: 11, color: subtext),
                          ),
                          Text(
                            _formatDuration(totalDur),
                            style: GoogleFonts.outfit(fontSize: 11, color: subtext),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 6),

              // Bottom row: Rewind 10s, Play/Pause, Forward 10s
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Rewind 10s
                  IconButton(
                    icon: const Icon(Icons.replay_10_rounded, size: 28),
                    color: textColor,
                    tooltip: 'تأخير 10 ثوانٍ',
                    onPressed: () => audioService.seekBackward(const Duration(seconds: 10)),
                  ),
                  const SizedBox(width: 16),

                  // Big Play/Pause
                  GestureDetector(
                    onTap: audioService.togglePlayPause,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primaryBlue, AppColors.primaryBlue2],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryBlue.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: audioState.isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: AppColors.accentGold,
                              ),
                            )
                          : Icon(
                              audioState.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Forward 10s
                  IconButton(
                    icon: const Icon(Icons.forward_10_rounded, size: 28),
                    color: textColor,
                    tooltip: 'تقديم 10 ثوانٍ',
                    onPressed: () => audioService.seekForward(const Duration(seconds: 10)),
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
