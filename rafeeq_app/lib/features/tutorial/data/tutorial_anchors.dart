/// Where the tour is allowed to point.
///
/// «حط النص اللي بيشرح في دايرة أو مستطيل صغير يشرح كل فيتشر في التطبيق
/// ويشاور عليه بسهم» — a bubble that points needs something to point AT, and
/// a hard-coded rectangle would be a lie the first time a card moved. So the
/// widgets worth explaining register themselves, and the tour asks the live
/// widget tree where they are right now.
///
/// A missing anchor is not an error: the card may be on another tab, or
/// scrolled out of view. The overlay simply shows its bubble without a
/// spotlight rather than pointing at nothing.
library;

import 'package:flutter/widgets.dart';

/// The ids the tour knows how to point at. String constants rather than bare
/// literals so a typo is a compile error on both sides.
abstract final class TourAnchor {
  static const hadithCard = 'hadith_card';
  static const quoteCard = 'quote_card';
  static const prayerCard = 'prayer_card';
  static const khatmaCard = 'khatma_card';
  static const continueReading = 'continue_reading';

  // «يشرح امكانيات التطبيق حتة حتة في كل شاشة». One id per part a stop
  // explains, registered where that part is built.
  static const quranLayout = 'quran_layout';
  static const quranFont = 'quran_font';
  static const quranRecite = 'quran_recite';
  static const quranTheme = 'quran_theme';
  static const quranFullScreen = 'quran_full_screen';
  static const quranSearch = 'quran_search';
  static const quranJump = 'quran_jump';
  static const quranEditions = 'quran_editions';
  static const qiblaCompass = 'qibla_compass';
  static const adhanSettings = 'adhan_settings';
  static const prayerAdjustments = 'prayer_adjustments';
  static const azkarCategory = 'azkar_category';
  static const tasbeehTargets = 'tasbeeh_targets';
  static const tasbeehMathur = 'tasbeeh_mathur';
  static const libraryTabs = 'library_tabs';
  static const moreQuranAudio = 'more_quran_audio';
  static const moreTajweed = 'more_tajweed';
  static const moreDownloads = 'more_downloads';
  static const moreFocus = 'more_focus';
}

final Map<String, GlobalKey> _anchors = <String, GlobalKey>{};

/// Wraps a widget the guided tour can highlight.
///
/// Costs one `GlobalKey` and nothing else: it does not rebuild, does not
/// listen, and does not know the tour exists.
class TutorialAnchor extends StatelessWidget {
  final String id;
  final Widget child;

  const TutorialAnchor({super.key, required this.id, required this.child});

  @override
  Widget build(BuildContext context) {
    final key = _anchors.putIfAbsent(id, GlobalKey.new);
    return KeyedSubtree(key: key, child: child);
  }
}

/// Scrolls [id] into view when it sits inside a scrolling list, so a stop
/// about the fifth card on a screen points at it instead of at the tab's
/// button. Completes at once when the widget is not mounted or not scrollable.
Future<void> revealAnchor(String id) async {
  final context = _anchors[id]?.currentContext;
  if (context == null || !context.mounted) return;
  if (Scrollable.maybeOf(context) == null) return;
  await Scrollable.ensureVisible(
    context,
    alignment: 0.35,
    duration: const Duration(milliseconds: 380),
    curve: Curves.easeInOutCubic,
  );
}

/// The rectangle [id] currently occupies on screen, or null when it is not
/// mounted — a different tab, or scrolled past.
Rect? anchorRect(String id) {
  final context = _anchors[id]?.currentContext;
  if (context == null) return null;
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  final origin = box.localToGlobal(Offset.zero);
  final rect = origin & box.size;
  // A card scrolled mostly off screen is worse to point at than nothing.
  if (rect.height <= 0 || rect.width <= 0) return null;
  return rect;
}
