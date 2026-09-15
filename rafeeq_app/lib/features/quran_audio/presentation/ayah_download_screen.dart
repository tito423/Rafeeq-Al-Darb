/// «تلاوات آية بآية» — per-ayah recitation downloads, redesigned.
///
/// «تلاوة اية باية غير تصميمها لانها اصلا مش بتعرض هو بيحمل». The first
/// version was one card per reciter with a single «download all 6,236 ayahs»
/// button and a bar: it never showed WHAT was on the phone, a surah could not
/// be taken on its own, and nothing downloaded could be played from here. So:
///
///  * the reciters list shows, for each, a ring of how much is on the phone
///    and how many surahs are complete;
///  * a reciter opens onto his 114 surahs, each with its own ring, its own
///    download button, and a listen button that plays it ayah by ayah — from
///    the files on the phone when they are there (`RecitationSource.urlsFor`
///    prefers the local file), so a complete surah plays offline.
library;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/models.dart';
import '../../../core/services/ayah_audio_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/digits.dart';
import '../../downloads/data/reciters_provider.dart';
import '../../../core/db/quran_repository.dart';
import '../data/ayah_recitation_library.dart';

class AyahDownloadScreen extends StatefulWidget {
  const AyahDownloadScreen({super.key});

  @override
  State<AyahDownloadScreen> createState() => _AyahDownloadScreenState();
}

class _AyahDownloadScreenState extends State<AyahDownloadScreen> {
  @override
  void initState() {
    super.initState();
    AyahRecitationLibrary.instance.ensureReady();
    AyahRecitationLibrary.instance.addListener(_rebuild);
  }

  @override
  void dispose() {
    AyahRecitationLibrary.instance.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final lib = AyahRecitationLibrary.instance;
    final available = AyahRecitationLibrary.availableEditions.toSet();
    final locale = context.locale.languageCode;

    return Scaffold(
      appBar: AppBar(title: Text('ayah_dl.title'.tr())),
      body: Consumer(
        builder: (context, ref, _) {
          final recitersAsync = ref.watch(recitersProvider);
          return recitersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(child: Text('ayah_dl.error'.tr())),
            data: (all) {
              final reciters =
                  all.where((r) => available.contains(r.identifier)).toList()
                    // What is already on the phone first.
                    ..sort((a, b) => lib
                        .downloadedCount(b.identifier)
                        .compareTo(lib.downloadedCount(a.identifier)));
              if (reciters.isEmpty) {
                return Center(child: Text('ayah_dl.no_reciters'.tr()));
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
                itemCount: reciters.length + 1,
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        'ayah_dl.choose_reciter'.tr(),
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant),
                      ),
                    );
                  }
                  final r = reciters[i - 1];
                  return _ReciterTile(
                    reciter: r,
                    locale: locale,
                    onOpen: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => _ReciterSurahsScreen(reciter: r),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// A progress ring with its percentage (or a tick) inside.
class _Ring extends StatelessWidget {
  final double value;
  final double size;
  final String locale;

  const _Ring({required this.value, required this.locale, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final complete = value >= 1;
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => Stack(
          fit: StackFit.expand,
          children: [
            CircularProgressIndicator(
              value: v,
              strokeWidth: size * 0.09,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                  complete ? AppColors.success : AppColors.gold),
            ),
            Center(
              child: complete
                  ? Icon(Icons.check_rounded,
                      color: AppColors.success, size: size * 0.45)
                  : Text(
                      localizeDigits('${(v * 100).round()}%', locale),
                      style: TextStyle(
                          fontSize: size * 0.24, fontWeight: FontWeight.w800),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReciterTile extends StatelessWidget {
  final Reciter reciter;
  final String locale;
  final VoidCallback onOpen;

  const _ReciterTile({
    required this.reciter,
    required this.locale,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final lib = AyahRecitationLibrary.instance;
    final scheme = Theme.of(context).colorScheme;
    final downloaded = lib.downloadedCount(reciter.identifier);
    var complete = 0;
    if (downloaded > 0) {
      for (var s = 1; s <= 114; s++) {
        if (lib.surahDownloadedCount(reciter.identifier, s) ==
            AyahRecitationLibrary.ayahCount(s)) {
          complete++;
        }
      }
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _Ring(
                value: downloaded / AyahRecitationLibrary.totalAyahs,
                locale: locale,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(reciter.displayName(locale),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      'ayah_dl.surahs_done'
                          .tr(args: [localizeDigits('$complete', locale)]),
                      style: TextStyle(
                          fontSize: 12.5, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReciterSurahsScreen extends ConsumerStatefulWidget {
  final Reciter reciter;
  const _ReciterSurahsScreen({required this.reciter});

  @override
  ConsumerState<_ReciterSurahsScreen> createState() =>
      _ReciterSurahsScreenState();
}

class _ReciterSurahsScreenState extends ConsumerState<_ReciterSurahsScreen> {
  String _query = '';

  /// The surah whose recitation this screen started, while it plays.
  int? _playing;

  String get _edition => widget.reciter.identifier;

  @override
  void initState() {
    super.initState();
    AyahRecitationLibrary.instance.addListener(_rebuild);
  }

  @override
  void dispose() {
    AyahRecitationLibrary.instance.removeListener(_rebuild);
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
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('downloads.delete'.tr()),
          ),
        ],
      ),
    );
    if (ok == true) {
      await AyahRecitationLibrary.instance.deleteReciter(_edition);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lib = AyahRecitationLibrary.instance;
    final locale = context.locale.languageCode;
    final scheme = Theme.of(context).colorScheme;
    final progress = lib.progressOf(_edition);
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
            final q = _query.trim();
            final surahs = snap.data!
                .where((s) =>
                    q.isEmpty ||
                    s.nameAr.contains(q) ||
                    s.nameEn.toLowerCase().contains(q.toLowerCase()) ||
                    '${s.id}' == asciiDigits(q))
                .toList();
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
              itemCount: surahs.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return _SummaryCard(
                    edition: _edition,
                    progress: progress,
                    locale: locale,
                    onQuery: (v) => setState(() => _query = v),
                  );
                }
                final s = surahs[i - 1];
                return _SurahTile(
                  surah: s,
                  edition: _edition,
                  locale: locale,
                  playing: _playing == s.id,
                  onPlay: () => _play(s),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String edition;
  final AyahDlProgress progress;
  final String locale;
  final ValueChanged<String> onQuery;

  const _SummaryCard({
    required this.edition,
    required this.progress,
    required this.locale,
    required this.onQuery,
  });

  @override
  Widget build(BuildContext context) {
    final lib = AyahRecitationLibrary.instance;
    final scheme = Theme.of(context).colorScheme;
    final downloading = !progress.isComplete &&
        !progress.paused &&
        progress.downloaded > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            AppColors.gold.withValues(alpha: 0.16),
            scheme.surfaceContainerHighest,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Ring(
                value: progress.fraction,
                locale: locale,
                size: 64,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ayah_dl.ayahs_progress'.tr(args: [
                        localizeDigits('${progress.downloaded}', locale),
                        localizeDigits('${progress.total}', locale),
                      ]),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text('ayah_dl.offline_hint'.tr(),
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: progress.isComplete
                    ? Text('ayah_dl.offline_ready'.tr(),
                        style: const TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w700))
                    : FilledButton.icon(
                        onPressed: () => lib.downloadReciter(edition),
                        icon: const Icon(Icons.download_rounded),
                        label: Text('ayah_dl.download_reciter'.tr()),
                      ),
              ),
              if (downloading)
                IconButton.filledTonal(
                  tooltip: 'downloads.pause'.tr(),
                  onPressed: () => lib.pause(edition),
                  icon: const Icon(Icons.pause_rounded),
                ),
              if (progress.paused)
                IconButton.filledTonal(
                  tooltip: 'downloads.resume'.tr(),
                  onPressed: () => lib.resume(edition),
                  icon: const Icon(Icons.play_arrow_rounded),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            onChanged: onQuery,
            decoration: InputDecoration(
              hintText: 'ayah_dl.search_hint'.tr(),
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
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
    final pending = lib.isSurahPending(edition, surah.id) && have < total;
    final complete = total > 0 && have >= total;
    final name = Reciter.arabicScriptLocales.contains(locale)
        ? surah.nameAr
        : surah.nameEn;

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
        leading: _Ring(
          value: total == 0 ? 0 : have / total,
          locale: locale,
          size: 42,
        ),
        title: Text(
          '${localizeDigits('${surah.id}', locale)}. $name',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          pending
              ? 'ayah_dl.downloading'.tr()
              : 'ayah_dl.ayahs_progress'.tr(args: [
                  localizeDigits('$have', locale),
                  localizeDigits('$total', locale),
                ]),
          style: TextStyle(
              fontSize: 12,
              color: pending ? AppColors.gold : scheme.onSurfaceVariant),
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
            IconButton.filledTonal(
              tooltip: playing ? 'ayah_dl.stop'.tr() : 'ayah_dl.listen'.tr(),
              icon: Icon(playing ? Icons.stop_rounded : Icons.play_arrow_rounded),
              onPressed: onPlay,
            ),
          ],
        ),
      ),
    );
  }
}
