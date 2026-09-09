// easy_localization re-exports package:intl, whose `TextDirection` (LTR/RTL)
// collides with the `dart:ui` enum (ltr/rtl) this file needs for the hadith's
// own right-to-left layout.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import '../../../../core/utils/arabic_normalize.dart';
import 'package:flutter/material.dart';

import '../../../../core/widgets/arabic_text.dart';
import '../widgets/hadith_translation.dart';

import '../../../../core/db/hadith_repository.dart';
import '../../../../core/theme/app_colors.dart';
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
        ArabicText(
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
          stripBidiControls(item.arabic),
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.justify,
          style: const TextStyle(
            fontFamily: 'AmiriQuran',
            fontSize: 20,
            height: 2.0,
          ),
        ),
        // The translation, shown under the Arabic whenever the app isn't in
        // Arabic. It used to appear unlabelled, which left a Spanish reader
        // to work out for themselves that the paragraph was English — and a
        // collection with no translation at all said nothing whatsoever.
        if (!isArabic) ...[
          const Divider(height: 32),
          HadithTranslation(item: item),
        ],
        // Every hadith now says something about its takhrij, because saying
        // nothing is itself ambiguous — a reader can't tell an ungraded
        // hadith from one whose grading the app simply forgot to show.
        //
        // Bukhari and Muslim have no per-hadith grade column and should not:
        // what the two of them included in their Sahihs is authentic by the
        // collections' own criteria and by scholarly consensus, so the
        // collection *is* the grading. That is stated plainly rather than
        // left blank. For everything else the source's own grade and grader
        // are shown, and where the source states none, so is that — nothing
        // here is ever inferred.
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: _TakhrijChip(book: book, item: item),
        ),
      ],
    );
  }
}


/// The takhrij line under a hadith: its authenticity grading, or an honest
/// statement of where that grading comes from.
class _TakhrijChip extends StatelessWidget {
  final HadithBook book;
  final HadithItem item;

  const _TakhrijChip({required this.book, required this.item});

  /// Sahih al-Bukhari and Sahih Muslim, by their `books.id`.
  static const _bukhari = 1;
  static const _muslim = 2;

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final scheme = Theme.of(context).colorScheme;

    final String text;
    final Color tone;
    final IconData icon;

    if (book.id == _bukhari || book.id == _muslim) {
      // Not a grade the app invented — a statement of which Sahih it is in.
      text = 'library.takhrij_sahihayn'.tr(args: [book.nameAr]);
      tone = AppColors.success;
      icon = Icons.verified_outlined;
    } else if (item.grade != null && item.grade!.isNotEmpty) {
      final grade = localizedHadithGrade(item.grade!, lang);
      text = item.grader != null
          ? '$grade — ${localizedHadithGrader(item.grader!, lang)}'
          : grade;
      tone = AppColors.gold;
      icon = Icons.fact_check_outlined;
    } else {
      text = 'library.takhrij_none'.tr();
      tone = scheme.outline;
      icon = Icons.help_outline;
    }

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tone.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: tone),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                text,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: tone, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
