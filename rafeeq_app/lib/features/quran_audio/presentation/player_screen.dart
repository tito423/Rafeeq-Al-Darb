import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/byte_formatter.dart';
import '../../../core/widgets/islamic_pattern.dart';
import '../data/player_theme.dart';
import '../data/quran_audio_player.dart';
import 'widgets/audio_common.dart';

/// The full player.
///
/// Seek with elapsed and remaining time, ten-second skips, previous and next,
/// shuffle, repeat (list / one surah), speed, a sleep timer that can stop at
/// the end of the surah, the queue, and — «زرار ثيمات بعشر ثيمات … والكارت
/// اللي في النص يتحرك بصريًا، مثلًا يلف كأنه سي دي» — ten themes and a disc
/// that turns while the recitation plays and stops where it is when paused.
///
/// The transport is laid out left-to-right in every language, the way media
/// controls are: ⏮ and ⏭ are pictures of direction.
class QuranAudioPlayerScreen extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final player = QuranAudioPlayer.instance;
    final t = ref.watch(playerThemeProvider);
    return Scaffold(
      backgroundColor: t.ground.last,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: t.ground,
            stops: const [0, 0.45, 1],
          ),
        ),
        child: SafeArea(
          child: ListenableBuilder(
            listenable: player,
            builder: (context, _) {
              final track = player.current;
              return Column(
                children: [
                  _TopBar(
                    theme: t,
                    onQueue: track == null ? null : () => _showQueue(context, t),
                    onTheme: () => _pickTheme(context, ref),
                  ),
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
                                      _Disc(track: track, playing: player.playing, theme: t),
                                      _Titles(track: track, theme: t),
                                      _SeekBar(theme: t),
                                      _Transport(theme: t),
                                      _Extras(theme: t),
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

  static void _pickTheme(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.nightElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final current = ref.watch(playerThemeProvider);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('quran_audio.theme'.tr(),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textHigh)),
                  const SizedBox(height: 18),
                  GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 5,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.72,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (final theme in playerThemes)
                        InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => ref.read(playerThemeProvider.notifier).select(theme),
                          child: Column(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [theme.ground.first, theme.ground.last],
                                  ),
                                  border: Border.all(
                                    color: theme.accent,
                                    width: theme.id == current.id ? 3 : 1.2,
                                  ),
                                  boxShadow: theme.id == current.id
                                      ? [BoxShadow(color: theme.accent.withValues(alpha: 0.5), blurRadius: 12)]
                                      : null,
                                ),
                                child: theme.id == current.id
                                    ? Icon(Icons.check_rounded, color: theme.accentSoft)
                                    : Center(
                                        child: Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                              color: theme.accent, shape: BoxShape.circle),
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                theme.nameKey.tr(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.id == current.id ? theme.accentSoft : AppColors.textMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static void _showQueue(BuildContext context, PlayerTheme t) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.ground[1],
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
                    color: t.accent.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text('quran_audio.queue'.tr(),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textHigh)),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scroll,
                    itemCount: player.queue.length,
                    itemBuilder: (ctx, i) {
                      final track = player.queue[i];
                      final current = i == player.index;
                      return ListTile(
                        leading: SizedBox(
                          width: 32,
                          child: Center(
                            child: current
                                ? Icon(Icons.graphic_eq_rounded, color: t.accent)
                                : Text(ltr('${i + 1}'),
                                    style: const TextStyle(color: AppColors.textLow)),
                          ),
                        ),
                        title: Text(track.title,
                            style: TextStyle(
                                fontWeight: current ? FontWeight.w800 : FontWeight.w500,
                                color: current ? t.accentSoft : AppColors.textHigh)),
                        subtitle: Text(track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.textLow, fontSize: 12)),
                        trailing: Icon(
                          track.isLocal ? Icons.offline_pin_rounded : Icons.cloud_outlined,
                          size: 18,
                          color: track.isLocal ? AppColors.success : AppColors.textLow,
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
  final PlayerTheme theme;
  final VoidCallback? onQueue;
  final VoidCallback onTheme;
  const _TopBar({required this.theme, required this.onQueue, required this.onTheme});

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
            tooltip: 'quran_audio.theme'.tr(),
            color: theme.accentSoft,
            icon: const Icon(Icons.palette_outlined),
            onPressed: onTheme,
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

/// A disc that turns while the recitation plays: grooves and a sheen on a
/// ring that rotates, around a label that stays upright so the surah and the
/// reciter can be read at any moment.
class _Disc extends StatefulWidget {
  final PlayerTrack track;
  final bool playing;
  final PlayerTheme theme;
  const _Disc({required this.track, required this.playing, required this.theme});

  @override
  State<_Disc> createState() => _DiscState();
}

class _DiscState extends State<_Disc> with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  );

  @override
  void initState() {
    super.initState();
    if (widget.playing) _spin.repeat();
  }

  @override
  void didUpdateWidget(covariant _Disc old) {
    super.didUpdateWidget(old);
    if (widget.playing && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!widget.playing && _spin.isAnimating) {
      _spin.stop(); // stays at its angle, like a record lifted off
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final size = (MediaQuery.sizeOf(context).width * 0.74).clamp(210.0, 340.0);
    final label = size * 0.52;
    return AnimatedScale(
      scale: widget.playing ? 1.0 : 0.93,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Glow, breathing with the disc.
            AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: t.accent.withValues(alpha: widget.playing ? 0.35 : 0.1),
                    blurRadius: size * 0.18,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            RotationTransition(
              turns: _spin,
              child: CustomPaint(
                size: Size.square(size),
                painter: _DiscPainter(theme: t),
              ),
            ),
            // The label: upright, in the theme's ground.
            Container(
              width: label,
              height: label,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [t.ground.first, t.ground.last],
                ),
                border: Border.all(color: t.accent.withValues(alpha: 0.8), width: 1.6),
              ),
              child: ClipOval(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      painter: IslamicPatternPainter(
                        tile: label / 3,
                        color: t.accent.withValues(alpha: 0.10),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(label * 0.14),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                widget.track.title,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                style: TextStyle(
                                  fontFamily: 'AmiriQuran',
                                  fontSize: label * 0.17,
                                  height: 1.5,
                                  color: t.accentSoft,
                                ),
                              ),
                            ),
                          ),
                          Container(
                            margin: EdgeInsets.symmetric(vertical: label * 0.03),
                            width: label * 0.35,
                            height: 1.2,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                Colors.transparent,
                                t.accent,
                                Colors.transparent,
                              ]),
                            ),
                          ),
                          Text(
                            widget.track.artist,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: label * 0.075,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textHigh,
                            ),
                          ),
                        ],
                      ),
                    ),
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

class _DiscPainter extends CustomPainter {
  final PlayerTheme theme;
  _DiscPainter({required this.theme});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final disc = Paint()
      ..shader = RadialGradient(
        colors: [Color.lerp(theme.ground.last, Colors.black, 0.35)!, theme.ground.last],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, disc);

    // Grooves.
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (var rr = r * 0.54; rr < r * 0.97; rr += 3.2) {
      groove.color = theme.accent.withValues(alpha: 0.05 + 0.05 * ((rr / 3.2).floor() % 3 == 0 ? 1 : 0));
      canvas.drawCircle(c, rr, groove);
    }

    // Two sheens on opposite sides — what makes a turning disc look like it
    // turns.
    final sheen = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          theme.accentSoft.withValues(alpha: 0.22),
          Colors.transparent,
          Colors.transparent,
          theme.accentSoft.withValues(alpha: 0.14),
          Colors.transparent,
        ],
        stops: const [0.0, 0.08, 0.16, 0.5, 0.58, 0.66],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r * 0.97, sheen);

    // A marker on the rim, so the turn can be seen even on a quiet theme.
    final mark = Paint()..color = theme.accent;
    canvas.drawCircle(c + Offset(math.cos(-math.pi / 2) * r * 0.9, math.sin(-math.pi / 2) * r * 0.9), 3.2, mark);

    canvas.drawCircle(
      c,
      r - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = theme.accent.withValues(alpha: 0.7),
    );
  }

  @override
  bool shouldRepaint(covariant _DiscPainter old) => old.theme.id != theme.id;
}

class _Titles extends StatelessWidget {
  final PlayerTrack track;
  final PlayerTheme theme;
  const _Titles({required this.track, required this.theme});

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
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: theme.accentSoft),
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
              color: theme.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.accent.withValues(alpha: 0.3)),
            ),
            child: Text(track.album!, style: TextStyle(fontSize: 12, color: theme.accentSoft)),
          ),
        ],
        const SizedBox(height: 10),
      ],
    );
  }
}

class _SeekBar extends StatefulWidget {
  final PlayerTheme theme;
  const _SeekBar({required this.theme});

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final player = QuranAudioPlayer.instance;
    final t = widget.theme;
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
                      activeTrackColor: t.accent,
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
                      thumbColor: t.accentSoft,
                      overlayColor: t.accent.withValues(alpha: 0.15),
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
  final PlayerTheme theme;
  const _Transport({required this.theme});

  @override
  Widget build(BuildContext context) {
    final player = QuranAudioPlayer.instance;
    final t = theme;
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
                    (state == ProcessingState.loading || state == ProcessingState.buffering);
                return GestureDetector(
                  onTap: player.togglePlay,
                  child: Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [t.accentSoft, t.accent],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: t.accent.withValues(alpha: 0.35),
                          blurRadius: 22,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: busy
                          ? SizedBox(
                              width: 30,
                              height: 30,
                              child: CircularProgressIndicator(strokeWidth: 3, color: t.onAccent),
                            )
                          : Icon(
                              player.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              size: 46,
                              color: t.onAccent,
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
  final PlayerTheme theme;
  const _Extras({required this.theme});

  @override
  Widget build(BuildContext context) {
    final player = QuranAudioPlayer.instance;
    final t = theme;
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
                accent: t.accent,
                tooltip: 'quran_audio.shuffle'.tr(),
                onTap: player.toggleShuffle,
              ),
              _Toggle(
                icon: loopIcon,
                on: player.loop != LoopMode.off,
                accent: t.accent,
                tooltip: 'quran_audio.repeat'.tr(),
                onTap: player.cycleLoop,
              ),
              TextButton(
                onPressed: () => _pickSpeed(context),
                style: TextButton.styleFrom(
                  foregroundColor: player.speed == 1.0 ? AppColors.textMedium : t.accent,
                ),
                child: Text(ltr('${_speedLabel(player.speed)}×'),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
              _Toggle(
                icon: Icons.bedtime_outlined,
                on: sleeping,
                accent: t.accent,
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
            style: TextStyle(color: t.accentSoft, fontSize: 12),
          ),
      ],
    );
  }

  static String _speedLabel(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';

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
                      selectedColor: theme.accent,
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
                leading: Icon(Icons.timer_outlined, color: theme.accentSoft),
                title: Text('quran_audio.sleep_minutes'.tr(args: ['$m'])),
                onTap: () {
                  player.setSleep(SleepMode.timer, after: Duration(minutes: m));
                  Navigator.pop(ctx);
                },
              ),
            ListTile(
              leading: Icon(Icons.last_page_rounded, color: theme.accentSoft),
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
  final Color accent;
  final String tooltip;
  final VoidCallback onTap;
  const _Toggle({
    required this.icon,
    required this.on,
    required this.accent,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: tooltip,
          iconSize: 26,
          color: on ? accent : AppColors.textMedium,
          icon: Icon(icon),
          onPressed: onTap,
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: on ? 5 : 0,
          height: 5,
          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
        ),
      ],
    );
  }
}
