/// Every action the mushaf reader offers, in one place.
///
/// This was two hundred lines nested eight levels deep inside
/// `quran_screen.dart`'s `build`, between a `PreferredSize` and a
/// `TweenAnimationBuilder` — which is why the three "text mushaf only"
/// conditions on it had drifted into three different shapes, and why nothing
/// could be said about the bar without reading the whole screen.
///
/// It takes what it draws and calls back for what it changes; it holds no
/// state of its own. `ConsumerWidget` rather than plain `StatelessWidget`
/// because two of the actions (the verse layout and the edition mode) read
/// and write providers directly, exactly as they did in the screen.
library;

import '../../../../../core/config/app_config.dart';
import '../../../../../core/widgets/toolbar_action.dart';
import '../../../../search/presentation/screens/search_screen.dart';
import '../../../data/mushaf_data_provider.dart';
import '../../../data/mushaf_edition.dart';
import '../../../data/text_layout_provider.dart';
import '../../widgets/mushaf_nav_sheets.dart';
import '../../widgets/mushaf_theme_picker.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'toolbar_strip.dart';

class MushafToolbar extends ConsumerWidget {
  /// Landscape: icons only, one scrolling row. See [ToolbarStrip].
  final bool compact;

  /// The reader is on the reflowable text mushaf, not a page image.
  final bool textMode;

  /// The open printing is a scan with no text form of its own.
  final bool isRaster;

  /// This printing paginates the Madinah 604-page way, so the app's
  /// surah→page and juz→page tables apply to it.
  final bool canIndexBySurah;

  final bool autoScroll;
  final bool reciteActive;
  final bool pageFillScreen;

  final MushafData data;
  final int current;
  final int totalPages;

  final void Function(double delta) onFontScale;
  final VoidCallback onToggleAutoScroll;
  final VoidCallback onToggleRecite;
  final VoidCallback onTogglePageFill;
  final void Function(int page) onGoToPage;
  final void Function(int page, {bool surahStart}) onNavigateFromIndex;
  final VoidCallback onPickEdition;
  final VoidCallback onEnterImageView;
  final VoidCallback onLeaveImageView;

  const MushafToolbar({
    super.key,
    required this.compact,
    required this.textMode,
    required this.isRaster,
    required this.canIndexBySurah,
    required this.autoScroll,
    required this.reciteActive,
    required this.pageFillScreen,
    required this.data,
    required this.current,
    required this.totalPages,
    required this.onFontScale,
    required this.onToggleAutoScroll,
    required this.onToggleRecite,
    required this.onTogglePageFill,
    required this.onGoToPage,
    required this.onNavigateFromIndex,
    required this.onPickEdition,
    required this.onEnterImageView,
    required this.onLeaveImageView,
  });

  /// True for the actions that only mean anything on the reflowable text
  /// mushaf: the verse layout, the font size, auto-scroll, the continuous
  /// recitation and the page theme. The image mode does not draw the thing
  /// any of them changes.
  bool get _textOnly => textMode && !isRaster;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ToolbarStrip(
      compact: compact,
      children: [
        if (_textOnly) ...[
          // Three verse layouts now, all of them real reading preferences,
          // so this cycles rather than flips — and it is labelled with the
          // one it will GIVE you, not the one you are in.
          ToolbarAction(
            icon: switch (ref.read(quranTextLayoutProvider.notifier).next) {
              QuranTextLayout.page => Icons.article_rounded,
              QuranTextLayout.cards => Icons.view_agenda_rounded,
              QuranTextLayout.reading => Icons.chrome_reader_mode_rounded,
            },
            label: switch (ref.read(quranTextLayoutProvider.notifier).next) {
              QuranTextLayout.page => 'quran.layout_page'.tr(),
              QuranTextLayout.cards => 'quran.layout_cards'.tr(),
              QuranTextLayout.reading => 'quran.layout_reading'.tr(),
            },
            onPressed: () =>
                ref.read(quranTextLayoutProvider.notifier).toggle(),
          ),
          ToolbarAction(
            icon: Icons.text_decrease_rounded,
            label: 'quran.font_smaller'.tr(),
            onPressed: () => onFontScale(-0.1),
          ),
          ToolbarAction(
            icon: Icons.text_increase_rounded,
            label: 'quran.font_larger'.tr(),
            onPressed: () => onFontScale(0.1),
          ),
          ToolbarAction(
            icon: autoScroll
                ? Icons.pause_circle_outline
                : Icons.play_circle_outline,
            label: autoScroll
                ? 'quran.auto_scroll_stop'.tr()
                : 'quran.auto_scroll'.tr(),
            onPressed: onToggleAutoScroll,
          ),
          // Continuous recitation lives in the text mushaf only, in every
          // layout and theme — «شيل التلاوة المستمرة خالص من المصحف المصوّر».
          // The Tajweed printing highlighted 4:3 on page 77 a line low, so
          // the image page does not offer it at all.
          ToolbarAction(
            icon: reciteActive
                ? Icons.stop_circle_rounded
                : Icons.headphones_rounded,
            label: reciteActive
                ? 'quran.recite_stop'.tr()
                : 'quran.recite_continuous'.tr(),
            onPressed: onToggleRecite,
          ),
          // The paper. It lived only in Settings, four taps and a different
          // tab away from the page whose colour it changes — which is why the
          // owner reported the app had no black reading page while shipping
          // five of them. Khatmah puts it behind a gear on the reading screen
          // itself; so do we. Text mushaf only: «شيل ثيمات المصحف النصي من
          // المصحف المصوّر» — it recolours a page the image mode does not draw.
          Builder(
            builder: (tileContext) => ToolbarAction(
              icon: Icons.palette_outlined,
              label: 'mushaf_theme.title'.tr(),
              onPressed: () =>
                  MushafThemePicker.show(context, origin: tileContext),
            ),
          ),
        ],
        // P3‑43 #6: NOT in the text-only block above — full-screen reading is
        // a real, useful mode for the image mushaf too.
        ToolbarAction(
          icon: pageFillScreen
              ? Icons.fullscreen_exit_rounded
              : Icons.fullscreen_rounded,
          label: pageFillScreen
              ? 'quran.page_fit_small'.tr()
              : 'quran.page_fit_full'.tr(),
          onPressed: onTogglePageFill,
        ),
        ToolbarAction(
          icon: Icons.travel_explore_rounded,
          label: 'search.title'.tr(),
          onPressed: () async {
            final page = await Navigator.of(context).push<int>(
              MaterialPageRoute<int>(
                builder: (_) => SearchScreen(repo: data.repo),
              ),
            );
            if (page != null) onGoToPage(page);
          },
        ),
        if (canIndexBySurah)
          ToolbarAction(
            icon: Icons.format_list_bulleted_rounded,
            label: 'quran.surah_list'.tr(),
            onPressed: () => showSurahSheet(
              context,
              surahs: data.surahs,
              startPages: data.surahStartPages,
              onSelect: (page) => onNavigateFromIndex(page, surahStart: true),
            ),
          ),
        if (canIndexBySurah)
          ToolbarAction(
            icon: Icons.layers_rounded,
            label: 'quran.juz'.tr(),
            onPressed: () => showJuzSheet(
              context,
              juzStartPages: data.juzStartPages,
              onSelect: (page) => onNavigateFromIndex(page),
            ),
          ),
        ToolbarAction(
          icon: Icons.numbers_rounded,
          label: 'quran.jump_to'.tr(),
          // «خلي زر الانتقال يديني خيارات إلى سورة أو صفحة أو جزء مباشرة».
          onPressed: () => showJumpSheet(
            context,
            surahs: canIndexBySurah ? data.surahs : const [],
            surahStartPages: data.surahStartPages,
            juzStartPages: data.juzStartPages,
            current: current,
            totalPages: totalPages,
            onSurahPage: (page) => onNavigateFromIndex(page, surahStart: true),
            onPage: (page) => onNavigateFromIndex(page),
          ),
        ),
        ToolbarAction(
          icon: Icons.auto_stories_rounded,
          label: 'quran.editions'.tr(),
          onPressed: onPickEdition,
        ),
        // A raster printing is a finished scan with no reflowable text of its
        // own — but the button is still shown, because hiding it left a reader
        // who had picked one of those printings with no way back to the text
        // reader at all. On a raster edition it switches back to the default
        // text edition as well as the mode.
        ToolbarAction(
          icon: _textOnly ? Icons.image_rounded : Icons.notes_rounded,
          label: _textOnly
              ? 'quran.mushaf_mode'.tr()
              : 'quran.text_mode'.tr(),
          onPressed: () {
            if (isRaster) {
              ref
                  .read(selectedMushafEditionProvider.notifier)
                  .select(AppConfig.defaultMushafEdition);
              onLeaveImageView();
            } else if (textMode) {
              onEnterImageView();
            } else {
              onLeaveImageView();
            }
          },
        ),
      ],
    );
  }
}
