import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/db/hadith_repository.dart';
import '../../../../core/i18n/hadith_grade_i18n.dart';

/// One hadith, full text, with Previous/Next inside its chapter so reading
/// doesn't require popping back for every hadith.
///
/// P3‑56: the chapter's hadiths are now a horizontal [PageView] — a swipe
/// left/right (honouring the app's reading direction, since a horizontal
/// PageView follows the ambient `Directionality`) turns to the previous/next
/// hadith with a smooth slide. The Previous/Next buttons are kept and simply
/// drive the same [PageController], so both gestures and buttons stay in sync.
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
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int i) {
    if (i < 0 || i >= widget.chapterHadiths.length) return;
    _controller.animateToPage(
      i,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.chapterHadiths[_index];
    final last = widget.chapterHadiths.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: Text('${'library.hadith_number'.tr()} ${item.numberInBook}'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.chapterHadiths.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => _HadithContent(
                  book: widget.book,
                  item: widget.chapterHadiths[i],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _index > 0 ? () => _goTo(_index - 1) : null,
                        // Semantic icons that Flutter auto-mirrors in RTL (both
                        // are matchTextDirection icons), so they point the right
                        // way in Arabic without hard-swapping them.
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label: Text('library.previous'.tr()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed:
                            _index < last ? () => _goTo(_index + 1) : null,
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

/// One hadith's scrollable content — the book name, the Arabic text, the
/// (locale-gated) English gloss, and the real per-hadith grade where the
/// source states one. Pulled out of the screen's `build` so it can be the
/// per-page builder of the [PageView].
class _HadithContent extends StatelessWidget {
  final HadithBook book;
  final HadithItem item;
  const _HadithContent({required this.book, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isArabic = context.locale.languageCode == 'ar';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          book.nameAr,
          style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary),
        ),
        // Hide the English book name in Arabic — an Arabic reader doesn't need
        // "Sahih al-Bukhari" under "صحيح البخاري".
        if (!isArabic) ...[
          const SizedBox(height: 4),
          Text(
            book.nameEn,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
        const Divider(height: 28),
        SelectableText(
          item.arabic,
          textAlign: TextAlign.justify,
          style: const TextStyle(
            fontFamily: 'AmiriQuran',
            fontSize: 20,
            height: 2.0,
          ),
        ),
        // The English gloss only shows when the app isn't in Arabic.
        if (!isArabic && (item.textEn ?? '').isNotEmpty) ...[
          const Divider(height: 32),
          if ((item.narratorEn ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                item.narratorEn!,
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          Text(
            item.textEn!,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
        ],
        // Bukhari/Muslim carry no per-hadith grade column (they're sahih by
        // definition); the real grade+grader for the other books shows where
        // the source states one.
        if (book.id != 1 && book.id != 2 && item.grade != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Chip(
              label: Text(item.grader != null
                  ? '${localizedHadithGrade(item.grade!, context.locale.languageCode)} '
                      '(${localizedHadithGrader(item.grader!, context.locale.languageCode)})'
                  : localizedHadithGrade(
                      item.grade!, context.locale.languageCode)),
            ),
          ),
      ],
    );
  }
}
