/// «مقولة اليوم» on the Home screen: a small card that holds one quote, moves
/// between them with a swipe or with arrows, and opens the full card when it
/// is tapped.
///
/// «حط كارت مقولة اليوم لو متفعل من الإعدادات في الشاشة الرئيسية فوق حديث
/// اليوم، وخليني أقدر أجيب المقولة اللي بعدها بالتنقل بالأصابع أو بالأسهم، بس
/// طبعًا خليها في كارت صغير وفيه تصغير لشكل المقولة، ولو ضغطت عليه يكبر بكامل
/// الشاشة ويبقى فيه زرار dismiss».
///
/// The miniature is drawn from the same [QuotePalette] the full card would
/// use, so the small thing looks like a shrunk version of the big thing rather
/// than like a different component that happens to hold the same text.
///
/// The order is shuffled once per launch and then FIXED, not re-randomised on
/// every rebuild: a card whose content changes when the screen happens to
/// repaint is a card you cannot finish reading.
library;

import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/arabic_text.dart';
import '../../data/quote_background_catalog.dart';
import '../../data/quote_palettes.dart';
import '../../data/quote_reminder_provider.dart';
import '../../data/quote_repository.dart';
import '../quote_card_screen.dart';

class HomeQuoteCard extends ConsumerStatefulWidget {
  const HomeQuoteCard({super.key});

  @override
  ConsumerState<HomeQuoteCard> createState() => _HomeQuoteCardState();
}

class _HomeQuoteCardState extends ConsumerState<HomeQuoteCard> {
  static const _count = 12;

  final _controller = PageController();
  int _page = 0;

  /// (bookIndex, quoteIndex) pairs, picked once.
  List<(int, int)>? _picks;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<(int, int)> _pick(QuoteLibrary library) {
    final rng = math.Random();
    final out = <(int, int)>[];
    var guard = 0;
    while (out.length < _count && guard++ < _count * 40) {
      if (library.books.isEmpty) break;
      final b = rng.nextInt(library.books.length);
      final quotes = library.books[b].quotes;
      if (quotes.isEmpty) continue;
      final q = rng.nextInt(quotes.length);
      if (!out.contains((b, q))) out.add((b, q));
    }
    return out;
  }

  void _step(int delta) {
    final picks = _picks;
    if (picks == null || picks.isEmpty) return;
    final next = (_page + delta).clamp(0, picks.length - 1);
    if (next == _page) return;
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _open(Quote quote) async {
    final photos = await ref.read(quoteBackgroundsProvider.future);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuoteCardScreen(quote: quote, photos: photos),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(homeQuoteCardProvider)) return const SizedBox.shrink();
    final library = ref.watch(quoteLibraryProvider).valueOrNull;
    if (library == null || library.total == 0) return const SizedBox.shrink();

    final picks = _picks ??= _pick(library);
    if (picks.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.format_quote_rounded,
                size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'quotes.home_title'.tr(),
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            // Arrows as well as the swipe: the owner asked for both, and an
            // arrow is the only one of the two that announces itself.
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: _page == 0 ? null : () => _step(-1),
              icon: const Icon(Icons.chevron_right, size: 22),
              tooltip: 'quotes.previous'.tr(),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed:
                  _page >= picks.length - 1 ? null : () => _step(1),
              icon: const Icon(Icons.chevron_left, size: 22),
              tooltip: 'quotes.next'.tr(),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 168,
          child: PageView.builder(
            controller: _controller,
            itemCount: picks.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) {
              final (b, q) = picks[i];
              final quote = library.at(b, q);
              if (quote == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _QuoteMiniature(
                  quote: quote,
                  palette: kQuotePalettes[i % kQuotePalettes.length],
                  onTap: () => _open(quote),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The shrunk card. Same palette, same ornament colour, same attribution line
/// — just small, and clipped to three lines.
class _QuoteMiniature extends StatelessWidget {
  final Quote quote;
  final QuotePalette palette;
  final VoidCallback onTap;

  const _QuoteMiniature({
    required this.quote,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      color: palette.bottom,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [palette.top, palette.bottom],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.format_quote_rounded,
                    size: 18, color: palette.ornament),
                const SizedBox(height: 4),
                Expanded(
                  child: ArabicText(
                    quote.text,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.ink,
                      height: 1.75,
                      fontSize: 14.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ArabicText(
                        quote.bookTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.open_in_full_rounded,
                        size: 14, color: palette.muted),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
