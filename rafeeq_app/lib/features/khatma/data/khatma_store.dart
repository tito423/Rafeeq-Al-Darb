import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/rafeeq_app.dart';
import '../../../core/services/khatma_reminder_service.dart';

/// How a khatma's daily portion is worked out.
enum KhatmaMode { targetDate, dailyPages, dailyJuz }

/// One khatma (a Quran read-through) — pure local state over the mushaf's
/// existing 604-page layout (P2‑11: "no new content, no network").
class Khatma {
  final String id;
  final DateTime startDate;
  final KhatmaMode mode;

  /// Set only for [KhatmaMode.targetDate].
  final DateTime? targetDate;

  /// Pages/day ([KhatmaMode.dailyPages]) or juz/day ([KhatmaMode.dailyJuz]).
  final int? dailyAmount;

  /// How many of the 604 pages have been marked read so far.
  final int pagesRead;

  /// Date-only (midnight) of the last "read today" tap, for the streak and
  /// the "already read today" state.
  final DateTime? lastReadDate;

  final int streak;
  final DateTime? completedAt;
  final TimeOfDay? reminderTime;

  const Khatma({
    required this.id,
    required this.startDate,
    required this.mode,
    this.targetDate,
    this.dailyAmount,
    this.pagesRead = 0,
    this.lastReadDate,
    this.streak = 0,
    this.completedAt,
    this.reminderTime,
  });

  static const totalPages = 604;

  bool get isCompleted => completedAt != null;

  /// The page to open the mushaf on — the next unread page, clamped so a
  /// completed khatma still points somewhere real.
  int get currentPage => (pagesRead + 1).clamp(1, totalPages);

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool get readToday {
    final last = lastReadDate;
    return last != null && _sameDay(last, DateTime.now());
  }

  /// Today's due amount in pages. For [KhatmaMode.targetDate] this is
  /// recomputed from whatever is actually left and however many days
  /// actually remain — so falling behind raises tomorrow's due amount
  /// instead of silently missing the target (the "catch-up" behaviour the
  /// Khatmah-app research called for).
  int duePages(Map<int, int> juzStartPages) {
    final remaining = totalPages - pagesRead;
    if (remaining <= 0) return 0;
    switch (mode) {
      case KhatmaMode.dailyPages:
        return math.min(dailyAmount ?? 1, remaining);
      case KhatmaMode.dailyJuz:
        return math.min(_pagesForJuz(dailyAmount ?? 1, juzStartPages), remaining);
      case KhatmaMode.targetDate:
        final target = targetDate;
        if (target == null) return remaining;
        final today = DateTime.now();
        final days = target
            .difference(DateTime(today.year, today.month, today.day))
            .inDays +
            1;
        return math.min((remaining / math.max(1, days)).ceil(), remaining);
    }
  }

  /// Pages spanned by [juzCount] juz starting from the current position,
  /// using the real juz boundaries (juz lengths vary, ~20 pages each but not
  /// exactly) rather than a flat multiply.
  int _pagesForJuz(int juzCount, Map<int, int> juzStartPages) {
    final startJuz = _juzForPage(currentPage, juzStartPages);
    final endJuz = (startJuz + juzCount).clamp(1, 31);
    final endPage = endJuz > 30 ? totalPages + 1 : (juzStartPages[endJuz] ?? totalPages + 1);
    final startPage = juzStartPages[startJuz] ?? currentPage;
    return math.max(1, endPage - startPage);
  }

  static int _juzForPage(int page, Map<int, int> juzStartPages) {
    var juz = 1;
    for (final entry in juzStartPages.entries) {
      if (entry.value <= page) juz = math.max(juz, entry.key);
    }
    return juz;
  }

  /// Days left until [targetDate] (inclusive of today), or null when this
  /// khatma has no fixed target date.
  int? get daysLeft {
    final target = targetDate;
    if (target == null) return null;
    final today = DateTime.now();
    final d = target.difference(DateTime(today.year, today.month, today.day)).inDays;
    return math.max(0, d);
  }

  double get progress => (pagesRead / totalPages).clamp(0, 1);

  Khatma copyWith({
    int? pagesRead,
    DateTime? lastReadDate,
    int? streak,
    DateTime? completedAt,
    Object? reminderTime = _sentinel,
  }) =>
      Khatma(
        id: id,
        startDate: startDate,
        mode: mode,
        targetDate: targetDate,
        dailyAmount: dailyAmount,
        pagesRead: pagesRead ?? this.pagesRead,
        lastReadDate: lastReadDate ?? this.lastReadDate,
        streak: streak ?? this.streak,
        completedAt: completedAt ?? this.completedAt,
        reminderTime: identical(reminderTime, _sentinel)
            ? this.reminderTime
            : reminderTime as TimeOfDay?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'startDate': startDate.toIso8601String(),
        'mode': mode.name,
        'targetDate': targetDate?.toIso8601String(),
        'dailyAmount': dailyAmount,
        'pagesRead': pagesRead,
        'lastReadDate': lastReadDate?.toIso8601String(),
        'streak': streak,
        'completedAt': completedAt?.toIso8601String(),
        'reminderHour': reminderTime?.hour,
        'reminderMinute': reminderTime?.minute,
      };

  static Khatma fromJson(Map<String, dynamic> j) => Khatma(
        id: j['id'] as String,
        startDate: DateTime.parse(j['startDate'] as String),
        mode: KhatmaMode.values.firstWhere((m) => m.name == j['mode']),
        targetDate: j['targetDate'] != null
            ? DateTime.parse(j['targetDate'] as String)
            : null,
        dailyAmount: j['dailyAmount'] as int?,
        pagesRead: j['pagesRead'] as int? ?? 0,
        lastReadDate: j['lastReadDate'] != null
            ? DateTime.parse(j['lastReadDate'] as String)
            : null,
        streak: j['streak'] as int? ?? 0,
        completedAt:
            j['completedAt'] != null ? DateTime.parse(j['completedAt'] as String) : null,
        reminderTime: j['reminderHour'] != null
            ? TimeOfDay(hour: j['reminderHour'] as int, minute: j['reminderMinute'] as int)
            : null,
      );
}

const _sentinel = Object();

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
        _key, jsonEncode(state.map((k) => k.toJson()).toList()));
  }

  /// Reminder ids are derived from the khatma's own id so they stay stable
  /// (and distinct from every other notification id this app uses) without
  /// needing a separate id-allocation table.
  int _reminderId(String khatmaId) => 7000 + (khatmaId.hashCode.abs() % 900);

  Future<Khatma> create({
    required KhatmaMode mode,
    DateTime? targetDate,
    int? dailyAmount,
    TimeOfDay? reminderTime,
  }) async {
    final khatma = Khatma(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      startDate: DateTime.now(),
      mode: mode,
      targetDate: targetDate,
      dailyAmount: dailyAmount,
      reminderTime: reminderTime,
    );
    state = [...state, khatma];
    await _persist();
    if (reminderTime != null) await _armReminder(khatma);
    return khatma;
  }

  /// Marks today as read, advancing by the day's due amount. Safe to call
  /// more than once a day (a deliberate choice — a user catching up on
  /// missed days should be able to keep advancing, not be capped at one tap).
  Future<Khatma> readToday(Khatma khatma, Map<int, int> juzStartPages) async {
    final due = khatma.duePages(juzStartPages);
    final today = DateTime.now();
    final wasYesterday = khatma.lastReadDate != null &&
        DateTime(today.year, today.month, today.day)
                .difference(DateTime(khatma.lastReadDate!.year,
                    khatma.lastReadDate!.month, khatma.lastReadDate!.day))
                .inDays ==
            1;
    final alreadyToday = khatma.readToday;
    final newPages = (khatma.pagesRead + due).clamp(0, Khatma.totalPages);
    final completed = newPages >= Khatma.totalPages;
    final updated = khatma.copyWith(
      pagesRead: newPages,
      lastReadDate: today,
      streak: alreadyToday
          ? khatma.streak
          : (wasYesterday ? khatma.streak + 1 : 1),
      completedAt: completed ? DateTime.now() : null,
    );
    state = [for (final k in state) if (k.id == khatma.id) updated else k];
    await _persist();
    if (completed) await KhatmaReminderService.instance.cancel(_reminderId(khatma.id));
    return updated;
  }

  /// Reverts a [readToday] call — backs the "تراجع" undo action on the
  /// snackbar shown right after marking today read, for an accidental tap
  /// (P3‑6). Takes the exact pre-update [previous] snapshot the caller
  /// already has in scope, rather than re-deriving the inverse of
  /// [readToday]'s due-amount/streak math here.
  Future<void> restore(Khatma previous) async {
    state = [for (final k in state) if (k.id == previous.id) previous else k];
    await _persist();
    // readToday() cancels the reminder on completion; undo that too if the
    // tap being undone was the one that completed this khatma.
    if (previous.reminderTime != null && !previous.isCompleted) {
      await _armReminder(previous);
    }
  }

  Future<void> setReminder(Khatma khatma, TimeOfDay? time) async {
    final updated = khatma.copyWith(reminderTime: time);
    state = [for (final k in state) if (k.id == khatma.id) updated else k];
    await _persist();
    if (time != null) {
      await _armReminder(updated);
    } else {
      await KhatmaReminderService.instance.cancel(_reminderId(khatma.id));
    }
  }

  Future<void> _armReminder(Khatma khatma) async {
    final time = khatma.reminderTime;
    if (time == null) return;
    await KhatmaReminderService.instance.schedule(
      _reminderId(khatma.id),
      time.hour,
      time.minute,
    );
  }

  Future<void> delete(Khatma khatma) async {
    state = state.where((k) => k.id != khatma.id).toList();
    await _persist();
    await KhatmaReminderService.instance.cancel(_reminderId(khatma.id));
  }
}

final khatmaStoreProvider =
    StateNotifierProvider<KhatmaStore, List<Khatma>>((ref) {
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
    ..sort((a, b) => (b.completedAt ?? DateTime(0)).compareTo(a.completedAt ?? DateTime(0)));
});
