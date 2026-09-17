/// «العرض» — every reading preference for the mushaf, grouped and showing
/// its current value.
///
/// WHAT THIS REPLACED, and why. The Qur'an tab carried **eleven** captioned
/// icons in a two-row `Wrap` above the text: layout, smaller, larger,
/// auto-scroll, recitation, themes, full screen, search, surahs, juz, jump,
/// editions, mode. The owner's verdict was «شكلهم بدائي اوي».
///
/// Three things were wrong with it, and only the third is cosmetic:
///
///  1. **It answered nothing.** Every tile was an icon and a verb. Nothing
///     said which layout you were in, how large the text currently was, or
///     which page colour was set — so the only way to find out was to press
///     something and watch the page change.
///  2. **Three of the eleven were the same sheet.** «السور», «الجزء» and
///     «الانتقال» all end at `showJumpSheet`, which has been one sheet with
///     three tabs — surah, juz, page — since the owner asked for it («خلي زر
///     الانتقال يديني خيارات إلى سورة أو صفحة أو جزء مباشرة»).
///  3. It spent about a quarter of a phone screen, permanently, on a tab
///     whose entire job is to show the Qur'an.
///
/// So the bar keeps the four actions a reader uses *while reading*, and
/// everything that is a **setting** moves here, where it can be laid out with
/// its state visible and its groups named.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../data/text_layout_provider.dart';
import '../mushaf_theme_picker.dart';

Future<void> showQuranDisplaySheet(
  BuildContext context, {
  required bool textMode,
  required bool isRaster,
  required bool autoScroll,
  required bool pageFillScreen,
  required double fontScale,
  required void Function(double delta) onFontScale,
  required VoidCallback onToggleAutoScroll,
  required VoidCallback onTogglePageFill,
  required VoidCallback onPickEdition,
  required VoidCallback onEnterImageView,
  required VoidCallback onLeaveImageView,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _QuranDisplaySheet(
      textMode: textMode,
      isRaster: isRaster,
      autoScroll: autoScroll,
      pageFillScreen: pageFillScreen,
      fontScale: fontScale,
      onFontScale: onFontScale,
      onToggleAutoScroll: onToggleAutoScroll,
      onTogglePageFill: onTogglePageFill,
      onPickEdition: onPickEdition,
      onEnterImageView: onEnterImageView,
      onLeaveImageView: onLeaveImageView,
    ),
  );
}

class _QuranDisplaySheet extends ConsumerStatefulWidget {
  final bool textMode;
  final bool isRaster;
  final bool autoScroll;
  final bool pageFillScreen;
  final double fontScale;
  final void Function(double delta) onFontScale;
  final VoidCallback onToggleAutoScroll;
  final VoidCallback onTogglePageFill;
  final VoidCallback onPickEdition;
  final VoidCallback onEnterImageView;
  final VoidCallback onLeaveImageView;

  const _QuranDisplaySheet({
    required this.textMode,
    required this.isRaster,
    required this.autoScroll,
    required this.pageFillScreen,
    required this.fontScale,
    required this.onFontScale,
    required this.onToggleAutoScroll,
    required this.onTogglePageFill,
    required this.onPickEdition,
    required this.onEnterImageView,
    required this.onLeaveImageView,
  });

  @override
  ConsumerState<_QuranDisplaySheet> createState() => _SheetState();
}

class _SheetState extends ConsumerState<_QuranDisplaySheet> {
  late double _scale = widget.fontScale;
  late bool _fill = widget.pageFillScreen;
  late bool _auto = widget.autoScroll;

  /// The reflowable text mushaf is the only thing the layout, the font size
  /// and the page colour change. A scanned printing draws none of them, which
  /// is why those rows are hidden rather than shown doing nothing.
  bool get _textOnly => widget.textMode && !widget.isRaster;

  void _bumpFont(double delta) {
    final next = (_scale + delta).clamp(0.75, 1.8);
    if (next == _scale) return;
    setState(() => _scale = next);
    widget.onFontScale(delta);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'quran.display_title'.tr(),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (_textOnly) ...[
              _Group(label: 'quran.display_layout'.tr()),
              _LayoutChoice(
                value: ref.watch(quranTextLayoutProvider),
                onSelect: (v) =>
                    ref.read(quranTextLayoutProvider.notifier).set(v),
              ),
              _Group(label: 'quran.display_font'.tr()),
              _FontRow(
                scale: _scale,
                onSmaller: () => _bumpFont(-0.1),
                onLarger: () => _bumpFont(0.1),
              ),
              _Group(label: 'quran.display_page'.tr()),
              _Tile(
                icon: Icons.palette_outlined,
                title: 'mushaf_theme.title'.tr(),
                onTap: () => MushafThemePicker.show(context),
              ),
            ],
            _Group(label: 'quran.display_reading'.tr()),
            _SwitchTile(
              icon: _fill
                  ? Icons.fullscreen_exit_rounded
                  : Icons.fullscreen_rounded,
              title: 'quran.page_fit_full'.tr(),
              value: _fill,
              onChanged: (_) {
                setState(() => _fill = !_fill);
                widget.onTogglePageFill();
              },
            ),
            if (_textOnly)
              _SwitchTile(
                icon: Icons.swipe_vertical_rounded,
                title: 'quran.auto_scroll'.tr(),
                value: _auto,
                onChanged: (_) {
                  setState(() => _auto = !_auto);
                  widget.onToggleAutoScroll();
                },
              ),
            _Group(label: 'quran.display_edition'.tr()),
            _Tile(
              icon: Icons.auto_stories_rounded,
              title: 'quran.editions'.tr(),
              onTap: () {
                Navigator.of(context).pop();
                widget.onPickEdition();
              },
            ),
            _Tile(
              icon: _textOnly ? Icons.image_rounded : Icons.notes_rounded,
              title: _textOnly
                  ? 'quran.mushaf_mode'.tr()
                  : 'quran.text_mode'.tr(),
              onTap: () {
                Navigator.of(context).pop();
                if (_textOnly) {
                  widget.onEnterImageView();
                } else {
                  widget.onLeaveImageView();
                }
              },
            ),
            const SizedBox(height: 4),
            Text(
              'quran.display_hint'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final String label;
  const _Group({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

/// The three layouts as three cards, with the one in use filled gold.
///
/// It replaced a single button that CYCLED through them and was labelled with
/// the layout it would give you next — which meant the control never told you
/// where you were, only where you would land.
class _LayoutChoice extends StatelessWidget {
  final QuranTextLayout value;
  final void Function(QuranTextLayout) onSelect;
  const _LayoutChoice({required this.value, required this.onSelect});

  static const _items = <(QuranTextLayout, IconData, String)>[
    (QuranTextLayout.page, Icons.article_rounded, 'quran.layout_page'),
    (QuranTextLayout.cards, Icons.view_agenda_rounded, 'quran.layout_cards'),
    (
      QuranTextLayout.reading,
      Icons.chrome_reader_mode_rounded,
      'quran.layout_reading',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (final (layout, icon, key) in _items)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onSelect(layout),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: layout == value
                        ? AppColors.gold.withValues(alpha: 0.16)
                        : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    border: Border.all(
                      color: layout == value
                          ? AppColors.gold
                          : Colors.transparent,
                      width: 1.4,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        icon,
                        size: 22,
                        color: layout == value
                            ? AppColors.gold
                            : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        key.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: layout == value
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: layout == value
                              ? AppColors.gold
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// − / + with the size actually shown, as a percentage and as live sample
/// text. The old pair of buttons changed something invisible: there was no
/// way to know you were at the 1.8 ceiling except that pressing «+» stopped
/// doing anything.
class _FontRow extends StatelessWidget {
  final double scale;
  final VoidCallback onSmaller;
  final VoidCallback onLarger;
  const _FontRow({
    required this.scale,
    required this.onSmaller,
    required this.onLarger,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: scale > 0.75 ? onSmaller : null,
            icon: const Icon(Icons.text_decrease_rounded),
            tooltip: 'quran.font_smaller'.tr(),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'بِسْمِ ٱللَّهِ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15 * scale),
                ),
                const SizedBox(height: 2),
                Text(
                  '${(scale * 100).round()}%',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: scale < 1.8 ? onLarger : null,
            icon: const Icon(Icons.text_increase_rounded),
            tooltip: 'quran.font_larger'.tr(),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _Tile({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
    leading: Icon(icon, color: AppColors.gold),
    title: Text(title),
    // `chevron_right`, not `chevron_left`: the left one auto-mirrors in
    // RTL and ten of them pointed the wrong way once (trap #7).
    trailing: const Icon(Icons.chevron_right, size: 20),
    onTap: onTap,
  );
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => SwitchListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
    secondary: Icon(icon, color: AppColors.gold),
    title: Text(title),
    value: value,
    onChanged: onChanged,
  );
}
