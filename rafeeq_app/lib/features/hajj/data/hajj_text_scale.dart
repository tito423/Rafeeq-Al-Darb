import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Hajj and Umrah screen's text size, as a multiplier on its base sizes,
/// kept between visits. «أدوات التحكم في الخط تصغير وتكبير» (2026-09-19).
class HajjTextScale extends StateNotifier<double> {
  HajjTextScale() : super(1) {
    SharedPreferences.getInstance().then((p) {
      final v = p.getDouble(_key);
      if (v != null && mounted) state = v;
    });
  }

  static const _key = 'hajj.text_scale_v1';
  static const min = 0.8, max = 1.8;

  Future<void> step(int dir) async {
    final next =
        double.parse((state + dir * 0.1).clamp(min, max).toStringAsFixed(1));
    if (next == state) return;
    state = next;
    final p = await SharedPreferences.getInstance();
    await p.setDouble(_key, next);
  }
}

final hajjTextScaleProvider =
    StateNotifierProvider<HajjTextScale, double>((ref) => HajjTextScale());
