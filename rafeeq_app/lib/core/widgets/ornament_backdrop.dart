import 'package:flutter/material.dart';

/// A faint Islamic ornament behind a Home card's text (owner, 2026-09-29:
/// «حط خلفيات لكارت السنن … ولحديث اليوم … ولمقولة اليوم … والنصوص واضحة
/// والخلفيات مش تتعارض مع الثيمات»).
///
/// The picture is one of the bundled ornament scans (the public-domain / CC0
/// set the quote and azkar cards already use, credited on the Sources
/// screen), laid OVER the card's own theme ground at a low opacity - so the
/// card keeps the theme's colour and the theme's text tones, and the ornament
/// is a texture in it, not a ground of its own. The two strengths are the
/// highest at which every body and secondary tone still clears 4.5 : 1 on
/// every scan used here (`scripts/check_ornament_card_contrast.py`).
class OrnamentBackdrop extends StatelessWidget {
  static const _dir = 'assets/quote_backgrounds';

  /// A mosque's muqarnas dome, for the sunnah surahs - its top band only:
  /// lower down, the chandelier's chain ran through the text like a crack
  /// (assets/card_ornaments/SOURCES.json).
  static const sunan = 'assets/card_ornaments/muqarnas_band.jpg';

  /// A geometric star panel, for the hadith of the day.
  static const hadith = '$_dir/dado_panel2.jpg';

  /// Cycled through the quote-of-the-day pages (not the star panel: the
  /// hadith card just below already has it).
  static const quotes = [
    '$_dir/l_ornement_polychrome_met_dp146521.jpg',
    '$_dir/ornament_sborn_k_slohov_ch_ozdob_v_ech_obdob_um_.jpg',
    '$_dir/turquoise_muqarna_mba_lyon_1969_331.jpg',
  ];

  /// The hadith card carries the longest text on Home, and the star panel's
  /// pale strapwork crossed it busily at full strength (emulator-5554,
  /// 2026-09-29), so it is drawn calmer.
  static const hadithDark = 0.13;
  static const hadithLight = 0.11;

  /// The quote card's grounds are tinted, which leaves less room, so its
  /// scans are drawn fainter.
  static const quoteDark = 0.16;
  static const quoteLight = 0.13;

  final String asset;
  final BorderRadius radius;
  final double darkStrength;
  final double lightStrength;
  final Widget child;

  const OrnamentBackdrop({
    super.key,
    required this.asset,
    required this.radius,
    this.darkStrength = 0.20,
    this.lightStrength = 0.15,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Image.asset(
                asset,
                fit: BoxFit.cover,
                cacheWidth: 700,
                opacity: AlwaysStoppedAnimation(
                  dark ? darkStrength : lightStrength,
                ),
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
