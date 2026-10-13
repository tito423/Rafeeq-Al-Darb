import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/digits.dart';
import '../../../../core/utils/external_link.dart';
import '../../../../core/widgets/arabic_text.dart';
import '../../../../core/widgets/fitted_sheet.dart';
import '../../data/book_catalog.dart';
import '../../data/book_text.dart';

/// Keep richer catalogue attributions, but drop an empty trailing separator
/// when the downloaded source label supplies the same attribution.
String bookProvenanceLabel(LibraryBook book, BookTextMeta? meta) {
  final catalogue = book.textEdition?.sourceLabel ?? '';
  final downloaded = meta?.sourceLabel ?? '';
  if (downloaded.trim().isNotEmpty &&
      (catalogue.trim().isEmpty ||
          catalogue.replaceFirst(RegExp(r'[\s—–-]+$'), '') == downloaded)) {
    return downloaded;
  }
  return catalogue;
}

Future<void> showBookProvenance(
  BuildContext context,
  LibraryBook book,
  BookTextMeta? meta,
) async {
  if (book.textEdition == null) return;
  await showFittedSheet<void>(
    context: context,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'library.text_source'.tr(),
            style: Theme.of(ctx).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          ArabicText(
            readerDigits(bookProvenanceLabel(book, meta)),
            style: const TextStyle(height: 1.7),
          ),
          if (meta?.editionCard.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 10),
            // Quote the original card without rewriting its text or numbers.
            ArabicText(meta!.editionCard, style: const TextStyle(height: 1.7)),
          ],
          const SizedBox(height: 8),
          if (meta?.printReliable ?? false)
            Text(
              'library.text_print_matches'.tr(),
              style: TextStyle(
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                fontSize: 12.5,
              ),
            ),
          const SizedBox(height: 14),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: () {
                final url = meta?.shamelaUrl ?? '';
                if (url.isNotEmpty) openExternalLink(url);
              },
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text('library.text_open_shamela'.tr()),
            ),
          ),
        ],
      ),
    ),
  );
}
