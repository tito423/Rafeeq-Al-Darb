import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How the text mushaf sets its verses.
///
/// All three are real reading modes people prefer for different reasons, so
/// this is a choice rather than a redesign:
///
/// * [cards] keeps each verse in its own boxed row, which makes an individual
///   verse easy to isolate, tap and study;
/// * [page] sets the whole run as one justified block with inline rosettes and
///   the surah's illuminated banner, the way a printed mushaf does;
/// * [reading] is [page] with everything decorative taken out — filled
///   markers instead of rosettes, tighter leading, no banner, and margins
///   halved so the line runs to the edge of the screen. Added 2026-09-11 at
///   the owner's request, after he sent screenshots of the app he reads in:
///   «انت تضيف وضع نصي زي بتاع ختمة بالظبط يبقى المجموع نصي ٣».
enum QuranTextLayout {
  cards,
  page,
  reading;

  /// True for the two layouts that set verses as running text; only [cards]
  /// gives a verse a widget of its own.
  bool get isFlowing => this != QuranTextLayout.cards;

  static QuranTextLayout fromName(String? name) =>
      QuranTextLayout.values.firstWhere(
        (v) => v.name == name,
        orElse: () => QuranTextLayout.page,
      );
}

const _kKey = 'quran_text_layout_v1';

class QuranTextLayoutNotifier extends StateNotifier<QuranTextLayout> {
  QuranTextLayoutNotifier() : super(QuranTextLayout.page) {
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    state = QuranTextLayout.fromName(prefs.getString(_kKey));
  }

  Future<void> set(QuranTextLayout layout) async {
    if (layout == state) return;
    state = layout;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, layout.name);
  }

  /// The layout after this one. With three of them the control cycles rather
  /// than flips, in the fixed order page → cards → reading → page.
  QuranTextLayout get next => switch (state) {
        QuranTextLayout.page => QuranTextLayout.cards,
        QuranTextLayout.cards => QuranTextLayout.reading,
        QuranTextLayout.reading => QuranTextLayout.page,
      };

  Future<void> toggle() => set(next);
}

final quranTextLayoutProvider =
    StateNotifierProvider<QuranTextLayoutNotifier, QuranTextLayout>(
        (ref) => QuranTextLayoutNotifier());
