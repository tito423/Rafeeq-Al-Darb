/// «مقولة اليوم» on the Home screen: a small card that holds one quote, moves
/// between them with a swipe or with arrows, and opens the full card when it
/// is tapped.
///
/// «حط كارت مقولة اليوم لو متفعل من الإعدادات في الشاشة الرئيسية فوق حديث
/// اليوم، وخليني أقدر أجيب المقولة اللي بعدها بالتنقل بالأصابع أو بالأسهم، بس
/// طبعًا خليها في كارت صغير وفيه تصغير لشكل المقولة، ولو ضغطت عليه يكبر بكامل
/// الشاشة ويبقى فيه زرار dismiss».
///
/// THE COLOURS COME FROM THE THEME, not from the share-card palettes.
/// The full-screen card is a thing you screenshot and send, so it keeps its
/// own dramatic grounds; a card sitting in the middle of the Home screen is
/// not, and one painted deep-night-blue on a light theme is the same mistake
/// the Downloads storage card made — «خلي ألوان مقولة اليوم وجميع ألوان
/// الكروت مناسبة وجميلة مع الثيم المستخدم». Each card takes one accent from a
/// small rotation and tints the surface with it, so the twelve still differ
/// from one another while all twelve belong to the theme that is on.
///
/// The order is shuffled once per launch and then FIXED, not re-randomised on
/// every rebuild: a card whose content changes when the screen happens to
/// repaint is a card you cannot finish reading.
library;

import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/arabic_text.dart';
import '../../data/quote_background_catalog.dart';
import '../../data/quote_reminder_provider.dart';
import '../../data/quote_repository.dart';
import '../quote_card_screen.dart';

class HomeQuoteCard extends ConsumerStatefulWidget {
  const HomeQuoteCard({super.key});

  @override
  ConsumerState<HomeQuoteCard> createState() => _HomeQuoteCardState();
}

/// One accent per card, cycled. They are the app's own palette entries, and
/// they are used as a TINT over the theme's surface rather than as a ground,
/// so they read the same way on all four themes.
const _accents = <Color>[
  AppColors.gold,
  AppColors.primarySoft,
  Color(0xFF6C5FBC),
  Color(0xFF3F7A8C),
  Color(0xFFD4785A),
  Color(0xFF2E9D6F),
];

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
                  accent: _accents[i % _accents.length],
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

/// The shrunk card: the quote, the book, and an accent — in the theme's own
/// colours.
class _QuoteMiniature extends StatelessWidget {
  final Quote quote;
  final Color accent;
  final VoidCallback onTap;

  const _QuoteMiniature({
    required this.quote,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Blended rather than set with an alpha: a translucent tint over an
    // unknown ground composites unpredictably, and this app has already paid
    // for that once (trap #15).
    final ground = Color.alphaBlend(
      accent.withValues(alpha: 0.10),
      scheme.surfaceContainerHighest,
    );
    final ink = scheme.onSurface;
    final muted = scheme.onSurfaceVariant;
    return Material(
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      color: ground,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            border: Border.all(color: accent.withValues(alpha: 0.35)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.format_quote_rounded,
                    size: 18, color: accent),
                const SizedBox(height: 4),
                Expanded(
                  child: ArabicText(
                    quote.text,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ink,
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
                          color: muted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.open_in_full_rounded,
                        size: 14, color: muted),
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
