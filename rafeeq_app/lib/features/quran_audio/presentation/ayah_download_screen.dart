import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../downloads/data/reciters_provider.dart';
import '../data/ayah_recitation_library.dart';

/// «تنزيل تلاوات آية بآية» — download per-ayah recitation files for offline
/// listening. Only reciters with a verified everyayah.com mirror are offered.
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
    final available = AyahRecitationLibrary.availableEditions;

    return Scaffold(
      appBar: AppBar(
        title: Text('ayah_dl.title'.tr()),
      ),
      body: Consumer(
        builder: (context, ref, _) {
          final recitersAsync = ref.watch(recitersProvider);

          return recitersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(child: Text('ayah_dl.error'.tr())),
            data: (allReciters) {
              // Filter to only those with verified everyayah mirrors.
              final reciters = allReciters.where(
                (r) => available.contains(r.identifier),
              ).toList();

              if (reciters.isEmpty) {
                return Center(child: Text('ayah_dl.no_reciters'.tr()));
              }

              final locale = context.locale.languageCode;

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
                itemCount: reciters.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final reciter = reciters[index];
                  final progress = lib.progressOf(reciter.identifier);

                  return _ReciterCard(
                    reciter: reciter,
                    progress: progress,
                    locale: locale,
                    onDownload: () => _download(reciter.identifier),
                    onPause: () => lib.pause(reciter.identifier),
                    onResume: () => lib.resume(reciter.identifier),
                    onDelete: () => _confirmDelete(context, reciter),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _download(String edition) async {
    final count = await AyahRecitationLibrary.instance
        .downloadReciter(edition);
    if (mounted && count > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'ayah_dl.started'.tr(args: [count.toString()]),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, Reciter reciter) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text('ayah_dl.delete_confirm'.tr()),
        content: Text(reciter.displayName(context.locale.languageCode)),
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
      await AyahRecitationLibrary.instance
          .deleteReciter(reciter.identifier);
    }
  }
}

class _ReciterCard extends StatelessWidget {
  final Reciter reciter;
  final AyahDlProgress progress;
  final String locale;
  final VoidCallback onDownload;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onDelete;

  const _ReciterCard({
    required this.reciter,
    required this.progress,
    required this.locale,
    required this.onDownload,
    required this.onPause,
    required this.onResume,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hasAny = progress.downloaded > 0;
    final isComplete = progress.isComplete;

    return Card(
      color: AppColors.nightElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isComplete
            ? const BorderSide(color: AppColors.success, width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isComplete
                      ? Icons.check_circle_rounded
                      : Icons.record_voice_over_outlined,
                  color: isComplete ? AppColors.success : AppColors.gold,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    reciter.displayName(locale),
                    style: const TextStyle(
                      color: AppColors.textHigh,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (hasAny && !isComplete && !progress.paused)
                  IconButton(
                    icon: const Icon(Icons.pause_circle_outline_rounded),
                    color: AppColors.textMedium,
                    tooltip: 'downloads.pause'.tr(),
                    onPressed: onPause,
                  ),
                if (progress.paused)
                  IconButton(
                    icon: const Icon(Icons.play_circle_outline_rounded),
                    color: AppColors.primarySoft,
                    tooltip: 'downloads.resume'.tr(),
                    onPressed: onResume,
                  ),
                if (hasAny)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: AppColors.error,
                    tooltip: 'downloads.delete'.tr(),
                    onPressed: onDelete,
                  ),
              ],
            ),
            if (hasAny) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress.fraction,
                  backgroundColor: AppColors.nightBorder,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isComplete ? AppColors.success : AppColors.primarySoft,
                  ),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    '${progress.downloaded} / ${progress.total}',
                    style: const TextStyle(
                      color: AppColors.textMedium,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  if (isComplete)
                    Text(
                      'ayah_dl.offline_ready'.tr(),
                      style: const TextStyle(
                        color: AppColors.success,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else if (progress.paused)
                    Text(
                      'downloads.paused'.tr(),
                      style: const TextStyle(
                        color: AppColors.textLow,
                        fontSize: 13,
                      ),
                    )
                  else
                    Text(
                      'ayah_dl.downloading'.tr(),
                      style: const TextStyle(
                        color: AppColors.primarySoft,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ],
            if (!hasAny) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onDownload,
                  icon: const Icon(Icons.download_rounded),
                  label: Text('ayah_dl.download_reciter'.tr()),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryContainer,
                    foregroundColor: AppColors.textHigh,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
