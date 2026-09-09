import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/card_route.dart';
import '../../data/mushaf_theme.dart';

/// The ten themes for the text mushaf, each previewed on real Qur'an text.
///
/// The preview is a real ayah set in the real mushaf font at a readable size,
/// with a real highlighted verse in it — not a colour swatch. A swatch cannot
/// answer the question the reader is actually asking, which is "can I read
/// this, and can I still see which verse is being recited?"
class MushafThemePicker extends ConsumerWidget {
  const MushafThemePicker({super.key});

  static Future<void> show(BuildContext context, {BuildContext? origin}) =>
      showCardScreen<void>(
        context: context,
        originContext: origin,
        child: const MushafThemePicker(),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(mushafThemeProvider);
    final notifier = ref.read(mushafThemeProvider.notifier);

    return CardScreen(
      title: 'mushaf_theme.title'.tr(),
      subtitle: 'mushaf_theme.subtitle'.tr(),
      icon: Icons.palette_outlined,
      accent: AppColors.gold,
      maxWidth: 520,
      maxHeightFraction: 0.88,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // "Follow the app theme" — the default, and the way back to it.
          _FollowAppTile(
            selected: selected == null,
            onTap: () => notifier.select(null),
          ),
          const SizedBox(height: 10),
          for (final t in mushafThemes) ...[
            _ThemeTile(
              theme: t,
              selected: selected == t.id,
              onTap: () => notifier.select(t.id),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _FollowAppTile extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const _FollowAppTile({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: selected
                ? AppColors.gold
                : Colors.white.withValues(alpha: 0.12),
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              size: 20,
              color: selected ? AppColors.gold : AppColors.textLow,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'mushaf_theme.follow_app'.tr(),
                style: const TextStyle(
                  color: AppColors.textHigh,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final MushafTheme theme;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeTile({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  /// Al-Fatiha 1–2, the verses every reader knows by heart — so the preview is
  /// judged on how it *looks*, not read for content.
  static const _sample = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';
  static const _sampleHighlighted = 'ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَٰلَمِينَ';

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? AppColors.gold
                : Colors.white.withValues(alpha: 0.12),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.28),
                    blurRadius: 18,
                    spreadRadius: -4,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: ColoredBox(
            color: theme.paper,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        size: 17,
                        color: theme.gold,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          theme.labelKey.tr(),
                          style: TextStyle(
                            color: theme.ink,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      // The medallion, in this theme's gold.
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: theme.gold, width: 1.2),
                        ),
                        child: Center(
                          child: Text(
                            '١',
                            style: TextStyle(
                              color: theme.gold,
                              fontSize: 10,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _sample,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'AmiriQuran',
                      fontSize: 17,
                      height: 1.9,
                      color: theme.ink,
                    ),
                  ),
                  // The same line again, but highlighted the way a verse being
                  // recited is — which is the half of the theme that a colour
                  // swatch cannot show.
                  Text(
                    _sampleHighlighted,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'AmiriQuran',
                      fontSize: 17,
                      height: 1.9,
                      color: theme.inkOnHighlight,
                      backgroundColor: theme.highlightPlaying,
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
