import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../data/quote_palettes.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/arabic_normalize.dart';
import '../../../core/widgets/arabic_text.dart';
import '../../../core/widgets/islamic_pattern.dart';
import '../data/quote_background_catalog.dart';
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
    this.paletteIndex,
    this.photos,
  });

  @override
  State<QuoteCardScreen> createState() => _QuoteCardScreenState();
}


class _QuoteCardScreenState extends State<QuoteCardScreen> {
  late final QuotePalette _palette;
  late final double _tile;

  /// The photograph this card drew, or null when it drew the ornament.
  QuoteBackground? _photo;

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _palette = kQuotePalettes[
        widget.paletteIndex ?? rng.nextInt(kQuotePalettes.length)];
    // The lattice scale changes too, so two cards on the same palette still
    // do not look like the same picture.
    _tile = 56.0 + rng.nextInt(5) * 12;
    // «خلفية إسلامية تتغير عشوائي كل مرة» — the whole pool, drawn ornaments
    // and photographs together, so «كل مرة» really is a different picture
    // rather than a rotation of six.
    final photos = widget.photos?.images ?? const <QuoteBackground>[];
    if (photos.isNotEmpty && widget.paletteIndex == null) {
      final n = rng.nextInt(photos.length + kQuotePalettes.length);
      if (n < photos.length) _photo = photos[n];
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.quote;
    return Scaffold(
      backgroundColor: _palette.bottom,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_photo != null) ...[
            Image.asset(
              _photo!.asset,
              fit: BoxFit.cover,
              // A missing or unreadable asset must not leave a blank card:
              // fall through to the gradient underneath.
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
            // The scrim the photograph was MEASURED through. Every image's
            // brightest region clears 4.5:1 against the ink under exactly
            // this layer (trap #15 — the composite is what the eye gets, not
            // either colour on its own), so the value comes from the manifest
            // rather than from a number typed here.
            ColoredBox(color: Color(widget.photos!.scrimArgb)),
          ] else ...[
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_palette.top, _palette.bottom],
                ),
              ),
            ),
            CustomPaint(
              painter: IslamicPatternPainter(
                tile: _tile,
                color: _palette.ornament,
                strokeWidth: 1,
              ),
            ),
          ],
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Column(
                children: [
                  Align(
                    alignment: AlignmentDirectional.topEnd,
                    child: Icon(Icons.format_quote,
                        size: 40, color: _palette.ink.withValues(alpha: 0.28)),
                  ),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // The saying is Arabic whatever the app's own
                            // language is, so it is laid out right-to-left
                            // whatever the chrome around it does — the defect
                            // `arabic_direction_test` measures.
                            ArabicText(
                              stripBidiControls(q.text),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _palette.ink,
                                fontSize: 21,
                                height: 1.95,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 26),
                            Container(
                              width: 54,
                              height: 1,
                              color: _palette.ornament.withValues(alpha: 0.9),
                            ),
                            const SizedBox(height: 18),
                            // §1.1 and §1.2: the book is not optional, and
                            // neither is its author. A saying with no source
                            // is the thing this project refuses to ship.
                            ArabicText(
                              q.bookTitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.gold,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            ArabicText(
                              q.authorAr,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: _palette.muted, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
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
