/// Mosque photographs behind the Home cards and the full-screen saying.
///
/// Owner, 2026-10-08: «خلي كل كروت الشاشة الرئيسية لها خلفية مسجد زي
/// الكارتين الاولانيين ويبقى كل مسجد مختلف بشكل هادي وجميل … وخلي خلفية
/// المقولة برده مسجد جميل في شاشتها الكبيرة». Every photo here is already
/// bundled and credited on the Sources screen (Wikimedia Commons, each under
/// its own free licence - azkar_backgrounds.dart, about.src_azkar_bg,
/// quote_backgrounds.json); nothing new is fetched.
library;

import 'package:flutter/material.dart';

abstract final class MosquePhotos {
  static const blueMosque = 'assets/azkar_cards/waking.jpg';
  static const meknes = 'assets/azkar_cards/mosque.jpg';
  static const vakil = 'assets/azkar_background/vakil_mosque.jpg';
  static const alMuizz = 'assets/azkar_cards/sleep.jpg';
  static const suleymaniye = 'assets/azkar_cards/afterPrayer.jpg';
  static const ummAlFahm = 'assets/azkar_cards/evening.jpg';
  static const faisal = 'assets/azkar_cards/morning.jpg';
  static const abuHanifa =
      'assets/quote_backgrounds/abu_hanifa_mosque_muqarnas.jpg';

  /// Whole mosques only, wide and calm, for the full-screen saying (owner:
  /// «مساجد برده كبيرة وجميلة وهادية بس») - no close-up of a carpet or a
  /// ceiling.
  static const wide = [
    blueMosque,
    meknes,
    vakil,
    alMuizz,
    ummAlFahm,
    faisal,
  ];

  static const all = [
    blueMosque,
    meknes,
    vakil,
    alMuizz,
    suleymaniye,
    ummAlFahm,
    faisal,
    abuHanifa,
  ];
}

/// A card with a mosque photograph laid faintly over it, the way the first
/// two Home cards carry theirs: present, calm, and never in the way of the
/// text. It takes no taps.
class MosqueBackdrop extends StatelessWidget {
  final String photo;
  final Widget child;

  /// The card's own corner, so the photo stays inside it.
  final double radius;
  const MosqueBackdrop({
    super.key,
    required this.photo,
    required this.child,
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: Opacity(
                opacity: dark ? 0.16 : 0.12,
                child: Image.asset(
                  photo,
                  fit: BoxFit.cover,
                  cacheWidth: 900,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
