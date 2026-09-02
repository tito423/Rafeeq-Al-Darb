import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/db/hadith_repository.dart';

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
                  if ((_item.textEn ?? '').isNotEmpty) ...[
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
                  // grade is deliberately never shown when null — see
                  // HadithRepository's doc on why this dataset has none.
                  if (_item.grade != null) ...[
                    const SizedBox(height: 16),
                    Chip(label: Text('${'library.grade'.tr()}: ${_item.grade}')),
                  ],
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
