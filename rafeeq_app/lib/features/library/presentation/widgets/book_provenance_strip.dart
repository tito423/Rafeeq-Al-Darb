import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/widgets/arabic_text.dart';
import '../../data/book_catalog.dart';

/// The line under every opened book that says where its text came from.
///
/// It lived inside `book_text_reader_screen.dart` until that file's length
/// guard refused the next change — «it is on the list because it was already
/// over, not so it could keep growing». It belongs out here anyway: what a
/// reader is told about provenance is its own concern, and CLAUDE.md §1.2
/// makes it a requirement rather than a decoration.
///
/// Two things can be shown besides the edition line:
///
/// * `editorNotesRemoved` — 47 books had a modern muhaqqiq's apparatus
///   filtered out of the hosted file on 2026-09-17 (see `CONTENT-LICENSES.md`).
///   Their `sourceLabel` still names him, because naming the printing the text
///   came from is what §1.2 asks for. But that line alone reads as «this is
///   his edition», and it is not any more — so the reader is told which of the
///   two he is holding. A card that is true and misleading at once is the
///   harder kind of wrong to catch.
/// * `isOcr` — never true for a Shamela book, which is typed text, but an
///   honest badge is waiting if a machine-read source is ever added.
class BookProvenanceStrip extends StatelessWidget {
  final LibraryBook book;
  final Color paper;
  final Color ink;
  final Color hairline;
  final VoidCallback onTap;

  const BookProvenanceStrip({
    super.key,
    required this.book,
    required this.paper,
    required this.ink,
    required this.hairline,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final edition = book.textEdition;
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: paper,
          border: Border(top: BorderSide(color: hairline)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline,
                size: 14, color: ink.withValues(alpha: 0.6)),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ArabicText(
                    edition?.sourceLabel ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: ink.withValues(alpha: 0.6), fontSize: 11.5),
                  ),
                  // A translation key, not Arabic in the widget — a reader who
                  // chose English reads this in English.
                  if (edition?.editorNotesRemoved ?? false)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'library.editor_notes_removed'.tr(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: ink.withValues(alpha: 0.5), fontSize: 10.5),
                      ),
                    ),
                ],
              ),
            ),
            if (edition?.isOcr ?? false)
              Container(
                margin: const EdgeInsetsDirectional.only(start: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('library.text_ocr_badge'.tr(),
                    style: TextStyle(
                        fontSize: 10, color: scheme.onErrorContainer)),
              ),
          ],
        ),
      ),
    );
  }
}
