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
