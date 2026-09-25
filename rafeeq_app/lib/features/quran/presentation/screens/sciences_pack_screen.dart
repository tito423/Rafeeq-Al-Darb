import '../../../../core/utils/digits.dart' show percentOf;
import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/db/sciences_repository.dart';
import '../../../../core/services/download_manager.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/byte_formatter.dart' show formatBytes;
import '../../../../core/utils/digits.dart'
    show localizeDigits, pluralN, trn, uiLanguageCode;
import '../../../../core/widgets/error_retry.dart';

/// What علوم القرآن actually contains, once it is on the device.
///
/// «علوم القران خليها تعرضلي بشكل جميل ايه اللي نزلته سواء التفاسير او
/// الاعراب او الترجمة». The storage hub could say «١٣١.٧ MB» and no more, and
/// a reader who had spent 33 MB had no way to see what he had bought with it.
///
/// Every number here is COUNTED from the database in front of you, not
/// written down: seven tafsirs by name with their verse counts, the
/// translations by language, and the two word-level layers. Nothing is
/// claimed that the file does not hold.
/// «علوم القران صفحة تحميلها بتعلق ومش بتتحدث ومش فيها اي حاجة» (2026-09-21).
///
/// Three separate defects, all of them in how this screen read its own state:
///
///  1. It watched the provider with `.valueOrNull`, which returns null while
///     the provider is still LOADING and again when it has ERRORED. Opening a
///     131.68 MB database is not instant, so the first thing the screen drew
///     was the download gate for a pack that was already installed - and if
///     the open threw, that gate was all you ever got, with nothing said.
///  2. Tapping «تحميل» enqueued the transfer and then nothing on this screen
///     ever rebuilt. No progress, no percentage, no change when it finished:
///     the page sat on the same button for the whole download. That is the
///     «بتعلق ومش بتتحدث» exactly - it was not hung, it was deaf.
///  3. The contents were read through `if (!snap.hasData) return spinner`,
///     so a throw out of `contents()` rendered as a spinner that never
///     stopped - the same shape as the `FutureView` bug that hid a broken
///     Nasa'i collection behind a loading indicator.
///
/// It now subscribes to [DownloadManager.stream] for as long as it is on
/// screen, draws queued/downloading/failed as themselves, invalidates the
/// repository the moment the transfer completes, and shows an error as an
/// error.
class SciencesPackScreen extends ConsumerStatefulWidget {
  const SciencesPackScreen({super.key});

  @override
  ConsumerState<SciencesPackScreen> createState() => _SciencesPackScreenState();
}

class _SciencesPackScreenState extends ConsumerState<SciencesPackScreen> {
  StreamSubscription<List<DownloadTask>>? _sub;
  DownloadStatus? _last;

  @override
  void initState() {
    super.initState();
    _sub = DownloadManager.instance.stream.listen((_) {
      if (!mounted) return;
      final status =
          DownloadManager.instance.taskById(sciencesDbDownloadId)?.status;
      // The unzip has already run by the time `completed` is emitted, so the
      // database is on disk and re-reading the provider opens it.
      if (status == DownloadStatus.completed &&
          _last != DownloadStatus.completed) {
        ref.invalidate(sciencesRepositoryProvider);
      }
      _last = status;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _download() => DownloadManager.instance.enqueue(
        id: sciencesDbDownloadId,
        url: AppConfig.sciencesDbUrl,
        category: 'sciences',
        fileName: 'quran_sciences.zip',
        unzipToDatabases: true,
        dbVersion: AppConfig.sciencesDbVersion,
        title: 'quran.sciences_pack'.tr(),
      );

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(sciencesRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: Text('quran.sciences_pack'.tr())),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorRetry(
            onRetry: () => ref.invalidate(sciencesRepositoryProvider)),
        data: (repo) => repo == null
            ? _NotHere(onDownload: _download)
            : FutureBuilder<SciencesPackContents>(
                future: repo.contents(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return ErrorRetry(
                        onRetry: () =>
                            ref.invalidate(sciencesRepositoryProvider));
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return _Contents(data: snap.data!);
                },
              ),
      ),
    );
  }
}

/// The gate, with the transfer's own state on it.
class _NotHere extends StatelessWidget {
  final Future<void> Function() onDownload;
  const _NotHere({required this.onDownload});

  @override
  Widget build(BuildContext context) {
    final task = DownloadManager.instance.taskById(sciencesDbDownloadId);
    final busy = task != null &&
        (task.status == DownloadStatus.downloading ||
            task.status == DownloadStatus.queued);
    final failed = task?.status == DownloadStatus.failed;
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_stories_outlined, size: 56, color: goldText(context)),
            const SizedBox(height: 14),
            Text(
              trn('quran.sciences_pack_hint',
                  args: [formatBytes(AppConfig.sciencesDbBytes)]),
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            if (busy) ...[
              LinearProgressIndicator(
                value: task.total == null ? null : task.progress,
                color: AppColors.gold,
              ),
              const SizedBox(height: 10),
              Text(
                task.total != null
                    ? localizeDigits(
                        percentOf(task.progress), uiLanguageCode)
                    : 'downloads.download'.tr(),
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ] else ...[
              if (failed && task?.error != null) ...[
                Text(
                  task!.error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.error, fontSize: 12),
                ),
                const SizedBox(height: 12),
              ],
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.night,
                ),
                onPressed: onDownload,
                icon: Icon(
                    failed ? Icons.refresh_rounded : Icons.download_rounded),
                label: Text(
                    failed ? 'common.retry'.tr() : 'downloads.download'.tr()),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Contents extends StatelessWidget {
  final SciencesPackContents data;
  const _Contents({required this.data});

  String _n(int n) => localizeDigits('$n', uiLanguageCode);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _Section(
          icon: Icons.menu_book_rounded,
          title: 'quran.tafseer'.tr(),
          // `pluralN`, not `trn`. THE GREY PAGE: `quran.pages_count` is a
          // plural object - six CLDR categories - and `tr()` on a key whose
          // value is a Map returns the Map, so this line threw
          // «type '_Map<String, dynamic>' is not a subtype of type 'String'»
          // every single time the screen had a pack to describe. In a
          // release build Flutter draws a thrown build as `RenderErrorBox`,
          // which paints a flat `Color(0xF0C0C0C0)` rectangle and no text -
          // the owner's «بتطلع صفحة رصاصي», photographed at 12:53 with the
          // pack installed. Seen as the red debug error box on
          // emulator-5554 before this line changed.
          //
          // And it is a count of SOURCES, not of pages: «٧ صفحات» under
          // «التفسير» would have been wrong copy even when it rendered.
          trailing: pluralN('quran.sources_count', data.tafsirs.length),
          children: [
            for (final t in data.tafsirs)
              _Row(label: t.$1, value: trn('quran.ayah_count', args: [_n(t.$2)])),
          ],
        ),
        _Section(
          icon: Icons.translate_rounded,
          title: 'quran.translation'.tr(),
          children: [
            for (final t in data.translations)
              _Row(label: t.$1, value: trn('quran.ayah_count', args: [_n(t.$2)])),
          ],
        ),
        _Section(
          icon: Icons.account_tree_outlined,
          title: 'quran.irab'.tr(),
          children: [
            _Row(
                label: 'quran.irab_book'.tr(),
                value: trn('quran.ayah_count', args: [_n(data.irabAyahs)])),
          ],
        ),
        _Section(
          icon: Icons.spellcheck_rounded,
          title: 'quran.meanings'.tr(),
          children: [
            _Row(
                label: 'quran.sciences_words'.tr(),
                value: _n(data.meaningRows)),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          trn('quran.sciences_pack_hint',
              args: [formatBytes(AppConfig.sciencesDbBytes)]),
          textAlign: TextAlign.center,
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailing;
  final List<Widget> children;
  const _Section({
    required this.icon,
    required this.title,
    required this.children,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: goldText(context), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              if (trailing != null)
                Text(trailing!,
                    style: TextStyle(
                        color: scheme.onSurfaceVariant, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              value,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
}
