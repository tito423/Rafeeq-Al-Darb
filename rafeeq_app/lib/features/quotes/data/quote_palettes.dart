/// The colour schemes a shareable quote card can be painted in.
///
/// Moved out of `quote_card_screen.dart`. `test/quote_palette_contrast_test.dart`
/// already read this list as data - it just had to reach into a screen file to
/// do it.
library;

import 'package:flutter/material.dart';

/// One background: two ends of a gradient, the ornament's colour, and the ink
/// the saying is set in.
///
/// The ink is not chosen by eye. CLAUDE.md trap #15 — «a translucent
/// highlight over a dark ground composites dark, however bright the colour
/// looks on its own» — cost three mushaf themes a contrast failure, so every
/// pairing here is checked by `test/quote_palette_contrast_test.dart` against
/// the 4.5:1 floor, computed on the composited result rather than on the
/// swatch.
class QuotePalette {
  final Color top;
  final Color bottom;
  final Color ornament;
  final Color ink;
  final Color muted;

  const QuotePalette({
    required this.top,
    required this.bottom,
    required this.ornament,
    required this.ink,
    required this.muted,
  });
}

const List<QuotePalette> kQuotePalettes = [
  // Deep night blue — the app's own dark ground.
  QuotePalette(
    top: Color(0xFF0B1F33),
    bottom: Color(0xFF071626),
    ornament: Color(0x33D4AF37),
    ink: Color(0xFFF2F6FA),
    muted: Color(0xFFB8C6D4),
  ),
  // Mihrab green.
  QuotePalette(
    top: Color(0xFF0C2B24),
    bottom: Color(0xFF061A16),
    ornament: Color(0x33E0C060),
    ink: Color(0xFFF1F8F4),
    muted: Color(0xFFB2CFC1),
  ),
  // Aubergine, the tile colour of the carousel.
  QuotePalette(
    top: Color(0xFF241436),
    bottom: Color(0xFF150B20),
    ornament: Color(0x33C9A0FF),
    ink: Color(0xFFF6F1FA),
    muted: Color(0xFFC9BBD8),
  ),
  // Desert ink — warm, still dark enough for gold ornament.
  QuotePalette(
    top: Color(0xFF2E1D10),
    bottom: Color(0xFF1A1009),
    ornament: Color(0x33F0C674),
    ink: Color(0xFFFAF3E8),
    muted: Color(0xFFD8C4A8),
  ),
  // Teal, the Sources screen's accent.
  QuotePalette(
    top: Color(0xFF07262B),
    bottom: Color(0xFF04171A),
    ornament: Color(0x3355D6C2),
    ink: Color(0xFFEFF9F8),
    muted: Color(0xFFAFCFCB),
  ),
  // Slate, for the days a colour would be too much.
  QuotePalette(
    top: Color(0xFF1C2230),
    bottom: Color(0xFF11151E),
    ornament: Color(0x33A8B6CC),
    ink: Color(0xFFF3F5F9),
    muted: Color(0xFFBCC4D2),
  ),
];
