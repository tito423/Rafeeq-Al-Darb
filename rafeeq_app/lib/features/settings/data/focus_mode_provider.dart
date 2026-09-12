/// «وضع التركيز» — the whole app collapses to ONE screen.
///
/// The owner asked for a mode where the reader *literally cannot* reach the
/// rest of the app: «تاب القرآن بس هو اللي يشتغل وباقي التطبيق حرفيًا لا
/// يستطيع المستخدم الدخول عليه عشان يكون بلا تشتيت». So this is not a hint or
/// a dimmed bar — `AppShell` removes the bottom navigation outright, pins its
/// index, and swallows the system back gesture.
///
/// And it is not only the Qur'an: «كارت للقرآن فيفتح القرآن ويقفل عليه، وكارت
/// لوضع للأذكار ويقفل عليه، وكارت للمسبحة ويقفل عليها، بس هما دول». Three
/// destinations, named here so nothing else can be locked onto by accident.
///
/// It is persisted, because a mode you set to stop yourself wandering is
/// worthless if closing the app quietly cancels it.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/shell/tab_request_provider.dart';

/// The three screens focus mode may lock onto. Deliberately not "any tab":
/// focus is for the three things a reader sits with, and the owner said «بس
/// هما دول».
enum FocusTarget {
  quran(AppTab.quran),
  azkar(AppTab.azkar),
  tasbeeh(AppTab.tasbeeh);

  const FocusTarget(this.tab);

  /// The `AppTab` index this target pins the shell to.
  final int tab;

  /// The i18n key for its name, and for the line under it on the picker.
  String get titleKey => 'focus.target_$name';
  String get bodyKey => 'focus.target_${name}_desc';
}

/// The target currently locked onto, or null when focus mode is off.
class FocusModeNotifier extends StateNotifier<FocusTarget?> {
  FocusModeNotifier() : super(null) {
    _restore();
  }

  /// v2: v1 stored a bool, from when the Qur'an was the only destination. A
  /// stored `true` becomes [FocusTarget.quran], which is what it meant.
  static const _key = 'focus_mode_target_v2';
  static const _legacyKey = 'focus_mode_v1';

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored != null) {
      state = FocusTarget.values
          .where((t) => t.name == stored)
          .firstOrNull;
      return;
    }
    if (prefs.getBool(_legacyKey) ?? false) state = FocusTarget.quran;
  }

  Future<void> enter(FocusTarget target) async {
    state = target;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, target.name);
    await prefs.remove(_legacyKey);
  }

  Future<void> leave() async {
    state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_legacyKey);
  }
}

final focusModeProvider =
    StateNotifierProvider<FocusModeNotifier, FocusTarget?>(
        (ref) => FocusModeNotifier());
