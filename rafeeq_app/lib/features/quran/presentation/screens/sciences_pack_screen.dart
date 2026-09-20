import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/db/sciences_repository.dart';
import '../../../../core/services/download_manager.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/byte_formatter.dart' show formatBytes;
import '../../../../core/utils/digits.dart' show localizeDigits, trn, uiLanguageCode;

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
class SciencesPackScreen extends ConsumerWidget {
  const SciencesPackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(sciencesRepositoryProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: Text('quran.sciences_pack'.tr())),
      body: repo == null
          ? _NotHere(onDownload: () => DownloadManager.instance.enqueue(
                id: sciencesDbDownloadId,
                url: AppConfig.sciencesDbUrl,
                category: 'sciences',
                fileName: 'quran_sciences.zip',
                unzipToDatabases: true,
                dbVersion: AppConfig.sciencesDbVersion,
                title: 'quran.sciences_pack'.tr(),
              ))
          : FutureBuilder<SciencesPackContents>(
              future: repo.contents(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return _Contents(data: snap.data!);
              },
            ),
    );
  }
}

class _NotHere extends StatelessWidget {
  final Future<void> Function() onDownload;
  const _NotHere({required this.onDownload});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_stories_outlined,
                  size: 56, color: AppColors.gold),
              const SizedBox(height: 14),
              Text(
                trn('quran.sciences_pack_hint',
                    args: [formatBytes(AppConfig.sciencesDbBytes)]),
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.night,
                ),
                onPressed: onDownload,
                icon: const Icon(Icons.download_rounded),
                label: Text('downloads.download'.tr()),
              ),
            ],
          ),
        ),
      );
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
          trailing: trn('quran.pages_count', args: [_n(data.tafsirs.length)]),
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
                label: 'quran.sciences_words'.tr(),
                value: _n(data.grammarRows)),
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
              Icon(icon, color: AppColors.gold, size: 20),
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
