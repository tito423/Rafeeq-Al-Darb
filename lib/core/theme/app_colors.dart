import 'package:flutter/material.dart';

/// App-wide color palette — Royal Blue & Gold theme
class AppColors {
  AppColors._();

  // ── Brand ────────────────────────────────────────────────────────────────
  static const Color primaryBlue   = Color(0xFF0F1714); // Sakanati Dark Forest Green (reusing variable name for compatibility temporarily)
  static const Color primaryBlue2  = Color(0xFF14251D); // Secondary Dark Green
  static const Color accentGold    = Color(0xFFF59E0B); // Amber / Gold
  static const Color accentGold2   = Color(0xFF10B981); // Emerald Green (repurposing accentGold2 for the emerald)

  // ── On-Primary ───────────────────────────────────────────────────────────────
  static const Color lightOnPrimary = Colors.white;
  static const Color darkOnPrimary  = Colors.white;

  // ── Light theme ──────────────────────────────────────────────────────────
  static const Color lightBackground    = Color(0xFFFAF7F0);
  static const Color lightSurface       = Color(0xFFFFFFFF);
  static const Color lightCardBackground= Color(0xFFEEE8DA);
  static const Color lightOnSurface     = Color(0xFF1A1A2E);
  static const Color lightSubtext       = Color(0xFF6B6B8A);
  static const Color lightNavBar        = Color(0xFFFFFFFF);
  static const Color lightDivider       = Color(0xFFE0D8C8);

  // ── Dark theme (Sakanati style) ──────────────────────────────────────────
  static const Color darkBackground     = Color(0xFF0A100E); // Deepest dark green/black
  static const Color darkSurface        = Color(0xFF14251D); // Card background
  static const Color darkCardBackground = Color(0xFF14251D);
  static const Color darkOnSurface      = Color(0xFFE8E4D4);
  static const Color darkSubtext        = Color(0xFF8A8FAA);
  static const Color darkNavBar         = Color(0xFF0A100E);
  static const Color darkDivider        = Color(0xFF1A3326);

  // ── Semantic ─────────────────────────────────────────────────────────────
  static const Color success   = Color(0xFF10B981); // Emerald
  static const Color warning   = Color(0xFFF59E0B);
  static const Color error     = Color(0xFFEF4444);
  static const Color info      = Color(0xFF3B82F6);

  // ── Prayer colors ────────────────────────────────────────────────────────
  static const Color fajrColor    = Color(0xFF6C5CE7);
  static const Color sunriseColor = Color(0xFFE17055);
  static const Color dhuhrColor   = Color(0xFF3B82F6);
  static const Color asrColor     = Color(0xFF10B981);
  static const Color maghribColor = Color(0xFFE84393);
  static const Color ishaColor    = Color(0xFF6C5CE7);
}
