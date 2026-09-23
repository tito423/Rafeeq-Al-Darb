/// «في المذاهب الأربعة» under a Hajj step: al-Jaziri's own words on the
/// same rite, the ruling in his body text and each school's position from his
/// notes, folded until asked for.
///
/// «طورها من جديد بوسطية» (2026-09-22). The step above stays al-Nawawi's, a
/// Shafi'i manual; this shows the reader that the four schools are four, in a
/// book written to set them side by side, so no one school's detail is read
/// as the only one. Nothing here is the app's: the text is
/// `assets/data/hajj_madhahib.json`, built verbatim by
/// `scripts/build_hajj_madhahib.py`, which ties each note to its section by
/// the note's own number in the body.
library;

import 'dart:convert';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/arabic_text.dart';

class MadhahibPart {
  final String title;
  final int printedPage;
  final List<String> body;

  /// Each note as its schools' statements, «الحنفية قالوا: …».
  final List<List<String>> notes;

  const MadhahibPart({
    required this.title,
    required this.printedPage,
    required this.body,
    required this.notes,
  });
}

class HajjMadhahib {
  final String sourceTitle;
  final String sourceAuthor;
  final String sourceEdition;
  final Map<String, List<MadhahibPart>> steps;

  const HajjMadhahib({
    required this.sourceTitle,
    required this.sourceAuthor,
    required this.sourceEdition,
    required this.steps,
  });

  factory HajjMadhahib.fromJson(Map<String, dynamic> j) {
    final src = (j['source'] as Map).cast<String, dynamic>();
    final steps = <String, List<MadhahibPart>>{};
    (j['steps'] as Map).forEach((key, parts) {
      steps[key as String] = [
        for (final p in parts as List)
          MadhahibPart(
            title: p['title'] as String,
            printedPage: (p['printed'] as num).toInt(),
            body: [for (final b in p['body'] as List) b as String],
            notes: [
              for (final n in p['notes'] as List)
                [for (final s in n as List) s as String],
            ],
          ),
      ];
    });
    return HajjMadhahib(
      sourceTitle: src['titleAr'] as String,
      sourceAuthor: src['authorAr'] as String,
      sourceEdition: src['edition'] as String,
      steps: steps,
    );
  }
}

final hajjMadhahibProvider = FutureProvider<HajjMadhahib>((ref) async {
  final raw = await rootBundle.loadString('assets/data/hajj_madhahib.json');
  return HajjMadhahib.fromJson(jsonDecode(raw) as Map<String, dynamic>);
});

/// «الحنفية قالوا:» — the school's name, so it can be set apart.
final _school = RegExp(
  r'^(الحنفية|المالكية|الشافعية|الحنابلة)\s*(?:قالوا|قال)\s*[:؛]',
);

class MadhahibSection extends ConsumerWidget {
  final String stepKey;
  final double scale;

  const MadhahibSection({super.key, required this.stepKey, this.scale = 1});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(hajjMadhahibProvider).valueOrNull;
    final parts = data?.steps[stepKey] ?? const <MadhahibPart>[];
    // A step with no counterpart in a book arranged by topic (قبل السفر،
    // النصيحة) shows nothing rather than something near.
    if (data == null || parts.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final k = scale;

    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: const Icon(
          Icons.account_balance_rounded,
          color: AppColors.gold,
        ),
        title: Text(
          'hajj.madhahib_title'.tr(),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          data.sourceTitle,
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final part in parts) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 6),
              child: ArabicText(
                part.title,
                style: TextStyle(
                  fontSize: 16 * k,
                  fontWeight: FontWeight.w800,
                  color: AppColors.gold,
                ),
              ),
            ),
            for (final b in part.body)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ArabicText(
                  b,
                  style: TextStyle(fontSize: 15 * k, height: 1.9),
                ),
              ),
            for (final note in part.notes)
              for (final s in note) _SchoolStatement(text: s, scale: k),
            const Divider(height: 18),
          ],
          // The book's name only - no page, author line or edition, at the
          // owner's word (2026-09-23); the Sources screen has the rest.
          Text(
            data.sourceTitle,
            style: TextStyle(
              fontSize: 11,
              height: 1.6,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SchoolStatement extends StatelessWidget {
  final String text;
  final double scale;
  const _SchoolStatement({required this.text, required this.scale});

  @override
  Widget build(BuildContext context) {
    final m = _school.firstMatch(text);
    final base = TextStyle(fontSize: 15 * scale, height: 1.9);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: m == null
          ? ArabicText(text, style: base)
          : Text.rich(
              TextSpan(
                style: base,
                children: [
                  TextSpan(
                    text: text.substring(0, m.end),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.gold,
                    ),
                  ),
                  TextSpan(text: text.substring(m.end)),
                ],
              ),
              textDirection: TextDirection.rtl,
            ),
    );
  }
}
