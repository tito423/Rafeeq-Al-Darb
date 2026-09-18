/// The mushaf reader's bar: the four things a reader does WHILE reading.
///
/// It used to be eleven captioned tiles in a two-row `Wrap` — layout, smaller,
/// larger, auto-scroll, recitation, themes, full screen, search, surahs, juz,
/// jump, editions, mode — and the owner's verdict on 2026-09-17 was «شكلهم
/// بدائي اوي». Three separate faults, only one of them cosmetic:
///
///  1. **Three of the eleven opened the same sheet.** «السور», «الجزء» and
///     «الانتقال» all call `showJumpSheet`, which has been one sheet with
///     three tabs since «خلي زر الانتقال يديني خيارات إلى سورة أو صفحة أو جزء
///     مباشرة». Two of those buttons were duplicates of the third.
///  2. **Settings and actions were mixed.** «اقرأ الآن» sits beside «حجم
///     الخط»; one is something you do, the other is something you configure,
///     and they were the same size and shape.
///  3. The bar spent roughly a quarter of the phone's height, permanently, on
///     the one tab whose whole purpose is to show the Qur'an.
///
/// So: four actions stay — **انتقال، بحث، استماع، عرض** — and every setting
/// moved into `showQuranDisplaySheet`, where it is grouped and shows its
/// current value instead of only a verb.
///
/// The guided tour's anchors all survive. `quranJump`, `quranSearch` and
/// `quranRecite` stay on their own buttons; `quranLayout`, `quranFont`,
/// `quranTheme`, `quranFullScreen` and `quranEditions` now nest on «عرض»,
/// which is exactly where those settings live, so the tour spotlights the
/// button that opens them rather than pointing at nothing.
library;

import '../../../../../core/widgets/toolbar_action.dart';
import '../../../../search/presentation/screens/search_screen.dart';
import '../../../data/mushaf_data_provider.dart';
import '../../widgets/mushaf_nav_sheets.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../tutorial/data/tutorial_anchors.dart';
import 'quran_display_sheet.dart';
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
  final double fontScale;

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
    required this.fontScale,
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
  /// mushaf. The image mode does not draw the thing any of them changes.
  bool get _textOnly => textMode && !isRaster;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ToolbarStrip(
      compact: compact,
      children: [
        // ── انتقال ── one sheet, three tabs: surah, juz, page. This absorbed
        // the two buttons that used to sit beside it opening the same thing.
        TutorialAnchor(
          id: TourAnchor.quranJump,
          child: ToolbarAction(
            icon: Icons.menu_book_rounded,
            label: 'quran.jump_to'.tr(),
            onPressed: () => showJumpSheet(
              context,
              surahs: canIndexBySurah ? data.surahs : const [],
              surahStartPages: data.surahStartPages,
              juzStartPages: data.juzStartPages,
              current: current,
              totalPages: totalPages,
              onSurahPage: (page) =>
                  onNavigateFromIndex(page, surahStart: true),
              onPage: (page) => onNavigateFromIndex(page),
            ),
          ),
        ),
        // ── بحث ──
        TutorialAnchor(
          id: TourAnchor.quranSearch,
          child: ToolbarAction(
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
        ),
        // ── استماع ── text mushaf only: the Tajweed printing highlighted
        // 4:3 on page 77 a line low, so the image page does not offer it.
        if (_textOnly)
          TutorialAnchor(
            id: TourAnchor.quranRecite,
            child: ToolbarAction(
              icon: reciteActive
                  ? Icons.stop_circle_rounded
                  : Icons.headphones_rounded,
              label: reciteActive
                  ? 'quran.recite_stop'.tr()
                  : 'quran.recite_continuous'.tr(),
              active: reciteActive,
              onPressed: onToggleRecite,
            ),
          ),
        // ── نصي ⇄ ورقي ── «ضيف خيار التنقل من وضع النص لوضع المصحف مباشرة».
        // It lived only inside «العرض», two taps and a scroll away; it is the
        // switch readers flip most, so it sits on the strip itself. The label
        // names where the tap takes you.
        ToolbarAction(
          icon: _textOnly ? Icons.image_rounded : Icons.notes_rounded,
          label: _textOnly ? 'quran.mushaf_mode'.tr() : 'quran.text_mode'.tr(),
          onPressed: _textOnly ? onEnterImageView : onLeaveImageView,
        ),
        // ── عرض ── everything that is a setting rather than an action.
        // The four tour anchors whose buttons moved in here are nested on it,
        // so every step of the Qur'an chapter still has something to point at.
        TutorialAnchor(
          id: TourAnchor.quranLayout,
          child: TutorialAnchor(
            id: TourAnchor.quranFont,
            child: TutorialAnchor(
              id: TourAnchor.quranTheme,
              child: TutorialAnchor(
                id: TourAnchor.quranFullScreen,
                child: TutorialAnchor(
                  id: TourAnchor.quranEditions,
                  child: ToolbarAction(
                    icon: Icons.tune_rounded,
                    label: 'quran.display_title'.tr(),
                    active: pageFillScreen || autoScroll,
                    onPressed: () => showQuranDisplaySheet(
                      context,
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
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
