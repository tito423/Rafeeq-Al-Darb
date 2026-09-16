import 'package:flutter/material.dart';

/// Rafeeq Al-Darb — Master Color System
/// Mix: Sakinati's calm night-teal + Ayat's authentic paper reading +
/// Gold illumination accents in the classic mushaf tradition.
abstract final class AppColors {
  // ── Brand core (night mode first) ────────────────────────────────
  static const Color night = Color(0xFF071625); // deep navy — scaffold
  static const Color nightElevated = Color(0xFF0C2135); // cards/sheets
  static const Color nightSurface = Color(0xFF10293F); // elevated cards
  static const Color nightBorder = Color(0xFF1E3A52); // hairlines

  // ── Primary (calm teal-green — Sakinati) ─────────────────────────
  static const Color primary = Color(0xFF0E7C61);
  static const Color primarySoft = Color(0xFF16A085);
  static const Color primaryContainer = Color(0xFF0F3D33);

  // ── Accent (illuminated gold) ────────────────────────────────────
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldSoft = Color(0xFFE8C96A);
  static const Color goldContainer = Color(0xFF3A2F14);

  // ── Mushaf paper (reading mode — Ayat) ───────────────────────────
  static const Color paper = Color(0xFFF8F4E9);
  static const Color paperDark = Color(0xFFEFE6D0);
  static const Color ink = Color(0xFF241C0E); // mushaf text ink
  static const Color inkSoft = Color(0xFF6B5D45);

  // ── Light theme surfaces ─────────────────────────────────────────
  static const Color lightScaffold = Color(0xFFF6F8F7);
  static const Color lightSurface = Colors.white;
  static const Color lightBorder = Color(0xFFE2E8E6);

  // ── Semantic ─────────────────────────────────────────────────────
  static const Color success = Color(0xFF2E9E6B);
  static const Color warning = Color(0xFFE3A008);
  static const Color error = Color(0xFFC0453B);
  static const Color info = Color(0xFF2F80A9);

  // ── Text on dark ─────────────────────────────────────────────────
  static const Color textHigh = Color(0xFFF2F5F4);
  static const Color textMedium = Color(0xFFB7C4C0);
  static const Color textLow = Color(0xFF7E908B);

  // Ayah highlight (tap-to-highlight — used by mushaf overlay)
  static const Color ayahHighlight = Color(0x5D16A085);
  static const Color ayahHighlightPlaying = Color(0x5DD4AF37);
}

/// Gold that keeps its contrast on whatever theme is on.
///
/// [AppColors.gold] is a night-mode colour. Used as TEXT or an icon over a
/// light theme it measures **2.10 : 1** against white and **1.90 : 1** against
/// the About hero's pale ground, where the floor is 4.5 : 1 — which is the
/// owner's «الوان الكتابة والخطوط مش بتبقى واضحة في الثيم النهاري», as a
/// number. [AppColors.goldSoft] is worse: 1.62 : 1.
///
/// Blending the gold halfway into the scheme's own `onSurface` gives a colour
/// that is still read as gold and is legible on both:
///
/// | ground                    | result   | contrast |
/// |---------------------------|----------|----------|
/// | light, white surface      | #736A2A  | 5.49 : 1 |
/// | light, scaffold #F6F8F7   | #736A2A  | 5.15 : 1 |
/// | light, About hero pale    | #736A2A  | 4.91 : 1 |
/// | dark, nightSurface        | #E3D296  | 9.87 : 1 |
/// | rgb, #0A0E1A              | #E3D296  | 12.6 : 1 |
///
/// Measured, not judged by eye — trap #15 in `CLAUDE.md` is exactly this
/// mistake made once already.
///
/// Use it for gold **text, icons and hairlines drawn on a theme surface**.
/// Do NOT use it on a surface that is dark in every theme (the mushaf's own
/// night pages, the splash, a hero panel with its own fixed dark gradient):
/// there the flat [AppColors.gold] is correct and this would dull it.
Color goldOn(ColorScheme scheme) => Color.alphaBlend(
      AppColors.gold.withValues(alpha: 0.50),
      scheme.onSurface,
    );
