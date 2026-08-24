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
      try {
        state = KhatmaPlan.fromJson(data);
      } catch (_) {
        // Corrupt prefs — start fresh
        state = KhatmaPlan.defaultPlan();
      }
    }
  }

  Future<void> save(KhatmaPlan plan) async {
    state = plan;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_khatma', plan.toJson());
  }

  /// Updates the current reading position (used when user navigates into reading).
  Future<void> updateProgress(int newPage) async {
    final plan = state.copyWith(currentPage: newPage.clamp(1, 604));
    await save(plan);
  }

  /// Called when user taps «أتممت القراءة» — advances completed days and moves
  /// currentPage to the start of tomorrow's wird.
  Future<void> markDayComplete() async {
    final newCompletedDays = state.completedDays + 1;
    final nextStartPage = (state.startPage + newCompletedDays * state.dailyPages).clamp(1, 604);
    final plan = state.copyWith(
      completedDays: newCompletedDays,
      currentPage: nextStartPage,
      currentJuz: ((nextStartPage - 1) ~/ 20) + 1,
    );
    await save(plan);
  }

  /// Creates and saves a brand-new khatma plan, replacing any existing one.
  Future<void> startNewKhatma(KhatmaPlan plan) async {
    await save(plan);
  }

  /// Resets/deletes the current khatma.
  Future<void> resetKhatma() async {
    final fresh = KhatmaPlan.defaultPlan();
    await save(fresh);
  }
}

final khatmaProvider = StateNotifierProvider<KhatmaNotifier, KhatmaPlan>(
  (ref) => KhatmaNotifier(),
);
