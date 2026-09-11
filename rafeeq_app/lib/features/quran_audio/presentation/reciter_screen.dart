import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/byte_formatter.dart';
import '../../../core/widgets/islamic_pattern.dart';
import '../../quran/data/mushaf_data_provider.dart';
import '../data/mp3quran_api.dart';
import '../data/player_theme.dart';
import '../data/quran_audio_library.dart';
import '../data/quran_audio_player.dart';
import 'widgets/audio_common.dart';
import 'widgets/mini_player.dart';

/// One reciter: his recitations as tabs, each a folder of 114 surahs (or as
/// many as the host has) to play, stream, or download whole.
class ReciterScreen extends ConsumerStatefulWidget {
  final Mp3Reciter reciter;
  final int? initialMoshafId;

  /// His number in the reciters list, drawn on his badge.
  final int? number;

  const ReciterScreen({
    super.key,
    required this.reciter,
    this.initialMoshafId,
    this.number,
  });

  @override
  ConsumerState<ReciterScreen> createState() => _ReciterScreenState();
}

class _ReciterScreenState extends ConsumerState<ReciterScreen> {
  late Mp3Moshaf _moshaf = widget.reciter.moshafs.firstWhere(
    (m) => m.id == widget.initialMoshafId,
    orElse: () => widget.reciter.moshafs.first,
  );

  final _scroll = ScrollController();
  final Map<int, GlobalKey> _rowKeys = {};
  bool _showTop = false;

  @override
  void initState() {
    super.initState();
    QuranAudioLibrary.instance.ensureReady();
    _scroll.addListener(() {
      final show = _scroll.hasClients &&
          _scroll.offset > _scroll.position.viewportDimension;
      if (show != _showTop) setState(() => _showTop = show);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// The surah transferring now (or next), with its progress.
  (int, double)? _downloading(QuranAudioLibrary lib) {
    (int, double)? queued;
    for (final surah in _moshaf.surahs) {
      final st = lib.statusOf(_moshaf.id, surah);
      if (st.state == SurahAudioState.running) return (surah, st.progress);
      if (st.state == SurahAudioState.queued) queued ??= (surah, 0);
    }
    return queued;
  }

  /// «لو ضغطت عليه ينقلني فورًا عند المكان اللي بتتحمّل منه السورة».
  void _jumpToSurah(int surah) {
    final i = _moshaf.surahs.indexOf(surah);
    if (i < 0 || !_scroll.hasClients) return;
    final ctx = _rowKeys[surah]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, alignment: 0.3, duration: const Duration(milliseconds: 350));
      return;
    }
    // Not built yet (the list builds as it scrolls): land near it by the
    // rows' height, then settle exactly on it.
    _scroll.jumpTo((300 + i * 64.0).clamp(0.0, _scroll.position.maxScrollExtent));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _rowKeys[surah]?.currentContext;
      if (c != null) {
        Scrollable.ensureVisible(c, alignment: 0.3, duration: const Duration(milliseconds: 250));
      }
    });
  }

  Future<void> _play({int? fromSurah}) async {
    final locale = context.locale.languageCode;
    final data = ref.read(mushafDataProvider).valueOrNull;
    final tracks = recitationTracks(
      reciterName: widget.reciter.name,
      moshaf: _moshaf,
      data: data,
      locale: locale,
    );
    final start = fromSurah == null ? 0 : _moshaf.surahs.indexOf(fromSurah);
    final ok = await QuranAudioPlayer.instance.playQueue(tracks, start: start < 0 ? 0 : start);
    if (!ok && mounted) showPlayFailed(context);
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(mushafDataProvider).valueOrNull;
    final locale = context.locale.languageCode;
    final lib = QuranAudioLibrary.instance;
    final player = QuranAudioPlayer.instance;

    return Scaffold(
      appBar: AppBar(title: Text(widget.reciter.name)),
      // «زرار شفاف أسفل يسار الشاشة لما أنزل بمقدار صفحة يرفعني لأول الصفحة».
      floatingActionButtonLocation:
          Directionality.of(context) == ui.TextDirection.rtl
              ? FloatingActionButtonLocation.endFloat
              : FloatingActionButtonLocation.startFloat,
      floatingActionButton: _showTop
          ? FloatingActionButton.small(
              heroTag: 'reciter-top',
              elevation: 0,
              backgroundColor: Colors.black.withValues(alpha: 0.35),
              foregroundColor: Colors.white,
              onPressed: () => _scroll.animateTo(0,
                  duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic),
              child: const Icon(Icons.keyboard_double_arrow_up_rounded),
            )
          : null,
      bottomNavigationBar: const MiniPlayer(),
      body: ListenableBuilder(
        listenable: Listenable.merge([lib, player]),
        builder: (context, _) {
          final entry = lib.entry(_moshaf.id);
          final done = lib.downloadedCount(_moshaf.id);
          final total = _moshaf.surahs.length;
          final pending = entry?.pending.isNotEmpty ?? false;
          final paused = pending && (entry?.paused ?? false);
          final theme = ref.watch(playerThemeProvider);
          final now = _downloading(lib);
          return CustomScrollView(
            controller: _scroll,
            slivers: [
              if (widget.reciter.moshafs.length > 1)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 54,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                      children: [
                        for (final m in widget.reciter.moshafs)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: ChoiceChip(
                              label: Text(m.name),
                              selected: m.id == _moshaf.id,
                              selectedColor: AppColors.gold.withValues(alpha: 0.9),
                              onSelected: (_) => setState(() => _moshaf = m),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                  child: _ThemedPanel(
                    theme: theme,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ReciterAvatar(name: widget.reciter.name, number: widget.number, size: 56),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _moshaf.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      color: AppColors.textHigh,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'quran_audio.downloaded_of'.tr(args: [ltr('$done'), ltr('$total')]),
                                    style: const TextStyle(color: AppColors.textMedium, fontSize: 12.5),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        GoldProgressBar(
                          value: total == 0 ? 0 : done / total,
                          height: 6,
                          color: done >= total ? AppColors.success : AppColors.gold,
                        ),
                        if (now != null) ...[
                          const SizedBox(height: 10),
                          InkWell(
                            onTap: () => _jumpToSurah(now.$1),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Icon(Icons.downloading_rounded, color: theme.accent, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'quran_audio.now_downloading'.tr(args: [
                                        surahTitle(data, now.$1, locale),
                                        ltr('${(now.$2 * 100).round()}%'),
                                      ]),
                                      style: TextStyle(color: theme.accentSoft, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  Icon(Icons.my_location_rounded, color: theme.accentSoft, size: 18),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.gold,
                                foregroundColor: AppColors.night,
                              ),
                              onPressed: _play,
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: Text('quran_audio.play_all'.tr()),
                            ),
                            if (done < total && !pending)
                              FilledButton.tonalIcon(
                                onPressed: () => lib.download(widget.reciter, _moshaf),
                                icon: const Icon(Icons.download_rounded),
                                label: Text('quran_audio.download_all'.tr()),
                              ),
                            if (pending && !paused)
                              FilledButton.tonalIcon(
                                onPressed: () => lib.pause(_moshaf.id),
                                icon: const Icon(Icons.pause_rounded),
                                label: Text('quran_audio.pause_all'.tr()),
                              ),
                            if (paused)
                              FilledButton.tonalIcon(
                                onPressed: () => lib.resume(_moshaf.id),
                                icon: const Icon(Icons.play_for_work_rounded),
                                label: Text('quran_audio.resume_all'.tr()),
                              ),
                            if (pending)
                              TextButton.icon(
                                onPressed: () => lib.cancel(_moshaf.id),
                                icon: const Icon(Icons.stop_circle_outlined),
                                label: Text('quran_audio.cancel_all'.tr()),
                              ),
                            if (done > 0)
                              TextButton.icon(
                                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                                onPressed: () async {
                                  if (await confirmAction(context, 'quran_audio.delete_confirm'.tr())) {
                                    await lib.deleteRecitation(_moshaf.id);
                                  }
                                },
                                icon: const Icon(Icons.delete_outline_rounded),
                                label: Text('quran_audio.delete_all'.tr()),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 24),
                sliver: SliverList.builder(
                  itemCount: _moshaf.surahs.length,
                  itemBuilder: (context, i) {
                    final s = _moshaf.surahs[i];
                    final playing = player.active && player.current?.id == trackIdFor(_moshaf.id, s);
                    return _SurahRow(
                      key: _rowKeys.putIfAbsent(s, GlobalKey.new),
                      surah: s,
                      title: surahTitle(data, s, locale),
                      status: lib.statusOf(_moshaf.id, s),
                      playing: playing,
                      onPlay: () => _play(fromSurah: s),
                      onDownload: () => lib.download(widget.reciter, _moshaf, only: [s]),
                      onCancel: () => lib.cancelSurah(_moshaf.id, s),
                      onDelete: () async {
                        if (await confirmAction(context, 'quran_audio.delete_surah_confirm'.tr())) {
                          await lib.deleteSurah(_moshaf.id, s);
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SurahRow extends StatelessWidget {
  final int surah;
  final String title;
  final SurahAudioStatus status;
  final bool playing;
  final VoidCallback onPlay;
  final VoidCallback onDownload;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  const _SurahRow({
    super.key,
    required this.surah,
    required this.title,
    required this.status,
    required this.playing,
    required this.onPlay,
    required this.onDownload,
    required this.onCancel,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final state = status.state;
    Widget? sub;
    switch (state) {
      case SurahAudioState.done:
        sub = Text('quran_audio.downloaded'.tr(),
            style: const TextStyle(color: AppColors.success, fontSize: 12));
      case SurahAudioState.running:
        sub = Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  minHeight: 5,
                  value: status.progress <= 0 ? null : status.progress,
                  color: AppColors.gold,
                  backgroundColor: AppColors.nightBorder,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(ltr('${(status.progress * 100).round()}%'),
                style: const TextStyle(fontSize: 11, color: AppColors.textMedium)),
          ],
        );
      case SurahAudioState.queued:
        sub = Text('quran_audio.queued'.tr(),
            style: const TextStyle(color: AppColors.textLow, fontSize: 12));
      case SurahAudioState.failed:
        sub = Text('quran_audio.failed_retry'.tr(),
            style: const TextStyle(color: AppColors.error, fontSize: 12));
      case SurahAudioState.none:
        sub = null;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: playing
            ? AppColors.gold.withValues(alpha: 0.12)
            : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPlay,
          onLongPress: state == SurahAudioState.done ? onDelete : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.gold.withValues(alpha: playing ? 0.3 : 0.1),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
                  ),
                  child: playing
                      ? const Icon(Icons.graphic_eq_rounded, color: AppColors.gold, size: 20)
                      : Text(ltr('$surah'),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.goldSoft)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: playing ? AppColors.gold : null,
                          )),
                      if (sub != null) ...[const SizedBox(height: 4), sub],
                    ],
                  ),
                ),
                if (state == SurahAudioState.done)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.offline_pin_rounded, color: AppColors.success, size: 22),
                  )
                else if (status.isActive)
                  IconButton(
                    tooltip: 'downloads.cancel'.tr(),
                    icon: const Icon(Icons.close_rounded),
                    onPressed: onCancel,
                  )
                else
                  IconButton(
                    tooltip: 'downloads.download'.tr(),
                    color: AppColors.gold,
                    icon: const Icon(Icons.download_rounded),
                    onPressed: onDownload,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


/// The recitation card on the reciter's screen, in the player's theme: its
/// ground, a lattice drawn over it, and a rim in its accent.
class _ThemedPanel extends StatelessWidget {
  final PlayerTheme theme;
  final Widget child;
  const _ThemedPanel({required this.theme, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: theme.ground,
        ),
        border: Border.all(color: theme.accent.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(color: theme.accent.withValues(alpha: 0.15), blurRadius: 18),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: IslamicPatternPainter(
                  tile: 54,
                  color: theme.accent.withValues(alpha: 0.12),
                ),
              ),
            ),
            Padding(padding: const EdgeInsets.all(16), child: child),
          ],
        ),
      ),
    );
  }
}
