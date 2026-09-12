/// «الإعراب ومعاني الكلمات» — the word-by-word grammar cards.
library;

import 'dart:async';

// easy_localization re-exports package:intl, whose `TextDirection` (LTR/RTL)
// collides with the `dart:ui` enum (rtl/ltr) used throughout this file.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/db/models.dart';
import '../../../../../core/services/quran_api_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../data/quran_grammar_parser.dart';
import 'sciences_common.dart';

/// Corpus morphology & syntax, one structured card per word:
/// Part of speech, grammatical case, root, morphemes tree, and wbw translation.
class IrabTab extends ConsumerStatefulWidget {
  final Ayah ayah;
  final Future<List<WordGrammar>> future;
  const IrabTab({super.key, required this.ayah, required this.future});

  @override
  ConsumerState<IrabTab> createState() => IrabTabState();
}

class IrabTabState extends ConsumerState<IrabTab> {
  late final Future<List<QuranWordWbw>> _wbwFuture;

  @override
  void initState() {
    super.initState();
    _wbwFuture = ref.read(quranApiServiceProvider).getAyahWordsWbw(
          widget.ayah.surahId,
          widget.ayah.ayahNumber,
        );
  }

  @override
  Widget build(BuildContext context) {
    return AsyncTab<List<WordGrammar>>(
      future: widget.future,
      isEmpty: (d) => d.isEmpty,
      builder: (context, localList) {
        return FutureBuilder<List<QuranWordWbw>>(
          future: _wbwFuture,
          builder: (context, wbwSnap) {
            final wbwList = wbwSnap.data ?? const <QuranWordWbw>[];
            final wbwMap = {for (final w in wbwList) w.position: w};

            final parsedItems = localList.map((g) {
              final wbw = wbwMap[g.pos];
              return QuranGrammarParser.parse(local: g, wbw: wbw);
            }).toList();

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
              itemCount: parsedItems.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                return _GrammarCard(item: parsedItems[i]);
              },
            );
          },
        );
      },
    );
  }
}

/// A structured, elegant grammar card for a single Quranic word.
class _GrammarCard extends StatelessWidget {
  final WordSyntaxData item;
  const _GrammarCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final gold = AppColors.gold;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: gold.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Word + Position + POS Badge
          Row(
            children: [
              // Position pill
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: gold.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${item.position}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: gold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // POS badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.posLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: gold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),

              // Word Token (Uthmani)
              Text(
                item.token,
                textDirection: TextDirection.rtl,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontFamily: 'AmiriQuran',
                  color: gold,
                  fontSize: 22,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Grammatical Case & Role Detail
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.account_tree_outlined,
                  size: 16,
                  color: gold.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.caseDetail,
                    textDirection: TextDirection.rtl,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Morphemes Tree / Decomposition (if available)
          if (item.segments.length > 1) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.end,
              children: item.segments.map((seg) {
                final isStem = seg.type == MorphemeType.stem;
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isStem
                        ? gold.withValues(alpha: 0.12)
                        : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isStem
                          ? gold.withValues(alpha: 0.35)
                          : scheme.outlineVariant.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    '${seg.text} (${seg.label})',
                    textDirection: TextDirection.rtl,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isStem ? gold : scheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          // Root & Lemma Chips
          if (item.rootFormatted != null || item.lemmaFormatted != null) ...[
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 6,
              children: [
                if (item.rootFormatted != null)
                  _Chip(
                    icon: Icons.grass_outlined,
                    label: 'quran.root'.tr(),
                    value: item.rootFormatted!,
                  ),
                if (item.lemmaFormatted != null)
                  _Chip(
                    icon: Icons.menu_book_outlined,
                    label: 'quran.word'.tr(),
                    value: item.lemmaFormatted!,
                  ),
              ],
            ),
          ],

          // Word-by-Word Translation & Transliteration (from Quran.com API v4)
          if (item.englishMeaning != null || item.transliteration != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                textDirection: TextDirection.ltr,
                children: [
                  if (item.transliteration != null)
                    Text(
                      item.transliteration!,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: gold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (item.transliteration != null &&
                      item.englishMeaning != null)
                    Text(
                      ' • ',
                      style: TextStyle(color: scheme.outline),
                    ),
                  if (item.englishMeaning != null)
                    Expanded(
                      child: Text(
                        item.englishMeaning!,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  const _Chip({required this.label, required this.value, this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = AppColors.gold;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: gold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: gold.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: gold),
            const SizedBox(width: 4),
          ],
          Text(
            '$label: $value',
            style: theme.textTheme.labelSmall?.copyWith(
              color: gold,
              fontWeight: FontWeight.w600,
            ),
            textDirection: TextDirection.rtl,
          ),
        ],
      ),
    );
  }
}

/// غريب القرآن — word-by-word meanings for the ayah, fetched from the
/// Quran.com API v4 `words` endpoint. Each word is displayed as a card with
/// the Uthmani-script word above and its meaning (translation) below.
