import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/rafeeq_app.dart' show sharedPrefsProvider;

/// While the continuous recitation plays and the reader turns away from the
/// page being recited, how many seconds until the mushaf goes back to the
/// highlighted ayah by itself; 0 = never.
///
/// «لو التلاوة المستمرة شغالة والتظليل شغال وقلبت الصفحة بالخطأ … اعمل خيار
/// جميل بكدة فيرجع للآية المظللة … بس بعد اد ايه دي بتاعتك» (owner,
/// 2026-10-06). Default 10 s: a page turned by mistake is noticed at once and
/// is back well before the reciter has moved on, while a reader who turned
/// on purpose to glance at a page still gets a few lines' worth of time
/// before being pulled back. Each further turn starts the wait again.
const _kKey = 'quran_recite_return_s_v1';
const reciteReturnChoices = [0, 5, 10, 20];

class ReciteReturnController extends StateNotifier<int> {
  ReciteReturnController(this._prefs) : super(_read(_prefs));

  final SharedPreferences _prefs;

  static int _read(SharedPreferences p) {
    final v = p.getInt(_kKey);
    return reciteReturnChoices.contains(v) ? v! : 10;
  }

  Future<void> set(int seconds) async {
    if (seconds == state || !reciteReturnChoices.contains(seconds)) return;
    state = seconds;
    await _prefs.setInt(_kKey, seconds);
  }
}

final reciteReturnProvider = StateNotifierProvider<ReciteReturnController, int>(
  (ref) => ReciteReturnController(ref.watch(sharedPrefsProvider)),
);
