/// «الإعراب» — the ayah's section of «إعراب القرآن الكريم» by Ahmad Ubaid
/// al-Da'as, Ahmad Muhammad Hamidan and Isma'il Mahmud al-Qasim (Dar
/// al-Munir / Dar al-Farabi, 1st ed. 1425 AH), the owner's chosen source
/// (2026-09-25).
///
/// It replaced the per-word cards built from the Quranic Arabic Corpus: the
/// owner allowed those labels only if 100% certain, and they were not.
///
/// Where the book says «سبق إعرابها» and the earlier place was PROVED
/// (the book's own quote found in it, or the ayah repeated word for word -
/// scripts/resolve_irab_daas_refs.py), that earlier i'rab is shown under the
/// book's line, framed and labelled, as the owner asked. Unproved references
/// show the book's sentence alone - never a guessed target.
library;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/db/models.dart';
import '../../../../../core/db/quran_repository.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/arabic_normalize.dart';
import '../../../../../core/utils/digits.dart';
import 'sciences_common.dart';

final _surahNamesProvider = FutureProvider<Map<int, String>>((ref) async {
  final repo = await ref.watch(quranRepositoryProvider.future);
  return {for (final s in await repo.surahs()) s.id: surahNameShort(s.nameAr)};
});

class IrabTab extends ConsumerWidget {
  final Ayah ayah;
  final Future<IrabSection?> future;
  const IrabTab({super.key, required this.ayah, required this.future});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = ref.watch(_surahNamesProvider).value ?? const <int, String>{};
    return AsyncTab<IrabSection?>(
      future: future,
      isEmpty: (d) => d == null,
      builder: (context, section) {
        final s = section!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
          children: [
            _SourceHeader(section: s),
            const SizedBox(height: 12),
            ..._body(context, s, names),
          ],
        );
      },
    );
  }

  /// The book's text, cut at each proved reference, with the referenced
  /// i'rab framed right after the clause that points to it.
  List<Widget> _body(
      BuildContext context, IrabSection s, Map<int, String> names) {
    final out = <Widget>[];
    var start = 0;
    for (final r in s.references) {
      if (r.at <= start || r.at > s.text.length) continue;
      out.add(_BookText(s.text.substring(start, r.at).trim()));
      out.add(_ReferenceBlock(reference: r, surahName: names[r.targetSurah]));
      start = r.at;
    }
    final rest = s.text.substring(start).trim();
    if (rest.isNotEmpty) out.add(_BookText(rest));
    return out;
  }
}

class _SourceHeader extends StatelessWidget {
  final IrabSection section;
  const _SourceHeader({required this.section});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = AppColors.gold;
    final range = section.ayahTo > section.ayahFrom;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: gold.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book_outlined, size: 16, color: gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'quran.irab_book'.tr(),
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: gold, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'quran.irab_source'.tr(),
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          if (range) ...[
            const SizedBox(height: 6),
            Text(
              trn('quran.irab_section_range',
                  args: ['${section.ayahFrom}', '${section.ayahTo}']),
              style: theme.textTheme.labelMedium?.copyWith(color: gold),
            ),
          ],
        ],
      ),
    );
  }
}

/// A run of the book's text. The Qur'an words it parses («…») are set
/// in gold, as the print sets them in bold. Always right to left: it is an
/// Arabic book whatever the interface language.
class _BookText extends StatelessWidget {
  final String text;
  const _BookText(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.bodyLarge?.copyWith(height: 1.9);
    final quote = base?.copyWith(
        color: AppColors.gold, fontWeight: FontWeight.w700);
    final spans = <TextSpan>[];
    var i = 0;
    for (final m in RegExp('«[^«»]*»').allMatches(text)) {
      if (m.start > i) spans.add(TextSpan(text: text.substring(i, m.start)));
      spans.add(TextSpan(text: m.group(0), style: quote));
      i = m.end;
    }
    if (i < text.length) spans.add(TextSpan(text: text.substring(i)));
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(style: base, children: spans),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.justify,
      ),
    );
  }
}

class _ReferenceBlock extends StatelessWidget {
  final IrabReference reference;
  final String? surahName;
  const _ReferenceBlock({required this.reference, required this.surahName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = AppColors.gold;
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 2, 12, 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: BorderDirectional(
          start: BorderSide(color: gold.withValues(alpha: 0.7), width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            trn('quran.irab_ref_title', args: [
              surahName ?? '${reference.targetSurah}',
              '${reference.targetAyah}',
            ]),
            style: theme.textTheme.labelMedium
                ?.copyWith(color: gold, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          _BookText(reference.targetText.trim()),
        ],
      ),
    );
  }
}
