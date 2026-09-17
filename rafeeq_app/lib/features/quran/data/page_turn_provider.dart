import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/rafeeq_app.dart' show sharedPrefsProvider;

// Re-exported so a caller that only wants the provider does not also have
// to import the widget file for the enum.
export '../presentation/widgets/mushaf/page_turn.dart' show PageTurnStyle;
import '../presentation/widgets/mushaf/page_turn.dart';

/// Which page-turn the mushaf uses, persisted.
///
/// «ممكن تقدر تعمل خيار ان صفحات المصحف تتقلب للصفحة اللي بعدها كاني ماسك
/// مصحف حقيقي واقلب بيه» (2026-09-17) — and the word he used was **خيار**,
/// an option, so it is one: [PageTurnStyle.slide] is still there for a slow
/// device or a reader who does not want the motion.
///
/// Defaults to [PageTurnStyle.book] because that is what he asked for; a
/// reader who turns it off keeps it off.
const _kKey = 'quran_page_turn_v1';

class PageTurnController extends StateNotifier<PageTurnStyle> {
  PageTurnController(this._prefs)
    : super(PageTurnStyle.fromName(_prefs.getString(_kKey)));

  final SharedPreferences _prefs;

  Future<void> set(PageTurnStyle style) async {
    if (style == state) return;
    state = style;
    await _prefs.setString(_kKey, style.name);
  }
}

final pageTurnProvider =
    StateNotifierProvider<PageTurnController, PageTurnStyle>(
      (ref) => PageTurnController(ref.watch(sharedPrefsProvider)),
    );
