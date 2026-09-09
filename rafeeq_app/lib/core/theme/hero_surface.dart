import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The palette for the app's "hero" surfaces — the ones that are a coloured
/// ground of their own rather than a plain card: the Home clock card and its
/// prayer carousel, and the four destination cards at the top of «المزيد».
///
/// WHY THIS EXISTS
/// Those surfaces were a **fixed dark gradient in every theme**, on an earlier
/// instruction («RGB في جميع الثيمات») that made them one visual family
/// regardless of the theme chosen. The owner has since asked for the opposite:
/// «كروت الساعة وشرايح مواقيت الصلاة والأربع كروت الأولانيين في المزيد دايمًا
/// دارك ثيم مش بيتغيروا مع الثيم المختار — صلّحهم». So the family stays, but
/// it now has a light member: one place decides the gradient, the border, the
/// glow and the three text tones, and every one of those surfaces asks here
/// instead of writing `Colors.white70` into itself.
///
/// The dark and RGB themes keep exactly the colours they had, so nothing the
/// owner already approved moves; only the light theme is new.
///
/// Every foreground tone below clears 4.5:1 against the *composited* ground it
/// actually sits on — computed, not eyeballed (CLAUDE.md trap #15): a
/// translucent scrim over a gradient is neither of the two colours you can
/// see, and three mushaf themes shipped at 2.3:1 by judging that by eye.
/// `scripts/check_hero_contrast.py` recomputes them.
@immutable
class HeroSurface {
  /// Top-left to bottom-right, three stops.
  final List<Color> gradient;

  /// The hairline around the card.
  final Color border;

  /// The cast under the card, so it lifts off the page.
  final Color glow;

  /// Titles and the clock face.
  final Color onSurface;

  /// Secondary lines — the next-prayer label, a slide's time.
  final Color onSurfaceMuted;

  /// The quietest tone: the location line, a dimmed neighbour slide.
  final Color onSurfaceFaint;

  /// The translucent pill drawn *on* the gradient (the countdown's
  /// background, a slide's chip).
  final Color scrim;

  /// A divider or hairline drawn on the gradient.
  final Color hairline;

  /// The ground for a sheet that opens out of one of these cards.
  final Color sheetBackground;

  final bool isDark;

  const HeroSurface({
    required this.gradient,
    required this.border,
    required this.glow,
    required this.onSurface,
    required this.onSurfaceMuted,
    required this.onSurfaceFaint,
    required this.scrim,
    required this.hairline,
    required this.sheetBackground,
    required this.isDark,
  });

  static const _dark = HeroSurface(
    gradient: [Color(0xFF0B0F1A), Color(0xFF102A3A), Color(0xFF1B1533)],
    border: Color(0x5915C7B0),
    glow: Color(0x2915C7B0),
    onSurface: Colors.white,
    onSurfaceMuted: Color(0xFFB9C6C3),
    onSurfaceFaint: Color(0xFF93A5A1),
    scrim: Color(0x14FFFFFF),
    hairline: Color(0x1FFFFFFF),
    sheetBackground: Color(0xFF0E1626),
    isDark: true,
  );

  /// The light member of the same family: the same three hues, lifted to
  /// paper. Mint → sea → lilac, so the card still reads as the app's own
  /// object and not as a plain white rectangle.
  static const _light = HeroSurface(
    gradient: [Color(0xFFFAFDFC), Color(0xFFDFEFEA), Color(0xFFE9E5F5)],
    border: Color(0x590E7C6B),
    glow: Color(0x1F0E7C6B),
    onSurface: Color(0xFF10231D),
    onSurfaceMuted: Color(0xFF3A4B45),
    onSurfaceFaint: Color(0xFF4E605A),
    scrim: Color(0x140E7C6B),
    hairline: Color(0x1F0E7C6B),
    sheetBackground: Color(0xFFF4FAF8),
    isDark: false,
  );

  /// The palette for the theme in force. RGB is a dark theme and keeps the
  /// dark member — its neon look is the point of it.
  static HeroSurface of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dark : _light;

  /// The six prayer colours as **text** on this ground.
  ///
  /// `prayerSlideColors` are chip fills, and four of them were never legible
  /// as text: on the dark card the violet Fajr label measured **2.43 : 1** and
  /// the brown Sunrise 2.53 : 1, which is the same failure CLAUDE.md trap #15
  /// records for three mushaf themes. Each entry below is the smallest nudge
  /// toward the ground's own foreground that clears 4.6 : 1 on every gradient
  /// stop *and* under the scrim — solved, not chosen, and re-checked by
  /// `scripts/check_hero_contrast.py`.
  // Keyed by the fill's ARGB value, not by [Color]: a const map cannot take
  // a key whose class overrides the equality operator, and [Color] does.
  static const _darkAccents = <int, Color>{
    0xFF7C4DFF: Color(0xFFAE91FF), // fajr     2.43 -> 4.63
    0xFF8D6E63: Color(0xFFB49F98), // sunrise  2.53 -> 4.66
    0xFF2F80A9: Color(0xFF74AAC5), // dhuhr    2.67 -> 4.63
    0xFF2E9D6F: Color(0xFF5CB38F), // asr      3.44 -> 4.63
    0xFFD4AF37: Color(0xFFD4AF37), // maghrib  already 5.57
    0xFF15C7B0: Color(0xFF15C7B0), // isha     already 5.48
  };

  static const _lightAccents = <int, Color>{
    0xFF7C4DFF: Color(0xFF6742D4), // fajr
    0xFF8D6E63: Color(0xFF715B51), // sunrise
    0xFF2F80A9: Color(0xFF256684), // dhuhr
    0xFF2E9D6F: Color(0xFF206C4D), // asr
    0xFFD4AF37: Color(0xFF6D6023), // maghrib
    0xFF15C7B0: Color(0xFF0D6C5F), // isha
  };

  /// [base] toned so it can be read as text here. A colour with no measured
  /// entry is returned unchanged rather than guessed at.
  Color accent(Color base) =>
      (isDark ? _darkAccents : _lightAccents)[base.toARGB32()] ?? base;

  /// A filled chip's ground for [base], and the colour of text on it.
  Color chipFill(Color base) => isDark
      ? base
      : Color.lerp(base, const Color(0xFFFFFFFF), 0.10)!;

  /// Text on a chip filled with [chipFill] — white on both grounds, since a
  /// filled chip is a saturated colour either way.
  Color get onChip => Colors.white;

  /// The tint used where a surface needs the app's primary rather than one of
  /// the prayer colours.
  Color get primary => isDark ? AppColors.primarySoft : AppColors.primary;
}
