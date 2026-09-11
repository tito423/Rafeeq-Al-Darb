import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/byte_formatter.dart';
import '../data/quran_audio_player.dart';
import 'widgets/audio_common.dart';

/// The full player.
///
/// «عايز البلاير يبقى روعة بصريًا واحترافي … وفيه كل إمكانيات البلاير
/// الحديثة»: seek with elapsed and remaining time, ten-second skips, previous
/// and next, shuffle, repeat (list / one surah), playback speed, a sleep timer
/// that can also stop at the end of the surah, and the queue — with the lock
/// screen and notification controls `just_audio_background` already provides.
///
/// The transport is laid out left-to-right in every language, the way media
/// controls are: ⏮ and ⏭ are pictures of direction, and mirrored in an Arabic
/// row they would point at the wrong surah.
class QuranAudioPlayerScreen extends StatelessWidget {
  const QuranAudioPlayerScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 380),
          pageBuilder: (_, _, _) => const QuranAudioPlayerScreen(),
          transitionsBuilder: (_, anim, _, child) => SlideTransition(
            position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                .chain(CurveTween(curve: Curves.easeOutCubic))
                .animate(anim),
            child: child,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final player = QuranAudioPlayer.instance;
    return Scaffold(
      backgroundColor: AppColors.night,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B2F24), AppColors.nightElevated, AppColors.night],
            stops: [0, 0.45, 1],
          ),
        ),
        child: SafeArea(
          child: ListenableBuilder(
            listenable: player,
            builder: (context, _) {
              final track = player.current;
              return Column(
                children: [
                  _TopBar(onQueue: track == null ? null : () => _showQueue(context)),
                  Expanded(
                    child: track == null
                        ? Center(
                            child: Text('quran_audio.no_track'.tr(),
                                style: const TextStyle(color: AppColors.textMedium)),
                          )
                        : LayoutBuilder(
                            builder: (context, c) => SingleChildScrollView(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minHeight: c.maxHeight),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 26),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _Artwork(track: track, playing: player.playing),
                                      _Titles(track: track),
                                      const _SeekBar(),
                                      const _Transport(),
                                      const _Extras(),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  static void _showQueue(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.nightElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (ctx, scroll) => ListenableBuilder(
          listenable: QuranAudioPlayer.instance,
          builder: (ctx, _) {
            final player = QuranAudioPlayer.instance;
            return Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.nightBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text('quran_audio.queue'.tr(),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: AppColors.textHigh)),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scroll,
                    itemCount: player.queue.length,
                    itemBuilder: (ctx, i) {
                      final t = player.queue[i];
                      final current = i == player.index;
                      return ListTile(
                        leading: SizedBox(
                          width: 32,
                          child: Center(
                            child: current
                                ? const Icon(Icons.graphic_eq_rounded,
                                    color: AppColors.gold)
                                : Text(ltr('${i + 1}'),
                                    style: const TextStyle(color: AppColors.textLow)),
                          ),
                        ),
                        title: Text(t.title,
                            style: TextStyle(
                                fontWeight: current ? FontWeight.w800 : FontWeight.w500,
                                color: current ? AppColors.gold : AppColors.textHigh)),
                        subtitle: Text(t.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.textLow, fontSize: 12)),
                        trailing: Icon(
                          t.isLocal ? Icons.offline_pin_rounded : Icons.cloud_outlined,
                          size: 18,
                          color: t.isLocal ? AppColors.success : AppColors.textLow,
                        ),
                        onTap: () => player.jumpTo(i),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback? onQueue;
  const _TopBar({required this.onQueue});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
      child: Row(
        children: [
          IconButton(
            iconSize: 32,
            color: AppColors.textHigh,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Text(
              'quran_audio.now_playing'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textMedium,
                letterSpacing: 0.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            tooltip: 'quran_audio.queue'.tr(),
            color: AppColors.textHigh,
            icon: const Icon(Icons.queue_music_rounded),
            onPressed: onQueue,
          ),
        ],
      ),
    );
  }
}

class _Artwork extends StatelessWidget {
  final PlayerTrack track;
  final bool playing;
  const _Artwork({required this.track, required this.playing});

  @override
  Widget build(BuildContext context) {
    final size = (MediaQuery.sizeOf(context).width * 0.72).clamp(200.0, 340.0);
    return AnimatedScale(
      scale: playing ? 1.0 : 0.92,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      child: Hero(
        tag: 'quran-audio-art',
        child: RecitationCover(
          title: track.title,
          artist: track.artist,
          album: track.album,
          size: size,
        ),
      ),
    );
  }
}

class _Titles extends StatelessWidget {
  final PlayerTrack track;
  const _Titles({required this.track});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 18),
        Text(
          track.title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.goldSoft,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          track.artist,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: AppColors.textHigh),
        ),
        if ((track.album ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
            ),
            child: Text(
              track.album!,
              style: const TextStyle(fontSize: 12, color: AppColors.goldSoft),
            ),
          ),
        ],
        const SizedBox(height: 10),
      ],
    );
  }
}

class _SeekBar extends StatefulWidget {
  const _SeekBar();

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final player = QuranAudioPlayer.instance;
    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: StreamBuilder<Duration?>(
        stream: player.durationStream,
        builder: (context, dur) {
          final total = dur.data ?? Duration.zero;
          return StreamBuilder<Duration>(
            stream: player.positionStream,
            builder: (context, pos) {
              final max = total.inMilliseconds.toDouble();
              final at = (_dragging ?? (pos.data?.inMilliseconds ?? 0).toDouble())
                  .clamp(0.0, max <= 0 ? 0.0 : max);
              return Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      activeTrackColor: AppColors.gold,
                      inactiveTrackColor: AppColors.nightBorder,
                      thumbColor: AppColors.goldSoft,
                      overlayColor: AppColors.gold.withValues(alpha: 0.15),
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                    ),
                    child: Slider(
                      value: at,
                      max: max <= 0 ? 1 : max,
                      onChanged: max <= 0 ? null : (v) => setState(() => _dragging = v),
                      onChangeEnd: (v) {
                        player.seek(Duration(milliseconds: v.round()));
                        setState(() => _dragging = null);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Text(formatClock(Duration(milliseconds: at.round())),
                            style: const TextStyle(color: AppColors.textMedium, fontSize: 12)),
                        const Spacer(),
                        Text(
                          max <= 0
                              ? '--:--'
                              : '-${formatClock(total - Duration(milliseconds: at.round()))}',
                          style: const TextStyle(color: AppColors.textMedium, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _Transport extends StatelessWidget {
  const _Transport();

  @override
  Widget build(BuildContext context) {
    final player = QuranAudioPlayer.instance;
    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              iconSize: 30,
              color: AppColors.textHigh,
              icon: const Icon(Icons.replay_10_rounded),
              onPressed: () => player.skip(const Duration(seconds: -10)),
            ),
            IconButton(
              iconSize: 40,
              color: AppColors.textHigh,
              icon: const Icon(Icons.skip_previous_rounded),
              onPressed: player.previous,
            ),
            StreamBuilder<PlayerState>(
              stream: player.stateStream,
              builder: (context, _) {
                final state = player.stateNow;
                final busy = player.playing &&
                    (state == ProcessingState.loading ||
                        state == ProcessingState.buffering);
                return GestureDetector(
                  onTap: player.togglePlay,
                  child: Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.goldSoft, AppColors.gold],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.35),
                          blurRadius: 22,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: busy
                          ? const SizedBox(
                              width: 30,
                              height: 30,
                              child: CircularProgressIndicator(
                                  strokeWidth: 3, color: AppColors.night),
                            )
                          : Icon(
                              player.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              size: 46,
                              color: AppColors.night,
                            ),
                    ),
                  ),
                );
              },
            ),
            IconButton(
              iconSize: 40,
              color: AppColors.textHigh,
              icon: const Icon(Icons.skip_next_rounded),
              onPressed: player.next,
            ),
            IconButton(
              iconSize: 30,
              color: AppColors.textHigh,
              icon: const Icon(Icons.forward_10_rounded),
              onPressed: () => player.skip(const Duration(seconds: 10)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Extras extends StatelessWidget {
  const _Extras();

  @override
  Widget build(BuildContext context) {
    final player = QuranAudioPlayer.instance;
    final loopIcon = player.loop == LoopMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded;
    final sleeping = player.sleepMode != SleepMode.off;
    return Column(
      children: [
        Directionality(
          textDirection: ui.TextDirection.ltr,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Toggle(
                icon: Icons.shuffle_rounded,
                on: player.shuffle,
                tooltip: 'quran_audio.shuffle'.tr(),
                onTap: player.toggleShuffle,
              ),
              _Toggle(
                icon: loopIcon,
                on: player.loop != LoopMode.off,
                tooltip: 'quran_audio.repeat'.tr(),
                onTap: player.cycleLoop,
              ),
              TextButton(
                onPressed: () => _pickSpeed(context),
                style: TextButton.styleFrom(
                  foregroundColor: player.speed == 1.0 ? AppColors.textMedium : AppColors.gold,
                ),
                child: Text(ltr('${_speedLabel(player.speed)}×'),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
              _Toggle(
                icon: Icons.bedtime_outlined,
                on: sleeping,
                tooltip: 'quran_audio.sleep_timer'.tr(),
                onTap: () => _pickSleep(context),
              ),
            ],
          ),
        ),
        if (sleeping)
          Text(
            player.sleepMode == SleepMode.endOfTrack
                ? 'quran_audio.sleep_end_of_track'.tr()
                : 'quran_audio.sleep_at'.tr(args: [
                    DateFormat.Hm(context.locale.languageCode).format(player.sleepAt!),
                  ]),
            style: const TextStyle(color: AppColors.goldSoft, fontSize: 12),
          ),
      ],
    );
  }

  static String _speedLabel(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';

  void _pickSpeed(BuildContext context) {
    final player = QuranAudioPlayer.instance;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.nightElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('quran_audio.speed'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textHigh)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  for (final s in QuranAudioPlayer.speeds)
                    ChoiceChip(
                      label: Text(ltr('${_speedLabel(s)}×')),
                      selected: player.speed == s,
                      selectedColor: AppColors.gold,
                      onSelected: (_) {
                        player.setSpeed(s);
                        Navigator.pop(ctx);
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _pickSleep(BuildContext context) {
    final player = QuranAudioPlayer.instance;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.nightElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('quran_audio.sleep_timer'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textHigh)),
            ),
            for (final m in const [15, 30, 45, 60, 90])
              ListTile(
                leading: const Icon(Icons.timer_outlined, color: AppColors.goldSoft),
                title: Text('quran_audio.sleep_minutes'.tr(args: ['$m'])),
                onTap: () {
                  player.setSleep(SleepMode.timer, after: Duration(minutes: m));
                  Navigator.pop(ctx);
                },
              ),
            ListTile(
              leading: const Icon(Icons.last_page_rounded, color: AppColors.goldSoft),
              title: Text('quran_audio.sleep_end_of_track'.tr()),
              onTap: () {
                player.setSleep(SleepMode.endOfTrack);
                Navigator.pop(ctx);
              },
            ),
            if (player.sleepMode != SleepMode.off)
              ListTile(
                leading: const Icon(Icons.close_rounded, color: AppColors.error),
                title: Text('quran_audio.sleep_off'.tr()),
                onTap: () {
                  player.setSleep(SleepMode.off);
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final IconData icon;
  final bool on;
  final String tooltip;
  final VoidCallback onTap;
  const _Toggle({required this.icon, required this.on, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: tooltip,
          iconSize: 26,
          color: on ? AppColors.gold : AppColors.textMedium,
          icon: Icon(icon),
          onPressed: onTap,
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: on ? 5 : 0,
          height: 5,
          decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
        ),
      ],
    );
  }
}
