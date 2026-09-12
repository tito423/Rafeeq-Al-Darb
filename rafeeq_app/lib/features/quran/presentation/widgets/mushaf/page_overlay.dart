/// The floating page furniture: the surah / juz header, the page number,
/// and the overlay that keeps them on screen while the page scrolls.
library;


import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../core/utils/digits.dart';
import '../../../../../core/theme/app_colors.dart';

/// Quran tab — a real mushaf browser.
///  • Text mode: real Uthmani ayahs laid out by their real Madani page
///    boundaries from the bundled database (works fully offline).
///  • Image mode: the authentic KFQC mushaf pages as vector art, cached on
///    device, with the real ayah polygons layered on top for tap/highlight.

/// P3‑43 #7: a real printed mushaf's running header — page number bottom
/// centre, surah name top-right, juz name top-left — kept on screen
/// regardless of toolbar visibility or full-screen mode (it's reading
/// context, not an "option"). Fixed physical corners, not RTL `start`/
/// `end`: a real mushaf page's own running headers don't mirror with the
/// *app's* locale, they're a property of the page itself. `IgnorePointer`
/// throughout so it never steals the background tap that toggles the
/// toolbar or exits full-screen.
class PersistentPageOverlay extends StatelessWidget {
  /// Null when the open printing doesn't share the Hafs pagination these
  /// labels are derived from — the header is simply omitted rather than
  /// asserting a surah/juz that isn't on the page.
  final String? surahName;
  final int? juzNumber;

  /// P3‑51: the page number itself no longer lives here. In normal mode it's
  /// a real bar under the text (see the Scaffold's bottomNavigationBar), so
  /// this overlay only paints the top running header (surah + juz). In
  /// full-screen mode there's no bottom bar, so the page badge is shown here
  /// at the bottom instead — the viewer already reserves 56px there, so it
  /// never overlaps the last line.
  final int? pageNumber;

  const PersistentPageOverlay({
    super.key,
    this.surahName,
    this.juzNumber,
    this.pageNumber,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Stack(
            children: [
              if (surahName != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: HeaderBadge(text: surahName!),
                ),
              if (juzNumber != null)
                Positioned(
                  top: 0,
                  left: 0,
                // Same convention as the surah name above (and as
                // `mushaf_nav_sheets.dart`'s own juz list): a real
                // mushaf's own running header is always Arabic — it's
                // part of the page's own printed identity, not app UI
                // chrome that follows the interface locale.
                  child:
                      HeaderBadge(
                          text: '${'quran.juz'.tr()} ${arabicPageNumber(juzNumber!)}'),
                ),
              if (pageNumber != null)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: PageNumberBadge(page: pageNumber!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A mushaf page number, always in Arabic-Indic digits — every printing sets
/// them that way, whatever language the app is in. The conversion itself
/// comes from `core/utils/digits.dart`; this was the fifth copy of it.
String arabicPageNumber(int n) => localizeDigits('$n', 'ar');

/// P3‑51: a uniform, perfectly-centred badge for the running header.
///
/// Arabic (esp. the AmiriQuran calligraphy face, with its large internal
/// metrics and tashkeel marks that sit above/below the glyph body) does not
/// vertically centre inside a box by default — the baseline drifts. The fix,
/// applied here and in [PageNumberBadge], is: `alignment: center` on the box,
/// plus `StrutStyle(forceStrutHeight, height:1.0, leading:0)` and a
/// `TextHeightBehavior` that trims the first-ascent/last-descent, so the line
/// box collapses to the font size and the glyph lands in the geometric centre.
class HeaderBadge extends StatelessWidget {
  final String text;
  const HeaderBadge({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const fontSize = 13.0;
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        strutStyle: const StrutStyle(
          fontFamily: 'AmiriQuran',
          fontSize: fontSize,
          height: 1.0,
          leading: 0,
          forceStrutHeight: true,
        ),
        textHeightBehavior: const TextHeightBehavior(
          applyHeightToFirstAscent: false,
          applyHeightToLastDescent: false,
        ),
        style: const TextStyle(
          fontFamily: 'AmiriQuran',
          fontSize: fontSize,
          height: 1.0,
          fontWeight: FontWeight.w600,
          color: AppColors.gold,
        ),
      ),
    );
  }
}

/// P3‑51: the page-number badge — a real circle with the Arabic-Indic page
/// number geometrically centred (same centring recipe as [HeaderBadge]).
/// Used both in the normal-mode bottom info bar and, in full-screen, floated
/// at the bottom of the reserved strip.
class PageNumberBadge extends StatelessWidget {
  final int page;
  const PageNumberBadge({super.key, required this.page});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.55),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
      ),
      child: Text(
        arabicPageNumber(page),
        textAlign: TextAlign.center,
        strutStyle: const StrutStyle(
          fontFamily: 'AmiriQuran',
          fontSize: 14,
          height: 1.0,
          leading: 0,
          forceStrutHeight: true,
        ),
        textHeightBehavior: const TextHeightBehavior(
          applyHeightToFirstAscent: false,
          applyHeightToLastDescent: false,
        ),
        style: const TextStyle(
          fontFamily: 'AmiriQuran',
          fontSize: 14,
          height: 1.0,
          fontWeight: FontWeight.w700,
          color: AppColors.gold,
        ),
      ),
    );
  }
}

/// P3‑39: the auto-scroll speed control — a plain labelled `Slider` over a
/// real pixels/second range (15–120) rather than an opaque "slow/medium/
/// fast" enum, so a reader can actually tune it to their own reading pace.
/// Only ever built while auto-scroll is on (see the call site).
