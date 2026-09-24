import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/quran_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/digits.dart' show localizeDigits;
import '../../../../core/widgets/arabic_text.dart';
import '../../../library/presentation/widgets/listen_text_button.dart';
import '../../data/hajj_guide.dart';
import '../../data/hajj_summary.dart';
import '../../data/hajj_text_scale.dart';

/// «ملخص العمرة» / «ملخص الحج» - the last card of each track: the whole
/// rite, stage by stage, with what is said at each. Every word is the
/// manual's own (`hajj_summary.dart`, checked by `hajj_summary_test.dart`).
class HajjSummaryCard extends ConsumerWidget {
  final HajjTrack track;

  const HajjSummaryCard({super.key, required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stages = track == HajjTrack.umrah ? umrahSummary : hajjSummary;
    final k = ref.watch(hajjTextScaleProvider);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(top: 6, bottom: 10),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppColors.gold.withValues(alpha: 0.6)),
      ),
      child: ExpansionTile(
        shape: const Border(),
        leading: const Icon(Icons.checklist_rtl_rounded, color: AppColors.gold),
        title: Text(
          (track == HajjTrack.umrah
                  ? 'hajj.summary_umrah'
                  : 'hajj.summary_hajj')
              .tr(),
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          'hajj.summary_hint'.tr(),
          style: TextStyle(color: goldText(context), fontSize: 12),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (context.locale.languageCode != 'ar')
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'hajj.arabic_only'.tr(),
                style: TextStyle(
                  fontSize: 11.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ListenTextButton(
            text: () => [
              for (final s in stages) ...[
                s.title,
                for (final l in s.lines)
                  if (l.kind != SummaryKind.ayah) l.text,
              ],
            ].join('\n'),
          ),
          for (final stage in stages) ...[
            const SizedBox(height: 10),
            ArabicText(
              stage.title,
              style: TextStyle(
                fontSize: 17 * k,
                fontWeight: FontWeight.w800,
                color: goldText(context),
              ),
            ),
            const SizedBox(height: 6),
            for (final line in stage.lines) _Line(line: line, scale: k),
          ],
        ],
      ),
    );
  }
}

class _Line extends ConsumerWidget {
  final SummaryLine line;
  final double scale;

  const _Line({required this.line, required this.scale});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = scale;
    switch (line.kind) {
      case SummaryKind.text:
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: ArabicText(
            line.text,
            style: TextStyle(fontSize: 15.5 * k, height: 1.85),
          ),
        );
      case SummaryKind.dhikr:
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primarySoft.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primarySoft.withValues(alpha: 0.35),
            ),
          ),
          child: ArabicText(
            line.text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17 * k,
              height: 1.9,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      case SummaryKind.ayah:
        // From the mushaf text, not the book (see hajj_summary.dart).
        return FutureBuilder<String>(
          future: _ayahs(ref),
          builder: (context, snap) {
            final text = snap.data;
            if (text == null || text.isEmpty) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ArabicText(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'AmiriQuran',
                  fontSize: 19 * k,
                  height: 2,
                ),
              ),
            );
          },
        );
    }
  }

  Future<String> _ayahs(WidgetRef ref) async {
    final repo = await ref.read(quranRepositoryProvider.future);
    final all = await repo.ayahsOfSurah(line.surah);
    return [
      for (final a in all)
        if (a.ayahNumber >= line.fromAyah && a.ayahNumber <= line.toAyah)
          '${a.textUthmani} ﴿${localizeDigits('${a.ayahNumber}', 'ar')}﴾',
    ].join(' ');
  }
}
