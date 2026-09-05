import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/db/hadith_repository.dart';
import '../../../../core/i18n/hadith_grade_i18n.dart';

/// One hadith, full text, with Previous/Next inside its chapter so reading
/// doesn't require popping back for every hadith.
class HadithDetailScreen extends StatefulWidget {
  final HadithBook book;
  final List<HadithItem> chapterHadiths;
  final int initialIndex;

  const HadithDetailScreen({
    super.key,
    required this.book,
    required this.chapterHadiths,
    required this.initialIndex,
  });

  @override
  State<HadithDetailScreen> createState() => _HadithDetailScreenState();
}

class _HadithDetailScreenState extends State<HadithDetailScreen> {
  late int _index = widget.initialIndex;

  HadithItem get _item => widget.chapterHadiths[_index];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('${'library.hadith_number'.tr()} ${_item.numberInBook}'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    widget.book.nameAr,
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: scheme.primary),
                  ),
                  // P3‑47: hide the English book name when the app is in
                  // Arabic — an Arabic reader doesn't need "Sahih al-Bukhari"
                  // shown under "صحيح البخاري".
                  if (context.locale.languageCode != 'ar') ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.book.nameEn,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                  const Divider(height: 28),
                  SelectableText(
                    _item.arabic,
                    textAlign: TextAlign.justify,
                    style: const TextStyle(
                      fontFamily: 'AmiriQuran',
                      fontSize: 20,
                      height: 2.0,
                    ),
                  ),
                  // P3‑43 #15: "لا تظهر الترجمة إلا إذا كانت لغة التطبيق
                  // مختلفة عن العربية" — an Arabic-reading user doesn't need
                  // the English gloss shown back at them next to the real
                  // Arabic hadith text above.
                  if (context.locale.languageCode != 'ar' &&
                      (_item.textEn ?? '').isNotEmpty) ...[
                    const Divider(height: 32),
                    if ((_item.narratorEn ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _item.narratorEn!,
                          style: theme.textTheme.labelMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    Text(
                      _item.textEn!,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(height: 1.6),
                    ),
                  ],
                  // P3‑47: the "صحيح — من الصحيحين" badge for Bukhari/Muslim
                  // was removed at the owner's request. The real per-hadith
                  // grade+grader for the other 7 books (where the source
                  // states one) still shows — that's genuine data, not the
                  // definitional badge that was dropped.
                  if (widget.book.id != 1 &&
                      widget.book.id != 2 &&
                      _item.grade != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Chip(
                        label: Text(_item.grader != null
                            ? '${localizedHadithGrade(_item.grade!, context.locale.languageCode)} '
                                '(${localizedHadithGrader(_item.grader!, context.locale.languageCode)})'
                            : localizedHadithGrade(
                                _item.grade!, context.locale.languageCode)),
                      ),
                    ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _index > 0
                            ? () => setState(() => _index--)
                            : null,
                        // P3‑47: use the semantic icons and let Flutter
                        // auto-mirror them in RTL (both are matchTextDirection
                        // icons). The old code hard-swapped them, which
                        // double-flipped in Arabic and pointed both the wrong
                        // way — the arrow bug the owner flagged.
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label: Text('library.previous'.tr()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _index < widget.chapterHadiths.length - 1
                            ? () => setState(() => _index++)
                            : null,
                        icon: const Icon(Icons.arrow_forward, size: 18),
                        label: Text('library.next'.tr()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
