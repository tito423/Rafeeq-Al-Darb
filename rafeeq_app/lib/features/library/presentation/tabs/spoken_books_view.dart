import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/digits.dart';
import '../../data/book_catalog.dart';
import '../../data/library_api_service.dart';
import '../widgets/book_card.dart';
import '../widgets/hidden_books_sheet.dart';

/// «اعمل تاب جديد قبل مكتبتي بأسماء الكتب القابلة للقراءة الصوتية»
/// (2026-09-19): every book the reader's voice will read - the ones
/// `LibraryBook.canBeSpoken` passes, measured against the hosted text - in
/// one list, with the same cards as the rest of the library.

class SpokenBooksView extends StatefulWidget {
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
  State<SpokenBooksView> createState() => _SpokenBooksViewState();
}

class _SpokenBooksViewState extends State<SpokenBooksView> {
  bool _selectionMode = false;
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    // `visibleBookCatalog`, like the authors and categories lists: this
    // list drew from the whole catalogue, so «−» here said «أُزيل … من
    // القائمة» while the book stayed exactly where it was (owner's phone,
    // 2026-09-25).
    final books = [
      for (final b in visibleBookCatalog())
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (!_selectionMode)
              FilledButton.tonalIcon(
                onPressed: () {
                  final missing = books.where((b) => !widget.paths.containsKey(b.id)).toList();
                  for (final b in missing) {
                    widget.onDownload(b);
                  }
                },
                icon: const Icon(Icons.download_for_offline_rounded),
                label: Text(
                  localizeDigits(
                    trn('library.download_author_all', args: ['${books.where((b) => !widget.paths.containsKey(b.id)).length}']),
                    context.locale.languageCode,
                  ),
                ),
              )
            else
              TextButton.icon(
                icon: const Icon(Icons.close),
                label: Text('إلغاء التحديد'),
                onPressed: () => setState(() {
                  _selectionMode = false;
                  _selected.clear();
                }),
              ),
            
            if (_selectionMode)
              Row(
                children: [
                  if (_selected.any((id) => widget.paths.containsKey(id)))
                    IconButton.filledTonal(
                      icon: const Icon(Icons.delete),
                      color: Colors.red,
                      onPressed: () async {
                        final toDelete = _selected.where((id) => widget.paths.containsKey(id)).toList();
                        for (final id in toDelete) {
                          await LibraryApiService.instance.deleteBook(id);
                        }
                        if (mounted) {
                          setState(() {
                            _selectionMode = false;
                            _selected.clear();
                          });
                        }
                      },
                    ),
                  if (_selected.any((id) => !widget.paths.containsKey(id)))
                    IconButton.filledTonal(
                      icon: const Icon(Icons.download),
                      onPressed: () {
                        final toDownload = books.where((b) => _selected.contains(b.id) && !widget.paths.containsKey(b.id));
                        for (final b in toDownload) {
                          widget.onDownload(b);
                        }
                        setState(() {
                          _selectionMode = false;
                          _selected.clear();
                        });
                      },
                    ),
                ],
              )
            else
              TextButton.icon(
                icon: const Icon(Icons.checklist),
                label: Text('تحديد'),
                onPressed: () => setState(() => _selectionMode = true),
              ),
          ],
        ),
        const SizedBox(height: 12),
        for (final b in books) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_selectionMode)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Checkbox(
                    value: _selected.contains(b.id),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) _selected.add(b.id);
                        else _selected.remove(b.id);
                      });
                    },
                  ),
                ),
              Expanded(
                child: BookCard(
                  book: b,
                  paths: widget.paths,
                  onDownload: () => widget.onDownload(b),
                  onOpen: () => widget.onOpen(b),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
