import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/byte_formatter.dart';
import '../../../core/widgets/islamic_pattern.dart';
import '../../quran/data/mushaf_data_provider.dart';
import '../data/mp3quran_api.dart';
import '../data/quran_audio_library.dart';
import '../data/quran_audio_player.dart';
import 'widgets/audio_common.dart';
import 'widgets/mini_player.dart';

/// One reciter: his recitations as tabs, each a folder of 114 surahs (or as
/// many as the host has) to play, stream, or download whole.
class ReciterScreen extends ConsumerStatefulWidget {
  final Mp3Reciter reciter;
  final int? initialMoshafId;

  const ReciterScreen({super.key, required this.reciter, this.initialMoshafId});

  @override
  ConsumerState<ReciterScreen> createState() => _ReciterScreenState();
}

class _ReciterScreenState extends ConsumerState<ReciterScreen> {
  late Mp3Moshaf _moshaf = widget.reciter.moshafs.firstWhere(
    (m) => m.id == widget.initialMoshafId,
    orElse: () => widget.reciter.moshafs.first,
  );

  @override
  void initState() {
    super.initState();
    QuranAudioLibrary.instance.ensureReady();
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
      bottomNavigationBar: const MiniPlayer(),
      body: ListenableBuilder(
        listenable: Listenable.merge([lib, player]),
        builder: (context, _) {
          final entry = lib.entry(_moshaf.id);
          final done = lib.downloadedCount(_moshaf.id);
          final total = _moshaf.surahs.length;
          final pending = entry?.pending.isNotEmpty ?? false;
          final paused = pending && (entry?.paused ?? false);
          return CustomScrollView(
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
                  child: IslamicPatternPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ReciterAvatar(name: widget.reciter.name, size: 56),
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
