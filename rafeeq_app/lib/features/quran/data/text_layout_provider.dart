import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How the text mushaf sets its verses.
///
/// Both are real reading modes people prefer for different reasons, so this is
/// a choice rather than a redesign: [cards] keeps each verse in its own boxed
/// row, which makes an individual verse easy to isolate, tap and study;
/// [page] sets the whole run as one justified block with inline rosettes, the
/// way a printed mushaf does, which is what someone reading continuously
/// expects to see.
enum QuranTextLayout {
  cards,
  page;

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

  Future<void> toggle() => set(
        state == QuranTextLayout.page
            ? QuranTextLayout.cards
            : QuranTextLayout.page,
      );
}

final quranTextLayoutProvider =
    StateNotifierProvider<QuranTextLayoutNotifier, QuranTextLayout>(
        (ref) => QuranTextLayoutNotifier());
