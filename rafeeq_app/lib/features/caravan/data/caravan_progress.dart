/// The reader's stars on each leg of «قافلة الدرب», kept on the device.
///
/// A leg is open when it is the first or the one before it has been won;
/// a replay keeps the best stars, never lowers them.
library;

import 'package:shared_preferences/shared_preferences.dart';

import 'caravan_legs.dart';

class CaravanProgress {
  CaravanProgress._(this._stars);

  static const _key = 'caravan_stars_v1';

  /// Leg number -> best stars (1..3). A leg not in the map is not won yet.
  final Map<int, int> _stars;

  static Future<CaravanProgress> load() async {
    final p = await SharedPreferences.getInstance();
    final stars = <int, int>{};
    for (final s in p.getStringList(_key) ?? const <String>[]) {
      final parts = s.split(':');
      final leg = int.tryParse(parts.first);
      final n = parts.length == 2 ? int.tryParse(parts[1]) : null;
      if (leg != null && n != null) stars[leg] = n.clamp(1, 3);
    }
    return CaravanProgress._(stars);
  }

  int starsOf(CaravanLeg leg) => _stars[leg.number] ?? 0;

  bool isOpen(CaravanLeg leg) =>
      leg.number == 1 || _stars.containsKey(leg.number - 1);

  int get totalStars => _stars.values.fold(0, (a, b) => a + b);

  /// Records a win; returns whether it beat the previous best.
  Future<bool> record(CaravanLeg leg, int stars) async {
    final before = starsOf(leg);
    if (stars <= before) return false;
    _stars[leg.number] = stars;
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_key, [
      for (final e in _stars.entries) '${e.key}:${e.value}',
    ]);
    return true;
  }
}
