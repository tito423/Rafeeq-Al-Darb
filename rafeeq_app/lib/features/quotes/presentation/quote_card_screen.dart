import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/arabic_normalize.dart';
import '../../../core/widgets/arabic_text.dart';
import '../../../core/widgets/mosque_backdrop.dart';
import '../data/quote_background_catalog.dart';
import '../data/quote_palettes.dart';
import '../data/quote_repository.dart';

/// The card the quote notification opens: it **covers what is behind it**,
/// carries an Islamic background that changes at random each time, and closes
/// on a dismiss button written in the interface language — which is exactly
/// what the owner asked for.
///
/// TWO KINDS OF BACKGROUND, DRAWN FROM ONE POOL.
/// Six are the ornament the adhkar cards already use —
/// `IslamicPatternPainter`, drawn by the app, no licence question at all —
/// each over its own measured palette. Eleven are photographs of Islamic
/// ornament from Wikimedia Commons, every one of them public domain or CC0
/// and checked file by file; see `QuoteBackground` for what was refused and
/// why. The card picks from all seventeen, so «تتغير عشوائي كل مرة» is a
/// real seventeen and not a rotation of six.
///
/// A photograph is drawn under the scrim it was **measured** through, so the
/// saying's contrast is a computed number rather than a hope.
///
/// The route is opaque and full-screen on purpose: a notification tapped from
/// a locked-away phone should land on the saying, not on whatever screen the
/// app happened to be showing three hours ago.
class QuoteCardScreen extends StatefulWidget {
  final Quote quote;

  /// The sayings to swipe through, [quote] among them at [initialIndex];
  /// null for a card opened on one saying (the notification).
  final List<Quote>? quotes;
  final int initialIndex;

  /// Fixed only in tests and in the gallery; null means "pick one now".
  final int? paletteIndex;

  /// The photographic backgrounds available, or null when they could not be
  /// read. The card then falls back to the drawn ornament, which needs no
  /// asset and cannot fail — a notification that fires with no connection and
  /// a cold cache still has to open on something.
  final QuoteBackgroundSet? photos;

  const QuoteCardScreen({
    super.key,
    required this.quote,
    this.quotes,
    this.initialIndex = 0,
    this.paletteIndex,
    this.photos,
  });

  @override
  State<QuoteCardScreen> createState() => _QuoteCardScreenState();
}

class _QuoteCardScreenState extends State<QuoteCardScreen> {
  late final QuotePalette _palette;

  /// The mosque behind the saying (owner, 2026-10-08: «خلي خلفية المقولة
  /// برده مسجد جميل في شاشتها الكبيرة»), drawn once per opening.
  late final String _mosque;

  /// «اديني امكانية اني اتنقل للمقولات اللي بعد الظاهرة بالاصبع»: the same
  /// sayings the Home card holds, swiped through over a fixed background.
  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );
  List<Quote> get _all => widget.quotes ?? [widget.quote];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _palette =
        kQuotePalettes[widget.paletteIndex ??
            rng.nextInt(kQuotePalettes.length)];
    // «خلفية إسلامية تتغير عشوائي كل مرة» — the whole pool, drawn ornaments
    // and photographs together, so «كل مرة» really is a different picture
    // rather than a rotation of six.
    _mosque = MosquePhotos.wide[rng.nextInt(MosquePhotos.wide.length)];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _palette.bottom,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            _mosque,
            fit: BoxFit.cover,
            // A missing asset must not leave a blank card.
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
          // The scrim the quote photographs were MEASURED through (trap
          // #15): the ink clears 4.5:1 over the brightest region under it.
          ColoredBox(color: Color(widget.photos?.scrimArgb ?? 0xCC071626)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Column(
                children: [
                  Align(
                    alignment: AlignmentDirectional.topEnd,
                    child: Icon(
                      Icons.format_quote,
                      size: 40,
                      color: _palette.ink.withValues(alpha: 0.28),
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pages,
                      itemCount: _all.length,
                      itemBuilder: (context, i) {
                        final q = _all[i];
                        return Center(
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // The saying in the reader's language — and only
                                // an Arabic one needs the right-to-left paragraph
                                // `arabic_direction_test` measures.
                                ScriptText(
                                  stripBidiControls(q.text),
                                  arabic: context.locale.languageCode == 'ar',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _palette.ink,
                                    fontSize: 21,
                                    height: 1.95,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                // … and under it, always, the words the author
                                // wrote. A translated maxim without its original
                                // is a claim about a book, not a quotation from
                                // it — the same rule the ayah cards follow.
                                if (context.locale.languageCode != 'ar') ...[
                                  const SizedBox(height: 18),
                                  ArabicText(
                                    stripBidiControls(q.arabic),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _palette.ink.withValues(
                                        alpha: 0.72,
                                      ),
                                      fontSize: 16,
                                      height: 1.95,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 26),
                                Container(
                                  width: 54,
                                  height: 1,
                                  color: _palette.ornament.withValues(
                                    alpha: 0.9,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                // §1.1 and §1.2: the book is not optional, and
                                // neither is its author. A saying with no source
                                // is the thing this project refuses to ship.
                                Text(
                                  q.bookTitle,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    // Measured against this card's own ground,
                                    // which changes with its palette.
                                    color: readableOn(
                                      AppColors.gold,
                                      _palette.bottom,
                                    ),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  q.authorAr,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _palette.muted,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _palette.ink.withValues(alpha: 0.12),
                        foregroundColor: _palette.ink,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: Text('quotes.dismiss'.tr()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
