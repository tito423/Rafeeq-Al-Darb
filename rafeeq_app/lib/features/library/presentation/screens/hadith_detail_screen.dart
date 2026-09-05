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
                  const SizedBox(height: 4),
                  Text(
                    widget.book.nameEn,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
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
                  // Bukhari (id 1) / Muslim (id 2) are sahih by definition —
                  // that badge comes from the book itself, never from a
                  // per-hadith `grade` (which stays null for both, see
                  // HadithRepository's doc). The other 7 books show the
                  // real per-hadith grade+grader where the source has one,
                  // and an honest "not stated" chip where it doesn't — never
                  // silence, which could read as "ungraded because weak".
                  if (widget.book.id == 1 || widget.book.id == 2)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Chip(
                        avatar: const Icon(Icons.verified, size: 18),
                        label: Text('library.sahihayn_badge'.tr()),
                      ),
                    )
                  else if (_item.grade != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      // P3‑41: no "Grade:" label — just the grade itself,
                      // localized where honestly possible (see
                      // hadith_grade_i18n.dart's own doc for why only
                      // Arabic gets real term restoration).
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
                        icon: const Icon(Icons.arrow_forward, size: 18),
                        label: Text('library.previous'.tr()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _index < widget.chapterHadiths.length - 1
                            ? () => setState(() => _index++)
                            : null,
                        icon: const Icon(Icons.arrow_back, size: 18),
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
