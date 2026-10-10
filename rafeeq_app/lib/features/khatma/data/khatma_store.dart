import 'dart:convert';

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/rafeeq_app.dart';
import '../../../core/config/notification_ids.dart';
import '../../../core/services/khatma_reminder_service.dart';
import 'khatma_model.dart';

export 'khatma_model.dart';

class KhatmaStore extends StateNotifier<List<Khatma>> {
  KhatmaStore(this._prefs) : super(_restore(_prefs));

  final SharedPreferences _prefs;
  static const _key = 'khatma_list_v1';

  static List<Khatma> _restore(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Khatma.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _persist() async {
    await _prefs.setString(
      _key,
      jsonEncode(state.map((k) => k.toJson()).toList()),
    );
  }

  /// No hash collisions and no persisted allocation table. Replacing the
  /// complete set also removes obsolete IDs after a plan is deleted.
  Future<void> rearmReminders() {
    final ids = NotificationIds.khatmaIds(state.map((k) => k.id));
    return KhatmaReminderService.instance.replaceAll([
      for (final k in state)
        if (!k.isCompleted && k.reminderTime != null)
          (ids[k.id]!, k.reminderTime!.hour, k.reminderTime!.minute),
    ]);
  }

  Khatma? _current(String id) {
    for (final k in state) {
      if (k.id == id) return k;
    }
    return null;
  }

  Future<void> _replace(Khatma updated) async {
    state = [
      for (final k in state)
        if (k.id == updated.id) updated else k,
    ];
    await _persist();
  }

  Future<Khatma> create({
    required KhatmaMode mode,
    DateTime? targetDate,
    int? dailyAmount,
    int startPage = 1,
    TimeOfDay? reminderTime,
  }) async {
    final khatma = Khatma(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      startDate: DateTime.now(),
      mode: mode,
      targetDate: targetDate,
      dailyAmount: dailyAmount,
      startPage: startPage,
      reminderTime: reminderTime,
    );
    state = [...state, khatma];
    await _persist();
    if (state.any((k) => k.reminderTime != null)) await rearmReminders();
    return khatma;
  }

  /// «أتممت القراءة»: finishes the current wird and makes the next one
  /// current. Any number of times a day — «ممكن اقرا اكتر من ورد» — the
  /// streak counts days, so a second wird today does not bump it.
  Future<Khatma> completeWird(
    Khatma khatma,
    Map<int, int> juzStartPages, [
    List<int>? rubElHizbPages,
  ]) async {
    final base = _current(khatma.id) ?? khatma;
    final due = base.duePages(juzStartPages, rubElHizbPages);
    if (due <= 0) return base;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final last = base.lastReadDate;
    final gap = last == null
        ? null
        : today.difference(DateTime(last.year, last.month, last.day)).inDays;
    final newPages = (base.pagesRead + due).clamp(0, base.totalPagesInPlan);
    final completed = newPages >= base.totalPagesInPlan;
    final updated = base.copyWith(
      pagesRead: newPages,
      portionsRead: base.portionsRead + 1,
      lastReadDate: now,
      streak: gap == 0 ? base.streak : (gap == 1 ? base.streak + 1 : 1),
      completedAt: completed ? now : null,
      wirds: [
        ...base.wirds,
        WirdRecord(
          from: base.pagesRead,
          to: newPages,
          at: now,
          lastReadBefore: base.lastReadDate,
          streakBefore: base.streak,
        ),
      ],
    );
    await _replace(updated);
    if (completed) {
      await rearmReminders();
    }
    return updated;
  }

  /// Makes the wird at [index] of [Khatma.previousWirds] the current one
  /// again — the «ارجع له» of the previous-wirds list, and «تراجع» after a
  /// tap (which is simply going back to the last wird). Works on the live
  /// state, not on a snapshot a closed screen was holding.
  Future<Khatma?> rewindTo(
    String khatmaId,
    int index,
    Map<int, int> juzStartPages, [
    List<int>? rubElHizbPages,
  ]) async {
    final base = _current(khatmaId);
    if (base == null) return null;
    final previous = base.previousWirds(juzStartPages, rubElHizbPages);
    if (index < 0 || index >= previous.length) return base;
    final updated = base.rewoundTo(previous[index], index);
    await _replace(updated);
    // completeWird() cancels the reminder on completion; undo that too if
    // the wird being undone was the one that completed this khatma.
    if (base.isCompleted && updated.reminderTime != null) {
      await rearmReminders();
    }
    return updated;
  }

  /// «تراجع»: un-reads the last finished wird.
  Future<Khatma?> undoLastWird(
    String khatmaId,
    Map<int, int> juzStartPages, [
    List<int>? rubElHizbPages,
  ]) async {
    final base = _current(khatmaId);
    if (base == null) return null;
    final count = base.previousWirds(juzStartPages, rubElHizbPages).length;
    if (count == 0) return base;
    return rewindTo(khatmaId, count - 1, juzStartPages, rubElHizbPages);
  }

  Future<void> setReminder(Khatma khatma, TimeOfDay? time) async {
    final updated = (_current(khatma.id) ?? khatma).copyWith(
      reminderTime: time,
    );
    await _replace(updated);
    await rearmReminders();
  }

  Future<void> delete(Khatma khatma) async {
    state = state.where((k) => k.id != khatma.id).toList();
    await _persist();
    await rearmReminders();
  }
}

final khatmaStoreProvider = StateNotifierProvider<KhatmaStore, List<Khatma>>((
  ref,
) {
  return KhatmaStore(ref.watch(sharedPrefsProvider));
});

/// Active (unfinished) khatmas, nearest deadline / most overdue first — the
/// Home card shows the top of this list.
final activeKhatmasProvider = Provider<List<Khatma>>((ref) {
  final all = ref.watch(khatmaStoreProvider);
  final active = all.where((k) => !k.isCompleted).toList()
    ..sort((a, b) {
      final ad = a.daysLeft ?? 9999;
      final bd = b.daysLeft ?? 9999;
      return ad.compareTo(bd);
    });
  return active;
});

final completedKhatmasProvider = Provider<List<Khatma>>((ref) {
  return ref.watch(khatmaStoreProvider).where((k) => k.isCompleted).toList()
    ..sort(
      (a, b) => (b.completedAt ?? DateTime(0)).compareTo(
        a.completedAt ?? DateTime(0),
      ),
    );
});
