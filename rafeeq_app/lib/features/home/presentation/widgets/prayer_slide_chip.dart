import 'package:flutter/material.dart';

import '../../../../core/theme/hero_surface.dart';
import '../../../../core/widgets/remote_tap.dart';

/// One prayer's chip in the Home carousel. Split out of `prayer_slides.dart`
/// to keep both under the file-size ceiling.
///
/// The chips have no photograph of their own any more: the whole prayer card
/// stands on ONE photograph (owner, 2026-09-29: «الخلفية دي تغطي الكارت
/// الأكبر … مش يبقى كل واحد فيهم منفرد»), so a chip is a pane of glass on
/// it - dark glass in the dark themes, frosted white in the light one - and
/// the next / focused prayer is filled with its own colour.
class PrayerSlideChip extends StatelessWidget {
  final String prayerKey;
  final String label;
  final String time;
  final Color color;
  final IconData icon;
  final bool isNext;
  final bool isFocused;
  final int offsetMinutes;
  final VoidCallback onTap;

  const PrayerSlideChip({
    super.key,
    required this.prayerKey,
    required this.label,
    required this.time,
    required this.color,
    required this.icon,
    required this.isNext,
    required this.isFocused,
    required this.offsetMinutes,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final filled = isNext || isFocused;
    final hero = HeroSurface.of(context);
    // Filled: the prayer's colour with white on it (hero.chipFill/onChip).
    // Glass: the card's own foreground tones, measured on the washed photo
    // by scripts/check_prayer_card_contrast.py.
    final ground = filled
        ? hero.chipFill(color)
        : (hero.isDark
              ? Colors.black.withValues(alpha: 0.32)
              : Colors.white.withValues(alpha: 0.62));
    final ink = filled ? hero.onChip : hero.onSurface;
    final muted = filled ? hero.onChip : hero.onSurfaceMuted;
    final radius = BorderRadius.circular(18);
    return RemoteTap(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        width: 96,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: ground,
          borderRadius: radius,
          border: Border.all(
            color: isFocused
                ? ink.withValues(alpha: 0.75)
                : (hero.isDark
                      ? Colors.white.withValues(alpha: 0.16)
                      : hero.border),
            width: 1.4,
          ),
          boxShadow: filled
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 16,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: filled ? ink : hero.accent(color)),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
            const SizedBox(height: 3),
            // Scaled down, not clipped: at the largest system font «12:11 PM»
            // is wider than the 96 dp slide and maxLines cut the «PM» off
            // (owner's phone, font scale 1.45, 2026-09-25). A one-digit hour
            // fitted, so only some slides lost it.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                time,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: muted,
                ),
              ),
            ),
            // An honest marker that this timing is not the calculated one.
            if (offsetMinutes != 0) ...[
              const SizedBox(height: 2),
              Text(
                offsetMinutes > 0 ? '+$offsetMinutes' : '$offsetMinutes',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: muted,
                ),
              ),
            ],
            // The affordance that this slide opens into something. It is an
            // "expand" glyph rather than a chevron because the card no longer
            // unfolds downward — it opens as its own screen.
            Icon(Icons.open_in_full_rounded, size: 13, color: muted),
          ],
        ),
      ),
    );
  }
}
