import 'dart:math' as math;

import 'package:flutter/material.dart' show TimeOfDay;

/// How a khatma's daily portion is worked out.
///
/// P3‑43 #9: [dailyQuarters] is new — the owner's real reference
/// screenshots (`design_refs/khatma_app_ref/`) show one unified daily-
/// amount unit that starts fine-grained (ربع/ربعان/٣ أرباع/حزب/٥-٧ أرباع
/// — quarters of a hizb) before switching to whole-juz counts past one
/// juz, not two separate concepts. Kept as its own enum value rather
/// than reinterpreting [dailyJuz]'s existing `dailyAmount` unit, so an
/// already-created khatma's "N juz/day" pacing can never be silently
/// reread as "N quarters/day" (4× slower) by this change.
enum KhatmaMode { targetDate, dailyPages, dailyJuz, dailyQuarters }

/// One finished wird, in the khatma's own page count (`pagesRead` before
/// and after it), plus what the khatma's streak state was just before it —
/// so going back to it restores exactly what was there, not a guess.
///
/// «لما اضغط الاوراد السابقة يعرض الاوراد السابقة كلها وانا اختار اي واحد
/// ارجعله»: that needs the real boundaries of every wird already read, and
/// the only honest place for them is a record written at the moment the
/// wird was finished. Khatmas started before this existed have no records;
/// their early wirds are rebuilt from the plan's own rule (see
/// [Khatma.previousWirds]) and carry `at == null`, which the list shows as
/// "no date" rather than inventing one.
class WirdRecord {
  final int from;
  final int to;
  final DateTime? at;
  final DateTime? lastReadBefore;
  final int? streakBefore;

  const WirdRecord({
    required this.from,
    required this.to,
    this.at,
    this.lastReadBefore,
    this.streakBefore,
  });

  Map<String, dynamic> toJson() => {
    'from': from,
    'to': to,
    'at': at?.toIso8601String(),
    'lastReadBefore': lastReadBefore?.toIso8601String(),
    'streakBefore': streakBefore,
  };

  static WirdRecord fromJson(Map<String, dynamic> j) => WirdRecord(
    from: j['from'] as int,
    to: j['to'] as int,
    at: j['at'] != null ? DateTime.parse(j['at'] as String) : null,
    lastReadBefore: j['lastReadBefore'] != null
        ? DateTime.parse(j['lastReadBefore'] as String)
        : null,
    streakBefore: j['streakBefore'] as int?,
  );
}

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

  /// The mushaf page this khatma starts from — 1 for "بداية المصحف", or a
  /// juz's or surah's own start page. All the page-count math below is
  /// relative to this start, not to the mushaf's own page 1, so a khatma
  /// started mid-mushaf still reports honest progress/completion.
  final int startPage;

  /// How many of this khatma's own pages (from [startPage], not from page 1)
  /// have been marked read so far.
  final int pagesRead;

  /// How many «أتممت القراءة» taps have completed a portion — the
  /// reference app's "الأوراد السابقة" count (P3‑6).
  final int portionsRead;

  /// Date-only (midnight) of the last wird finished, for the streak.
  final DateTime? lastReadDate;

  final int streak;
  final DateTime? completedAt;
  final TimeOfDay? reminderTime;

  /// Every wird finished since records began, oldest first.
  final List<WirdRecord> wirds;

  const Khatma({
    required this.id,
    required this.startDate,
    required this.mode,
    this.targetDate,
    this.dailyAmount,
    this.startPage = 1,
    this.pagesRead = 0,
    this.portionsRead = 0,
    this.lastReadDate,
    this.streak = 0,
    this.completedAt,
    this.reminderTime,
    this.wirds = const [],
  });

  static const totalPages = 604;

  /// How many pages this khatma's own plan actually covers — `totalPages`
  /// when [startPage] is 1 (the common case), less when it starts mid-mushaf.
  int get totalPagesInPlan => totalPages - startPage + 1;

  bool get isCompleted => completedAt != null;

  /// The page to open the mushaf on — the next unread page relative to
  /// [startPage], clamped so a completed khatma still points somewhere real.
  int get currentPage => pageAt(pagesRead);

  /// The mushaf page a khatma-relative page count [read] lands on.
  int pageAt(int read) => (startPage + read).clamp(startPage, totalPages);

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool get readToday {
    final last = lastReadDate;
    return last != null && _sameDay(last, DateTime.now());
  }

  /// Today's due amount in pages. For [KhatmaMode.targetDate] this is
  /// recomputed from whatever is actually left and however many days
  /// actually remain — so falling behind raises tomorrow's due amount
  /// instead of silently missing the target.
  int duePages(Map<int, int> juzStartPages, [List<int>? rubElHizbPages]) =>
      _dueAt(pagesRead, juzStartPages, rubElHizbPages);

  /// The size of the wird that starts at khatma-relative page count [read].
  /// Every list of wirds — previous, current, upcoming — is stepped with
  /// this one rule, so the three can never disagree about a boundary.
  int _dueAt(int read, Map<int, int> juzStartPages, List<int>? rubPages) {
    final remaining = totalPagesInPlan - read;
    if (remaining <= 0) return 0;
    final page = pageAt(read);
    switch (mode) {
      case KhatmaMode.dailyPages:
        return math.min(math.max(1, dailyAmount ?? 1), remaining);
      case KhatmaMode.dailyJuz:
        return math.min(
          _pagesForJuz(page, dailyAmount ?? 1, juzStartPages),
          remaining,
        );
      case KhatmaMode.dailyQuarters:
        if (rubPages == null || rubPages.isEmpty) return remaining;
        return math.min(
          _pagesForQuarters(page, dailyAmount ?? 1, rubPages),
          remaining,
        );
      case KhatmaMode.targetDate:
        final target = targetDate;
        if (target == null) return remaining;
        final today = DateTime.now();
        final days =
            target
                .difference(DateTime(today.year, today.month, today.day))
                .inDays +
            1;
        return math.min((remaining / math.max(1, days)).ceil(), remaining);
    }
  }

  /// Pages spanned by [juzCount] juz starting from [page], using the real
  /// juz boundaries (juz lengths vary, ~20 pages each but not exactly)
  /// rather than a flat multiply.
  int _pagesForJuz(int page, int juzCount, Map<int, int> juzStartPages) {
    final startJuz = _juzForPage(page, juzStartPages);
    final endJuz = (startJuz + juzCount).clamp(1, 31);
    final endPage = endJuz > 30
        ? totalPages + 1
        : (juzStartPages[endJuz] ?? totalPages + 1);
    return math.max(1, endPage - page);
  }

  static int _juzForPage(int page, Map<int, int> juzStartPages) {
    var juz = 1;
    for (final entry in juzStartPages.entries) {
      if (entry.value <= page) juz = math.max(juz, entry.key);
    }
    return juz;
  }

  /// Same rule as [_pagesForJuz], one level finer: pages spanned by
  /// [quarterCount] real quarter-hizb divisions starting from [page].
  /// [rubPages] is `MushafData.rubElHizbPages` — index 0 is رُبع 1's own
  /// start page.
  int _pagesForQuarters(int page, int quarterCount, List<int> rubPages) {
    final startRub = _rubForPage(page, rubPages);
    final endRub = (startRub + quarterCount).clamp(1, rubPages.length + 1);
    final endPage = endRub > rubPages.length
        ? totalPages + 1
        : rubPages[endRub - 1];
    return math.max(1, endPage - page);
  }

  static int _rubForPage(int page, List<int> rubPages) {
    var rub = 1;
    for (var i = 0; i < rubPages.length; i++) {
      if (rubPages[i] <= page) rub = i + 1;
    }
    return rub;
  }

  /// Days left until [targetDate] (inclusive of today), or null when this
  /// khatma has no fixed target date.
  int? get daysLeft {
    final target = targetDate;
    if (target == null) return null;
    final today = DateTime.now();
    final d = target
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
    return math.max(0, d);
  }

  double get progress => (pagesRead / totalPagesInPlan).clamp(0, 1);

  /// Today's wird and every one after it, to the end of the plan. The
  /// first entry is the wird the card shows as current.
  List<WirdRecord> upcomingWirds(
    Map<int, int> juzStartPages, [
    List<int>? rubElHizbPages,
  ]) {
    final out = <WirdRecord>[];
    var read = pagesRead;
    while (read < totalPagesInPlan) {
      final due = _dueAt(read, juzStartPages, rubElHizbPages);
      if (due <= 0) break;
      out.add(WirdRecord(from: read, to: read + due));
      read += due;
    }
    return out;
  }

  /// "الأوراد القادمة" (P3‑6) — how many portions remain, today's included.
  int portionsRemaining(
    Map<int, int> juzStartPages, [
    List<int>? rubElHizbPages,
  ]) => upcomingWirds(juzStartPages, rubElHizbPages).length;

  /// Every wird already read, oldest first.
  ///
  /// Recorded wirds are returned as they were written. Anything read before
  /// records began is rebuilt by stepping the plan's own rule from the
  /// start — exact for the page, juz and quarter plans, which is every plan
  /// the create sheet can make. A target-date plan's portion size moved
  /// with the calendar and was never stored, so its unrecorded stretch is
  /// one honest block rather than a split nobody can vouch for.
  List<WirdRecord> previousWirds(
    Map<int, int> juzStartPages, [
    List<int>? rubElHizbPages,
  ]) {
    final recordedFrom = wirds.isEmpty ? pagesRead : wirds.first.from;
    final rebuilt = <WirdRecord>[];
    if (recordedFrom > 0) {
      if (mode == KhatmaMode.targetDate) {
        rebuilt.add(WirdRecord(from: 0, to: recordedFrom));
      } else {
        var read = 0;
        while (read < recordedFrom) {
          final due = _dueAt(read, juzStartPages, rubElHizbPages);
          if (due <= 0) break;
          final to = math.min(read + due, recordedFrom);
          rebuilt.add(WirdRecord(from: read, to: to));
          read = to;
        }
      }
    }
    return [...rebuilt, ...wirds];
  }

  /// This khatma with every wird from [target] onwards un-read, so
  /// [target] is the current wird again. The streak and last-read date go
  /// back to what they were just before [target] was finished when that
  /// was recorded; a rebuilt wird has no such record and leaves them be.
  Khatma rewoundTo(WirdRecord target, int index) {
    final hasRecord = target.at != null;
    return Khatma(
      id: id,
      startDate: startDate,
      mode: mode,
      targetDate: targetDate,
      dailyAmount: dailyAmount,
      startPage: startPage,
      pagesRead: target.from,
      portionsRead: index,
      lastReadDate: hasRecord ? target.lastReadBefore : lastReadDate,
      streak: hasRecord ? (target.streakBefore ?? streak) : streak,
      completedAt: null,
      reminderTime: reminderTime,
      wirds: [
        for (final w in wirds)
          if (w.to <= target.from) w,
      ],
    );
  }

  Khatma copyWith({
    int? pagesRead,
    int? portionsRead,
    DateTime? lastReadDate,
    int? streak,
    DateTime? completedAt,
    List<WirdRecord>? wirds,
    Object? reminderTime = _sentinel,
  }) => Khatma(
    id: id,
    startDate: startDate,
    mode: mode,
    targetDate: targetDate,
    dailyAmount: dailyAmount,
    startPage: startPage,
    pagesRead: pagesRead ?? this.pagesRead,
    portionsRead: portionsRead ?? this.portionsRead,
    lastReadDate: lastReadDate ?? this.lastReadDate,
    streak: streak ?? this.streak,
    completedAt: completedAt ?? this.completedAt,
    wirds: wirds ?? this.wirds,
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
    'startPage': startPage,
    'pagesRead': pagesRead,
    'portionsRead': portionsRead,
    'lastReadDate': lastReadDate?.toIso8601String(),
    'streak': streak,
    'completedAt': completedAt?.toIso8601String(),
    'reminderHour': reminderTime?.hour,
    'reminderMinute': reminderTime?.minute,
    'wirds': [for (final w in wirds) w.toJson()],
  };

  static Khatma fromJson(Map<String, dynamic> j) => Khatma(
    id: j['id'] as String,
    startDate: DateTime.parse(j['startDate'] as String),
    mode: KhatmaMode.values.firstWhere((m) => m.name == j['mode']),
    targetDate: j['targetDate'] != null
        ? DateTime.parse(j['targetDate'] as String)
        : null,
    dailyAmount: j['dailyAmount'] as int?,
    // P3‑6: startPage/portionsRead are new fields — default to 1/0 for
    // every khatma saved before this change, which is exactly what they
    // already behaved as (start of mushaf, no portion count tracked).
    startPage: j['startPage'] as int? ?? 1,
    pagesRead: j['pagesRead'] as int? ?? 0,
    portionsRead: j['portionsRead'] as int? ?? 0,
    lastReadDate: j['lastReadDate'] != null
        ? DateTime.parse(j['lastReadDate'] as String)
        : null,
    streak: j['streak'] as int? ?? 0,
    completedAt: j['completedAt'] != null
        ? DateTime.parse(j['completedAt'] as String)
        : null,
    reminderTime: j['reminderHour'] != null
        ? TimeOfDay(
            hour: j['reminderHour'] as int,
            minute: j['reminderMinute'] as int,
          )
        : null,
    wirds: [
      for (final w in (j['wirds'] as List<dynamic>? ?? const []))
        WirdRecord.fromJson(w as Map<String, dynamic>),
    ],
  );
}

const _sentinel = Object();
