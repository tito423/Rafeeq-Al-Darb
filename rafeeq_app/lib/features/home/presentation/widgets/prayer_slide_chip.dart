import 'package:flutter/material.dart';

import '../../../../core/theme/hero_surface.dart';
import '../../../../core/widgets/remote_tap.dart';

/// One prayer's chip in the Home carousel: a photograph of a mosque at that
/// prayer's hour, darkened and tinted with the prayer's colour. Split out of
/// `prayer_slides.dart` to keep both under the file-size ceiling.
class PrayerSlideChip extends StatelessWidget {
  /// Which prayer: its photograph (`assets/prayer_backgrounds/<key>.jpg`) is
  /// the slide's ground, so the slide says which prayer it is before it is
  /// read (owner, 2026-09-29).
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
    // The slide stands on a photograph of a mosque at that prayer's hour,
    // darkened by a scrim (measured: white text >= 5.7 : 1 on every one, see
    // the prayer card) and tinted with the prayer's own colour - stronger on
    // the next and the focused slide. So the text is white whatever the theme.
    final onPhoto = HeroSurface.dark;
    final accent = onPhoto.accent(color);
    final radius = BorderRadius.circular(18);
    return RemoteTap(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        width: 96,
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/prayer_backgrounds/$prayerKey.jpg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: filled ? 0.58 : 0.68),
              BlendMode.srcOver,
            ),
          ),
          borderRadius: radius,
          border: Border.all(
            color: isFocused
                ? Colors.white.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.12),
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
        foregroundDecoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: filled ? 0.42 : 0.2),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: filled ? Colors.white : accent),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                shadows: [Shadow(color: Color(0xCC000000), blurRadius: 4)],
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
                  color: Colors.white.withValues(alpha: 0.92),
                  shadows: const [
                    Shadow(color: Color(0xCC000000), blurRadius: 4),
                  ],
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
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
            // The affordance that this slide opens into something. It is an
            // "expand" glyph rather than a chevron because the card no longer
            // unfolds downward — it opens as its own screen.
            Icon(
              Icons.open_in_full_rounded,
              size: 13,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ],
        ),
      ),
    );
  }
}
