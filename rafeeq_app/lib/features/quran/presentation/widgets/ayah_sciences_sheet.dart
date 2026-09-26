import 'dart:async';

// easy_localization re-exports package:intl, whose `TextDirection` (LTR/RTL)
// collides with the `dart:ui` enum (rtl/ltr) used throughout this file.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/db/models.dart';
import '../../../../core/db/quran_repository.dart';
import '../../../../core/db/sciences_repository.dart';
import '../../../../core/services/download_manager.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/digits.dart' show trn, percentOf;
import '../../../../core/utils/byte_formatter.dart' show formatBytes;
import 'ayah_sciences/ayah_panel.dart';
import 'ayah_sciences/irab_tab.dart';
import 'ayah_sciences/sciences_common.dart';
import 'ayah_sciences/sciences_header.dart';
import 'ayah_sciences/tafseer_tab.dart';
import 'ayah_sciences/translation_tab.dart';

/// "علوم الآية" — tafsir, translation, i'rab and word meanings for one ayah.
///
/// Its database was bundled until 3.44.0; it is 131.68 MB and now downloads
/// (31.70 MB packed) the first time a reader opens this card. Until then the
/// card shows [_SciencesPackGate] — the ayah itself, and an offer — rather
/// than an error or a spinner that never ends.
class AyahSciencesSheet extends ConsumerStatefulWidget {
  final Ayah ayah;
  final String surahNameAr;
  final QuranRepository quranRepo;

  /// False when the mushaf being read numbers this surah differently from the
  /// sciences database, in which case Hafs-keyed tafsir, translation and i'rab
  /// would belong to a different verse and must not be shown.
  final bool sciencesAvailable;

  const AyahSciencesSheet({
    super.key,
    required this.ayah,
    required this.surahNameAr,
    required this.quranRepo,
    this.sciencesAvailable = true,
  });

  static Future<void> show(
    BuildContext context, {
    required Ayah ayah,
    required String surahNameAr,
    required QuranRepository quranRepo,
    bool sciencesAvailable = true,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // The sheet draws its own handle (and hides it when expanded); the
      // theme's default one put a second bar above it.
      showDragHandle: false,
      // Sideways, wider than Material's 640 dp so its two columns (see
      // `build`) each have room.
      constraints: MediaQuery.orientationOf(context) == Orientation.landscape
          ? BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.94)
          : null,
      builder: (_) => AyahSciencesSheet(
        ayah: ayah,
        surahNameAr: surahNameAr,
        quranRepo: quranRepo,
        sciencesAvailable: sciencesAvailable,
      ),
    );
  }

  @override
  ConsumerState<AyahSciencesSheet> createState() => _AyahSciencesSheetState();
}

class _AyahSciencesSheetState extends ConsumerState<AyahSciencesSheet>
    with SingleTickerProviderStateMixin {
  // 4 tabs: Tafseer, Translation, I'rab, Gharib al-Quran (word meanings).
  // The 4th tab (Gharib al-Quran) uses Quran.com API v4 word-by-word data
  // to show each word's Arabic meaning alongside the Uthmani script.
  late final TabController _tabs = TabController(length: 3, vsync: this);

  /// Built once, the first frame on which the pack is actually open. They
  /// stay null while it is missing, which is what the gate renders.
  Future<Map<String, String>>? _tafseer;
  Future<Map<String, AyahTranslation>>? _translations;
  Future<IrabSection?>? _irab;

  /// The gate redraws on every progress tick, the way the hadith tab's does.
  StreamSubscription<List<DownloadTask>>? _downloads;

  /// «حط جنب زر تلاوة الآية زر تكبير لخيارات الآية بحيث يملى الشاشة كلها لأن
  /// التفسير بتبقى مساحة عرضه صغيرة».
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _downloads = DownloadManager.instance.stream.listen((_) {
      if (!mounted) return;
      // TRAP #27, caught on emulator-5554 before this line existed: the pack
      // downloaded, `_unzipToDatabases` wrote the 138,080,256-byte file and
      // its version stamp, and the card still said «تحميل» - for ever. The
      // provider had already resolved to null and Riverpod had no reason to
      // ask again. Watching a stream is not the same as re-reading the disk.
      final task = DownloadManager.instance.taskById(sciencesDbDownloadId);
      if (task?.status == DownloadStatus.completed && _tafseer == null) {
        ref.invalidate(sciencesRepositoryProvider);
      }
      setState(() {});
    });
  }

  void _bindRepo(SciencesRepository repo) {
    if (_tafseer != null) return;
    final s = widget.ayah.surahId;
    final a = widget.ayah.ayahNumber;
    _tafseer = repo.tafseerForAyah(s, a);
    _translations = repo.translationsForAyah(s, a);
    _irab = repo.irabForAyah(s, a);
  }

  Future<void> _startDownload() async {
    await DownloadManager.instance.enqueue(
      id: sciencesDbDownloadId,
      url: AppConfig.sciencesDbUrl,
      category: 'sciences',
      // Named after the database it becomes - trap #27.
      fileName: 'quran_sciences.zip',
      unzipToDatabases: true,
      dbVersion: AppConfig.sciencesDbVersion,
      title: 'quran.sciences_pack'.tr(),
    );
  }

  @override
  void dispose() {
    _downloads?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = AppColors.gold;
    final repo = ref.watch(sciencesRepositoryProvider).valueOrNull;
    if (repo != null) _bindRepo(repo);
    final ready = _tafseer != null;
    // SIDEWAYS, TWO COLUMNS: the ayah and its controls on one side, the
    // tafsir / translation / i'rab on the other at the sheet's full height.
    // Stacked, on emulator-5554 held sideways (2026-09-26), the header, the
    // ayah and the tab row left the i'rab about 225 dp of 540.
    final sideways =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final head = <Widget>[
      SciencesHeader(
        surahNameAr: widget.surahNameAr,
        ayah: widget.ayah,
        quranRepo: widget.quranRepo,
        translationsFuture: _translations ??
            Future<Map<String, AyahTranslation>>.value(const {}),
        expanded: _expanded,
        onToggleExpand: () => setState(() => _expanded = !_expanded),
      ),
      AyahPanel(ayah: widget.ayah),
    ];
    final Widget content = !widget.sciencesAvailable
        ? SciencesNotice(
            icon: Icons.info_outline,
            message: 'quran.sciences_unavailable_here'.tr(),
          )
        : !ready
            ? _SciencesPackGate(onDownload: _startDownload)
            : Column(
                children: [
                  TabBar(
                    controller: _tabs,
                    isScrollable: true,
                    tabAlignment: TabAlignment.center,
                    indicatorColor: gold,
                    labelColor: gold,
                    dividerColor: gold.withValues(alpha: 0.18),
                    tabs: [
                      Tab(text: 'quran.tafseer'.tr()),
                      Tab(text: 'quran.translation'.tr()),
                      Tab(text: 'quran.irab'.tr()),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabs,
                      children: [
                        TafseerTab(future: _tafseer!),
                        TranslationTab(
                            ayah: widget.ayah, future: _translations!),
                        IrabTab(ayah: widget.ayah, future: _irab!),
                      ],
                    ),
                  ),
                ],
              );

    return SafeArea(
      top: _expanded,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: _expanded ? 1.0 : 0.92),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        builder: (context, factor, child) =>
            FractionallySizedBox(heightFactor: factor, child: child),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.vertical(
                top: Radius.circular(_expanded ? 0 : 28)),
            border: Border(top: BorderSide(color: gold.withValues(alpha: 0.45))),
          ),
          child: Column(
            children: [
              if (!_expanded) const _DragHandle(),
              if (sideways)
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: SingleChildScrollView(
                          child: Column(children: head),
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(flex: 3, child: content),
                    ],
                  ),
                )
              else ...[
                ...head,
                Expanded(child: content),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 4,
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(2),
        ),
      );
}


/// Shown in place of the three tabs while علوم القرآن has not been
/// downloaded. It tells the reader the real size before he spends it -
/// `AppConfig.sciencesDbBytes`, measured against the bucket, not written by
/// hand - and `formatBytes` wraps the figure in an LTR isolate so «31.7 MB»
/// does not come out «MB 31.7» inside an Arabic sentence (trap #16).
class _SciencesPackGate extends StatelessWidget {
  final Future<void> Function() onDownload;
  const _SciencesPackGate({required this.onDownload});

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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_stories_outlined, size: 56, color: scheme.primary),
            const SizedBox(height: 14),
            Text('quran.sciences_pack'.tr(),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
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
              const SizedBox(height: 8),
              Text(task.total != null
                  ? percentOf(task.progress)
                  : 'quran.sciences_pack'.tr()),
            ] else
              FilledButton.icon(
                onPressed: onDownload,
                icon: const Icon(Icons.download_rounded),
                label: Text('downloads.download'.tr()),
              ),
            if (failed) ...[
              const SizedBox(height: 8),
              Text(task?.error ?? 'errors.generic'.tr(),
                  style: TextStyle(color: scheme.error)),
            ],
          ],
        ),
      ),
    );
  }
}
