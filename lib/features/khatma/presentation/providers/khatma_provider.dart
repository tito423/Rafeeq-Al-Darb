import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/khatma_plan.dart';

class KhatmaNotifier extends StateNotifier<KhatmaPlan> {
  KhatmaNotifier() : super(KhatmaPlan.defaultPlan()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('current_khatma');
    if (data != null) {
      state = KhatmaPlan.fromJson(data);
    }
  }

  Future<void> save(KhatmaPlan plan) async {
    state = plan;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_khatma', plan.toJson());
  }
  
  Future<void> updateProgress(int newPage) async {
    // Total pages = 604
    final plan = state.copyWith(
      currentPage: newPage,
    );
    await save(plan);
  }
}

final khatmaProvider = StateNotifierProvider<KhatmaNotifier, KhatmaPlan>(
  (ref) => KhatmaNotifier(),
);
