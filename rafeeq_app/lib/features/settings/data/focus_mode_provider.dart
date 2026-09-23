/// «وضع التركيز» — the whole app collapses to ONE screen.
///
/// The owner asked for a mode where the reader *literally cannot* reach the
/// rest of the app: «تاب القرآن بس هو اللي يشتغل وباقي التطبيق حرفيًا لا
/// يستطيع المستخدم الدخول عليه عشان يكون بلا تشتيت». So this is not a hint or
/// a dimmed bar — `AppShell` removes the bottom navigation outright, pins its
/// index, and swallows the system back gesture.
///
/// And it is not only the Qur'an: «كارت للقرآن فيفتح القرآن ويقفل عليه، وكارت
/// لوضع للأذكار ويقفل عليه، وكارت للمسبحة ويقفل عليها، بس هما دول». Those
/// three, plus «الحفظ والتسميع», which he added on 2026-09-23 — named here
/// so nothing else can be locked onto by accident.
///
/// It is persisted, because a mode you set to stop yourself wandering is
/// worthless if closing the app quietly cancels it.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/shell/tab_request_provider.dart';

/// The screens focus mode may lock onto. Deliberately not "any tab": focus
/// is for the things a reader sits with, and the owner said «بس هما دول» —
/// so this list only grows when he asks for it, as it did for [hifz].
enum FocusTarget {
  quran(AppTab.quran),
  azkar(AppTab.azkar),
  tasbeeh(AppTab.tasbeeh),

  /// «زود في وضع التركيز الحفظ والتسميع» (2026-09-23). Memorizing is the
  /// longest sitting in the app and the one a notification pulls you out of
  /// most easily, so it earns a card of its own.
  ///
  /// Unlike the other three it is not a bottom-nav tab - it is pushed from
  /// «المزيد» - so it pins an `IndexedStack` slot that only this mode ever
  /// selects. The tasmee panel lives inside a hifz session, so locking onto
  /// this one locks onto both halves the owner named.
  hifz(AppTab.focusHifz);

  const FocusTarget(this.tab);

  /// The `IndexedStack` slot this target pins the shell to. For everything
  /// but [hifz] that is also its `AppTab` bottom-nav index.
  final int tab;

  /// Whether [tab] is a real bottom-nav destination. `AppShell` keeps the
  /// navigation bar's own index on one of those even while focus mode is
  /// showing a slot beyond them.
  bool get isTab => tab < AppTab.navCount;

  /// The i18n key for its name, and for the line under it on the picker.
  String get titleKey => 'focus.target_$name';
  String get bodyKey => 'focus.target_${name}_desc';
}

/// The target currently locked onto, or null when focus mode is off.
class FocusModeNotifier extends StateNotifier<FocusTarget?> {
  FocusModeNotifier() : super(null) {
    _restore();
  }

  /// THE `local_` PREFIX IS LOAD-BEARING.
  ///
  /// `SyncService` pushes EVERY SharedPreferences key that does not start
  /// with `local_`, and its pull writes every key the server returns straight
  /// back into preferences with no comparison of `updated_at` at all. So
  /// focus mode - which is a thing you are in right now, not a preference -
  /// travelled between devices and could switch itself on while the app was
  /// open, behind the notifier that had already read it. That is the owner's
  /// «وضع التركيز بيشتغل لوحده».
  ///
  /// v3 is the same value under a key sync cannot see; v2 is read once and
  /// carried over so nobody loses the mode they were in.
  static const _key = 'local_focus_mode_target_v3';
  static const _v2Key = 'focus_mode_target_v2';
  static const _legacyKey = 'focus_mode_v1';

  static FocusTarget? _parse(String? name) => name == null
      ? null
      : FocusTarget.values.where((t) => t.name == name).firstOrNull;

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = _parse(prefs.getString(_key));
    if (stored != null) {
      state = stored;
      return;
    }
    // Migrate the old, synced key once, then take it out of sync's reach.
    final carried = _parse(prefs.getString(_v2Key));
    if (carried != null) {
      state = carried;
      await prefs.setString(_key, carried.name);
      await prefs.remove(_v2Key);
      return;
    }
    if (prefs.getBool(_legacyKey) ?? false) {
      state = FocusTarget.quran;
      await prefs.setString(_key, FocusTarget.quran.name);
      await prefs.remove(_legacyKey);
    }
  }

  Future<void> enter(FocusTarget target) async {
    state = target;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, target.name);
    await prefs.remove(_v2Key);
    await prefs.remove(_legacyKey);
  }

  Future<void> leave() async {
    state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_v2Key);
    await prefs.remove(_legacyKey);
  }
}

final focusModeProvider =
    StateNotifierProvider<FocusModeNotifier, FocusTarget?>(
        (ref) => FocusModeNotifier());
