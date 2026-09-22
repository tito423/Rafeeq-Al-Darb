/// One reciter's 114 surahs for per-ayah download — rebuilt 2026-09-22.
///
/// «قسم تنزيل التلاوات بالآيات ده دايمًا نشكله، اعمله ريفاكتور وهندسة
/// بشكل ميقرفنيش بعد مدة». What was wrong with the old screen, from the
/// owner's video and screenshots:
///
///  * the ring read «١٠٠٪» at 6,232 / 6,236 (rounded), and the download and
///    pause buttons stayed up beside it;
///  * nothing said WHICH ayahs were missing — they were at the bottom of a
///    114-row list;
///  * «حذف» appeared to do nothing, and was drawn in the app's green.
///
/// Now the summary says one plain thing for each state (complete, running,
/// paused, incomplete — with the number missing and one button to fetch
/// them), a filter jumps straight to the incomplete surahs, and delete is
/// red and immediate. The download logic stays in
/// `AyahRecitationLibrary`; this file only draws it.
library;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/models.dart';
import '../../../core/db/quran_repository.dart';
import '../../../core/services/ayah_audio_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/byte_formatter.dart' show ratio;
import '../../../core/utils/digits.dart';
import '../../downloads/data/reciters_provider.dart';
import '../data/ayah_recitation_library.dart';
import 'widgets/ayah_dl_ring.dart';

enum _Filter { all, missing, complete }

class AyahReciterScreen extends ConsumerStatefulWidget {
  final Reciter reciter;
  const AyahReciterScreen({super.key, required this.reciter});

  @override
  ConsumerState<AyahReciterScreen> createState() => _AyahReciterScreenState();
}

class _AyahReciterScreenState extends ConsumerState<AyahReciterScreen> {
  String _query = '';
  _Filter _filter = _Filter.all;

  /// The surah whose recitation this screen started, while it plays.
  int? _playing;

  String get _edition => widget.reciter.identifier;
  AyahRecitationLibrary get _lib => AyahRecitationLibrary.instance;

  @override
  void initState() {
    super.initState();
    _lib.ensureReady();
    _lib.addListener(_rebuild);
  }

  @override
  void dispose() {
    _lib.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _play(Surah surah) async {
    final audio = AyahAudioService.instance;
    if (_playing == surah.id) {
      await audio.stopQueue();
      if (mounted) setState(() => _playing = null);
      return;
    }
    final repo = await ref.read(quranRepositoryProvider.future);
    final ayahs = await repo.ayahsOfSurah(surah.id);
    if (!mounted || ayahs.isEmpty) return;
    setState(() => _playing = surah.id);
    await audio.playQueue(
      ayahs,
      repo,
      edition: _edition,
      titleFor: (a, _) => '${surah.nameAr} ${a.ayahNumber}',
    );
    if (mounted && _playing == surah.id) setState(() => _playing = null);
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('ayah_dl.delete_confirm'.tr()),
        content: Text(widget.reciter.displayName(context.locale.languageCode)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('downloads.delete'.tr()),
          ),
        ],
      ),
    );
    if (ok == true) await _lib.deleteReciter(_edition);
  }

  bool _matches(Surah s) {
    final q = _query.trim();
    if (q.isNotEmpty &&
        !s.nameAr.contains(q) &&
        !s.nameEn.toLowerCase().contains(q.toLowerCase()) &&
        '${s.id}' != asciiDigits(q)) {
      return false;
    }
    final total = AyahRecitationLibrary.ayahCount(s.id);
    final have = _lib.surahDownloadedCount(_edition, s.id);
    return switch (_filter) {
      _Filter.all => true,
      _Filter.missing => have < total,
      _Filter.complete => have >= total,
    };
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.languageCode;
    final scheme = Theme.of(context).colorScheme;
    final progress = _lib.progressOf(_edition);
    final repoAsync = ref.watch(quranRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.reciter.displayName(locale)),
        actions: [
          if (progress.downloaded > 0)
            IconButton(
              tooltip: 'downloads.delete'.tr(),
              icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: repoAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text('ayah_dl.error'.tr())),
        data: (repo) => FutureBuilder<List<Surah>>(
          future: repo.surahs(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final surahs = snap.data!.where(_matches).toList();
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  sliver: SliverToBoxAdapter(
                    child: _Summary(
                      edition: _edition,
                      progress: progress,
                      locale: locale,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  sliver: SliverToBoxAdapter(
                    child: _SearchAndFilter(
                      filter: _filter,
                      onFilter: (f) => setState(() => _filter = f),
                      onQuery: (v) => setState(() => _query = v),
                    ),
                  ),
                ),
                if (surahs.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text('ayah_dl.none_here'.tr())),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
                    sliver: SliverList.builder(
                      itemCount: surahs.length,
                      itemBuilder: (context, i) => _SurahTile(
                        surah: surahs[i],
                        edition: _edition,
                        locale: locale,
                        playing: _playing == surahs[i].id,
                        onPlay: () => _play(surahs[i]),
                      ),
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

/// The one-glance state of this reciter on the phone, and the one action
/// that state calls for.
class _Summary extends StatelessWidget {
  final String edition;
  final AyahDlProgress progress;
  final String locale;

  const _Summary({
    required this.edition,
    required this.progress,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    final lib = AyahRecitationLibrary.instance;
    final scheme = Theme.of(context).colorScheme;
    final missing = progress.total - progress.downloaded;
    final running = !progress.isComplete &&
        !progress.paused &&
        [for (var s = 1; s <= 114; s++) s]
            .any((s) => lib.isSurahPending(edition, s));

    final String status;
    final Color statusColor;
    Widget? action;
    if (progress.isComplete) {
      status = 'ayah_dl.offline_ready'.tr();
      statusColor = AppColors.success;
    } else if (progress.paused) {
      status = 'ayah_dl.paused'.tr();
      statusColor = AppColors.gold;
      action = FilledButton.icon(
        onPressed: () => lib.resume(edition),
        icon: const Icon(Icons.play_arrow_rounded),
        label: Text('downloads.resume'.tr()),
      );
    } else if (running) {
      status = 'ayah_dl.downloading'.tr();
      statusColor = AppColors.gold;
      action = OutlinedButton.icon(
        onPressed: () => lib.pause(edition),
        icon: const Icon(Icons.pause_rounded),
        label: Text('downloads.pause'.tr()),
      );
    } else {
      status = trn('ayah_dl.remaining', args: ['$missing']);
      statusColor = scheme.onSurfaceVariant;
      action = FilledButton.icon(
        onPressed: () => lib.downloadReciter(edition),
        icon: const Icon(Icons.download_rounded),
        label: Text(
          progress.downloaded == 0
              ? 'ayah_dl.download_reciter'.tr()
              : 'ayah_dl.download_remaining'.tr(),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: scheme.surfaceContainerHighest,
        border: Border.all(
          color: (progress.isComplete ? AppColors.success : AppColors.gold)
              .withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AyahDlRing(value: progress.fraction, locale: locale, size: 64),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ayah_dl.ayahs_progress'.tr(
                        args: [
                          ratio(
                            localizeDigits('${progress.downloaded}', locale),
                            localizeDigits('${progress.total}', locale),
                          ),
                        ],
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 13,
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (action != null) ...[const SizedBox(height: 12), action],
          const SizedBox(height: 8),
          Text(
            'ayah_dl.offline_hint'.tr(),
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _SearchAndFilter extends StatelessWidget {
  final _Filter filter;
  final ValueChanged<_Filter> onFilter;
  final ValueChanged<String> onQuery;

  const _SearchAndFilter({
    required this.filter,
    required this.onFilter,
    required this.onQuery,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          onChanged: onQuery,
          decoration: InputDecoration(
            hintText: 'ayah_dl.search_hint'.tr(),
            prefixIcon: const Icon(Icons.search_rounded),
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 10),
        SegmentedButton<_Filter>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: _Filter.all,
              label: Text('ayah_dl.filter_all'.tr()),
            ),
            ButtonSegment(
              value: _Filter.missing,
              label: Text('ayah_dl.filter_missing'.tr()),
            ),
            ButtonSegment(
              value: _Filter.complete,
              label: Text('ayah_dl.filter_complete'.tr()),
            ),
          ],
          selected: {filter},
          onSelectionChanged: (s) => onFilter(s.first),
        ),
      ],
    );
  }
}

class _SurahTile extends StatelessWidget {
  final Surah surah;
  final String edition;
  final String locale;
  final bool playing;
  final VoidCallback onPlay;

  const _SurahTile({
    required this.surah,
    required this.edition,
    required this.locale,
    required this.playing,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final lib = AyahRecitationLibrary.instance;
    final scheme = Theme.of(context).colorScheme;
    final total = AyahRecitationLibrary.ayahCount(surah.id);
    final have = lib.surahDownloadedCount(edition, surah.id);
    final complete = total > 0 && have >= total;
    final pending = !complete && lib.isSurahPending(edition, surah.id);
    final asked = !complete &&
        !pending &&
        have > 0; // started, and nothing is fetching the rest
    final name = Reciter.arabicScriptLocales.contains(locale)
        ? surah.nameAr
        : surah.nameEn;

    final String subtitle;
    Color subtitleColor = scheme.onSurfaceVariant;
    if (pending) {
      subtitle = 'ayah_dl.downloading'.tr();
      subtitleColor = AppColors.gold;
    } else {
      subtitle = 'ayah_dl.ayahs_progress'.tr(
        args: [
          ratio(
            localizeDigits('$have', locale),
            localizeDigits('$total', locale),
          ),
        ],
      );
      if (asked) subtitleColor = AppColors.gold;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: playing
            ? AppColors.gold.withValues(alpha: 0.14)
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: playing
              ? AppColors.gold
              : (complete
                    ? AppColors.success.withValues(alpha: 0.5)
                    : scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsetsDirectional.fromSTEB(10, 2, 6, 2),
        leading: AyahDlRing(
          value: total == 0 ? 0 : have / total,
          locale: locale,
          size: 42,
        ),
        title: Text(
          '${localizeDigits('${surah.id}', locale)}. $name',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: subtitleColor),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!complete && !pending)
              IconButton(
                tooltip: 'ayah_dl.download_surah'.tr(),
                icon: const Icon(Icons.download_rounded),
                onPressed: () => lib.downloadSurah(edition, surah.id),
              ),
            if (pending)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            // Explicit colours: the tonal style drew a dark icon on a dark
            // disc on the owner's Honor — the play button could not be seen.
            IconButton.filled(
              tooltip: playing ? 'ayah_dl.stop'.tr() : 'ayah_dl.listen'.tr(),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
              ),
              icon: Icon(
                playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
              ),
              onPressed: onPlay,
            ),
          ],
        ),
      ),
    );
  }
}
