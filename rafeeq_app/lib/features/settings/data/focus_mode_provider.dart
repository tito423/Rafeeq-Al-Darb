/// «وضع التركيز» — the whole app collapses to the Qur'an tab.
///
/// The owner asked for a mode where the reader *literally cannot* reach the
/// rest of the app: «تاب القرآن بس هو اللي يشتغل وباقي التطبيق حرفيًا لا
/// يستطيع المستخدم الدخول عليه عشان يكون بلا تشتيت». So this is not a hint
/// or a dimmed bar — `AppShell` removes the bottom navigation outright, pins
/// its index to the Qur'an tab, and swallows the system back gesture.
///
/// It is persisted, because a mode you set to stop yourself wandering is
/// worthless if closing the app quietly cancels it.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FocusModeNotifier extends StateNotifier<bool> {
  FocusModeNotifier() : super(false) {
    _restore();
  }

  static const _key = 'focus_mode_v1';

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  Future<void> set(bool on) async {
    state = on;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, on);
  }

  Future<void> toggle() => set(!state);
}

final focusModeProvider =
    StateNotifierProvider<FocusModeNotifier, bool>((ref) => FocusModeNotifier());
