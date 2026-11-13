import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/rafeeq_app.dart' show sharedPrefsProvider;

/// How many seconds the quarter / hizb plate stays at the side of a mushaf
/// page that carries «۞»; 0 = never shown. Owner, 2026-11-13: «حط خيارات في
/// كرت العرض ... إظهار أو إخفاء ومدة الإظهار بالثواني». Default 3 s, the
/// time the owner first asked for.
const _kKey = 'quran_rub_plate_s_v1';
const rubPlateChoices = [0, 2, 3, 5, 8];

class RubPlateSecondsController extends StateNotifier<int> {
  RubPlateSecondsController(this._prefs) : super(_read(_prefs));

  final SharedPreferences _prefs;

  static int _read(SharedPreferences p) {
    final v = p.getInt(_kKey);
    return rubPlateChoices.contains(v) ? v! : 3;
  }

  Future<void> set(int seconds) async {
    if (seconds == state || !rubPlateChoices.contains(seconds)) return;
    state = seconds;
    await _prefs.setInt(_kKey, seconds);
  }
}

final rubPlateSecondsProvider =
    StateNotifierProvider<RubPlateSecondsController, int>(
      (ref) => RubPlateSecondsController(ref.watch(sharedPrefsProvider)),
    );
