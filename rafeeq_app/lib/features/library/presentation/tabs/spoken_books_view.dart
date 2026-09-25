import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/digits.dart';
import '../../data/book_catalog.dart';
import '../widgets/book_card.dart';

/// «اعمل تاب جديد قبل مكتبتي بأسماء الكتب القابلة للقراءة الصوتية»
/// (2026-09-19): every book the reader's voice will read - the ones
/// `LibraryBook.canBeSpoken` passes, measured against the hosted text - in
/// one list, with the same cards as the rest of the library.
class SpokenBooksView extends StatelessWidget {
  final Map<String, String> paths;
  final void Function(LibraryBook) onDownload;
  final void Function(LibraryBook) onOpen;

  const SpokenBooksView({
    super.key,
    required this.paths,
    required this.onDownload,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final books = [
      for (final b in libraryBookCatalog)
        if (b.canBeSpoken) b,
    ]..sort((a, b) => a.sortKey.compareTo(b.sortKey));
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: AppColors.gold.withValues(alpha: 0.08),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
          ),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gold.withValues(alpha: 0.16),
              ),
              child: Icon(Icons.headphones_rounded,
                  color: goldText(context)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizeDigits(pluralN('library.book_count', books.length),
                        context.locale.languageCode),
                    style: TextStyle(
                        fontWeight: FontWeight.w800, color: goldText(context)),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'library.spoken_intro'.tr(),
                    style: TextStyle(
                        fontSize: 12.5,
                        height: 1.5,
                        color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ]),
        ),
        for (final b in books) ...[
          BookCard(
            book: b,
            paths: paths,
            onDownload: () => onDownload(b),
            onOpen: () => onOpen(b),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
