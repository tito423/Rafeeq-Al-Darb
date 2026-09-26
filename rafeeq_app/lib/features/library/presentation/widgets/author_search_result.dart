import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/digits.dart';
import '../../data/book_catalog.dart';

/// One author found by the search: the author, not a list of his books.
///
/// Owner, 2026-09-26: «المؤلفين بالذات المفروض يعرض لي أسماء المؤلفين مش
/// أسماء كتبهم … عايز إمكانية إني أحمل كل كتب المؤلف مرة واحدة». The card
/// names the author, the death date and how many books the library holds,
/// offers every one not yet on the phone in one tap, and opens onto the
/// books.
class AuthorSearchResult extends StatefulWidget {
  const AuthorSearchResult({
    super.key,
    required this.name,
    required this.deathDate,
    required this.books,
    required this.missing,
    required this.progress,
    required this.onDownloadAll,
    required this.bookTile,
  });

  final String name;
  final String deathDate;
  final List<LibraryBook> books;

  /// His books with a hosted text that are not on the phone yet.
  final List<LibraryBook> missing;

  /// (done, total) while his books download; null otherwise.
  final (int, int)? progress;
  final VoidCallback onDownloadAll;
  final Widget Function(LibraryBook) bookTile;

  @override
  State<AuthorSearchResult> createState() => _AuthorSearchResultState();
}

class _AuthorSearchResultState extends State<AuthorSearchResult> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = context.locale.languageCode;
    final count = pluralN('library.book_count', widget.books.length);
    final progress = widget.progress;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Row(children: [
                CircleAvatar(
                  backgroundColor: AppColors.gold.withValues(alpha: 0.15),
                  child: Icon(Icons.person_outline,
                      color: goldText(context), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.name,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        localizeDigits(
                          widget.deathDate.isEmpty
                              ? count
                              : '${widget.deathDate} • $count',
                          lang,
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _open ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  // chevron_right: the left one mirrors in RTL (trap #7).
                  child: const Icon(Icons.chevron_right),
                ),
              ]),
            ),
          ),
          if (progress != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizeDigits(
                      'library.author_downloading'
                          .tr(args: ['${progress.$1}', '${progress.$2}']),
                      lang,
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: progress.$2 == 0 ? null : progress.$1 / progress.$2,
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            )
          else if (widget.missing.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.tonalIcon(
                  onPressed: widget.onDownloadAll,
                  icon: const Icon(Icons.download_for_offline_rounded),
                  label: Text(localizeDigits(
                    'library.download_author_all'
                        .tr(args: ['${widget.missing.length}']),
                    lang,
                  )),
                ),
              ),
            ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
              child: Column(children: [
                for (final b in widget.books) widget.bookTile(b),
              ]),
            ),
        ],
      ),
    );
  }
}
