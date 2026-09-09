import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/card_route.dart';
import '../../data/mushaf_frame.dart';
import '../../data/mushaf_theme.dart';
import 'mushaf_frame_painter.dart';

/// The ten themes for the text mushaf, each previewed on real Qur'an text.
///
/// The preview is a real ayah set in the real mushaf font at a readable size,
/// with a real highlighted verse in it — not a colour swatch. A swatch cannot
/// answer the question the reader is actually asking, which is "can I read
/// this, and can I still see which verse is being recited?"
class MushafThemePicker extends ConsumerStatefulWidget {
  const MushafThemePicker({super.key});

  static Future<void> show(BuildContext context, {BuildContext? origin}) =>
      showCardScreen<void>(
        context: context,
        originContext: origin,
        child: const MushafThemePicker(),
      );

  @override
  ConsumerState<MushafThemePicker> createState() => _MushafThemePickerState();
}

/// Theme, frame and frame-colour in one card, because they are one decision:
/// the frame is drawn in the theme's own accent unless it is deliberately
/// overridden, so choosing them apart would let the reader build a pairing
/// that clashes without ever seeing it.
class _MushafThemePickerState extends ConsumerState<MushafThemePicker>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(mushafThemeProvider);
    final notifier = ref.read(mushafThemeProvider.notifier);
    final frame = ref.watch(mushafFrameProvider);
    final frameNotifier = ref.read(mushafFrameProvider.notifier);

    // Every preview below is drawn on the *active* theme's paper in the
    // active frame colour, so what the tile shows is what the page will look
    // like — not the ornament floating on a neutral card.
    final activeTheme =
        resolveMushafTheme(selected, Theme.of(context).brightness);
    final frameColor = frame.accent.color ?? activeTheme.gold;

    return CardScreen(
      title: 'mushaf_theme.title'.tr(),
      subtitle: 'mushaf_theme.subtitle'.tr(),
      icon: Icons.palette_outlined,
      accent: AppColors.gold,
      maxWidth: 520,
      maxHeightFraction: 0.9,
      scrollable: false,
      child: Column(
        children: [
          TabBar(
            controller: _tabs,
            indicatorColor: AppColors.gold,
            labelColor: AppColors.textHigh,
            unselectedLabelColor: AppColors.textLow,
            labelStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            tabs: [
              Tab(text: 'mushaf_theme.tab_theme'.tr()),
              Tab(text: 'mushaf_theme.tab_frame'.tr()),
              Tab(text: 'mushaf_theme.tab_colour'.tr()),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                  children: [
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
                GridView.count(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.86,
                  children: [
                    for (final f in MushafFrameStyle.values)
                      _FrameTile(
                        style: f,
                        theme: activeTheme,
                        colour: frameColor,
                        selected: frame.style == f,
                        onTap: () => frameNotifier.setStyle(f),
                      ),
                  ],
                ),
                GridView.count(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.92,
                  children: [
                    for (final a in MushafFrameAccent.values)
                      _AccentTile(
                        accent: a,
                        theme: activeTheme,
                        selected: frame.accent == a,
                        onTap: () => frameNotifier.setAccent(a),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One frame style, drawn on the active theme's own paper.
class _FrameTile extends StatelessWidget {
  final MushafFrameStyle style;
  final MushafTheme theme;
  final Color colour;
  final bool selected;
  final VoidCallback onTap;

  const _FrameTile({
    required this.style,
    required this.theme,
    required this.colour,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.gold
                : Colors.white.withValues(alpha: 0.12),
            width: selected ? 2 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: ColoredBox(
            color: theme.paper,
            child: Column(
              children: [
                Expanded(
                  child: MushafFrame(
                    style: style,
                    color: colour,
                    child: Center(
                      child: Text(
                        '\u0628\u0650\u0633\u0652\u0645\u0650 \u0671\u0644\u0644\u064e\u0651\u0647\u0650',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontFamily: 'AmiriQuran',
                          fontSize: 15,
                          color: theme.ink,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 7, left: 4, right: 4),
                  child: Text(
                    style.labelKey.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.ink.withValues(alpha: 0.75),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One frame colour, shown as a real corner of a real frame rather than a dot
/// — a swatch cannot show how a colour reads as thin ornament on that paper.
class _AccentTile extends StatelessWidget {
  final MushafFrameAccent accent;
  final MushafTheme theme;
  final bool selected;
  final VoidCallback onTap;

  const _AccentTile({
    required this.accent,
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colour = accent.color ?? theme.gold;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: theme.paper,
          border: Border.all(
            color: selected
                ? AppColors.gold
                : Colors.white.withValues(alpha: 0.12),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 54,
              height: 40,
              child: CustomPaint(
                painter: MushafFramePainter(
                  style: MushafFrameStyle.khatim,
                  color: colour,
                  band: 11,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              accent.labelKey.tr(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: theme.ink.withValues(alpha: 0.78),
              ),
            ),
          ],
        ),
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
