import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/i18n/proper_name.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/digits.dart';
import '../../data/book_catalog.dart';
import '../../data/hidden_books.dart';
import '../../../shamela/data/shamela_library.dart';

/// The catalogue without the books this reader removed from his list.
List<LibraryBook> visibleBookCatalog() => [
  for (final b in [...libraryBookCatalog, ...ShamelaLibrary.instance.books])
    if (!HiddenBooks.instance.isHidden(b.id)) b,
];

/// Takes [book] off the lists, with «تراجع» for a slip of the finger.
Future<void> hideBook(BuildContext context, LibraryBook book) async {
  final messenger = ScaffoldMessenger.of(context);
  await HiddenBooks.instance.hide(book.id);
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        persist: false,
        duration: const Duration(seconds: 5),
        content: Text(
          'library.hidden_done'.tr(
            args: [properName(book.titleAr, book.titleEn)],
          ),
        ),
        action: SnackBarAction(
          label: 'common.undo'.tr(),
          onPressed: () => HiddenBooks.instance.restore(book.id),
        ),
      ),
    );
}

/// «الكتب المخفية (N)» — shown above a list only while there is one.
class HiddenBooksButton extends StatelessWidget {
  const HiddenBooksButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: HiddenBooks.instance,
      builder: (context, _) {
        final n = HiddenBooks.instance.count;
        if (n == 0) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => const _HiddenBooksSheet(),
              ),
              icon: const Icon(Icons.visibility_off_outlined, size: 18),
              label: Text(trn('library.hidden_books', args: ['$n'])),
            ),
          ),
        );
      },
    );
  }
}

class _HiddenBooksSheet extends StatelessWidget {
  const _HiddenBooksSheet();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: HiddenBooks.instance,
      builder: (context, _) {
        final hidden = [
          for (final b in libraryBookCatalog)
            if (HiddenBooks.instance.isHidden(b.id)) b,
        ];
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.95,
          builder: (context, controller) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  trn('library.hidden_books', args: ['${hidden.length}']),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Expanded(
                child: hidden.isEmpty
                    ? Center(child: Text('library.hidden_empty'.tr()))
                    : ListView.builder(
                        controller: controller,
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                        itemCount: hidden.length,
                        itemBuilder: (context, i) {
                          final b = hidden[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Icon(
                                b.category.icon,
                                color: goldText(context),
                              ),
                              title: Text(properName(b.titleAr, b.titleEn)),
                              subtitle: Text(
                                localizeDigits(
                                  properName(b.authorAr, b.authorEn),
                                  uiLanguageCode,
                                ),
                              ),
                              trailing: TextButton.icon(
                                onPressed: () =>
                                    HiddenBooks.instance.restore(b.id),
                                icon: const Icon(Icons.undo_rounded, size: 18),
                                label: Text('library.restore'.tr()),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
