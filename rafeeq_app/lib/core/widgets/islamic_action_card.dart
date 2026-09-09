import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'islamic_pattern.dart';

/// A tappable card with an illuminated Islamic ground.
///
/// The owner asked for every card in the app to carry «خلفيه اسلامية جميله …
/// في تناسق مع الالوان والثيمات المختلفة» — so this is one widget rather than
/// a decoration copy-pasted per screen, and it takes its colours from
/// [AppColors] and its own [accent] so it sits correctly in every theme
/// instead of being a fixed picture that only works on one background.
///
/// The lattice is painted, not an image, for the same reason
/// [IslamicPatternPanel]'s is: the app is offline-first, and a card whose
/// background only appears once the network answers is a card that looks
/// broken on a plane.
class IslamicActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  /// Tints the border, the icon medallion, the lattice and the glow.
  final Color accent;

  final VoidCallback onTap;

  /// Shown at the trailing edge instead of the chevron — a badge, a count, a
  /// progress ring.
  final Widget? trailing;

  const IslamicActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent = AppColors.gold,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  Color.lerp(AppColors.nightSurface, accent, 0.20)!,
                  AppColors.nightElevated,
                ],
              ),
              border: Border.all(color: accent.withValues(alpha: 0.34)),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.16),
                  blurRadius: 22,
                  spreadRadius: -8,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: IslamicPatternPainter(
                          tile: 50,
                          color: accent.withValues(alpha: 0.10),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 15, 14, 15),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accent.withValues(alpha: 0.16),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.45),
                            ),
                          ),
                          child: Icon(icon, color: accent, size: 24),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  color: AppColors.textHigh,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                subtitle,
                                style: const TextStyle(
                                  color: AppColors.textMedium,
                                  fontSize: 12,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // `chevron_right`, never `chevron_left`: Flutter
                        // auto-mirrors `chevron_left` under RTL, so in Arabic
                        // it would end up pointing the wrong way. Ten of these
                        // pointed backwards in this app once.
                        trailing ??
                            Icon(
                              Icons.chevron_right,
                              color: accent.withValues(alpha: 0.75),
                            ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
