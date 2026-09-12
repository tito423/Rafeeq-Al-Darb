import 'dart:async';

// easy_localization re-exports package:intl, whose `TextDirection` (LTR/RTL)
// collides with the `dart:ui` enum (rtl/ltr) used throughout this file.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/models.dart';
import '../../../../core/db/quran_repository.dart';
import '../../../../core/db/sciences_repository.dart';
import '../../../../core/theme/app_colors.dart';
import 'ayah_sciences/ayah_panel.dart';
import 'ayah_sciences/irab_tab.dart';
import 'ayah_sciences/sciences_common.dart';
import 'ayah_sciences/sciences_header.dart';
import 'ayah_sciences/tafseer_tab.dart';
import 'ayah_sciences/translation_tab.dart';

/// "علوم الآية" — tafsir, translation, i'rab and word meanings for one ayah,
/// served straight from the bundled quran_sciences.db so the whole card works
/// with no network.
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

  late final Future<Map<String, String>> _tafseer;
  late final Future<Map<String, AyahTranslation>> _translations;
  late final Future<List<WordGrammar>> _grammar;

  /// «حط جنب زر تلاوة الآية زر تكبير لخيارات الآية بحيث يملى الشاشة كلها لأن
  /// التفسير بتبقى مساحة عرضه صغيرة».
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(sciencesRepositoryProvider.future);
    final s = widget.ayah.surahId;
    final a = widget.ayah.ayahNumber;
    _tafseer = repo.then((r) => r.tafseerForAyah(s, a));
    _translations = repo.then((r) => r.translationsForAyah(s, a));
    _grammar = repo.then((r) => r.wordGrammar(s, a));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = AppColors.gold;

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
              SciencesHeader(
                surahNameAr: widget.surahNameAr,
                ayah: widget.ayah,
                quranRepo: widget.quranRepo,
                translationsFuture: _translations,
                expanded: _expanded,
                onToggleExpand: () => setState(() => _expanded = !_expanded),
              ),
              AyahPanel(ayah: widget.ayah),
              if (!widget.sciencesAvailable)
                Expanded(
                  child: SciencesNotice(
                    icon: Icons.info_outline,
                    message: 'quran.sciences_unavailable_here'.tr(),
                  ),
                )
              else ...[
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
                      TafseerTab(future: _tafseer),
                      TranslationTab(
                          ayah: widget.ayah, future: _translations),
                      IrabTab(ayah: widget.ayah, future: _grammar),
                    ],
                  ),
                ),
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
