import 'dart:convert';

/// Determines how the daily reading quota is expressed.
enum DailyQtyType {
  pages,   // raw pages
  hizb,    // 1 hizb = 4 pages
  quarter, // 1 quarter-hizb = 2 pages
  half,    // 1 half-juz = 10 pages
  juz,     // 1 juz = 20 pages
}

/// Where the user starts their khatma.
enum KhatmaStartType { beginning, juz, surah, page }

class KhatmaPlan {
  final String id;
  final String name;

  // ── Configuration ──────────────────────────────────────────────────────────
  final int targetDays;
  final DailyQtyType dailyQtyType;
  final int dailyQtyValue; // quantity in the selected unit

  // ── Starting point ─────────────────────────────────────────────────────────
  final KhatmaStartType startType;
  final int startPage; // resolved global page 1–604

  // ── Progress ───────────────────────────────────────────────────────────────
  final int currentPage; // current global page 1–604 (reading position)
  final int currentJuz;
  final DateTime startDate;
  final int completedDays; // how many "أتممت القراءة" presses

  KhatmaPlan({
    required this.id,
    required this.name,
    required this.targetDays,
    required this.dailyQtyType,
    required this.dailyQtyValue,
    required this.startType,
    required this.startPage,
    required this.currentPage,
    required this.currentJuz,
    required this.startDate,
    required this.completedDays,
  });

  factory KhatmaPlan.defaultPlan() => KhatmaPlan(
        id: 'default',
        name: 'ختمة شهرية',
        targetDays: 30,
        dailyQtyType: DailyQtyType.pages,
        dailyQtyValue: 20,
        startType: KhatmaStartType.beginning,
        startPage: 1,
        currentPage: 1,
        currentJuz: 1,
        startDate: DateTime.now(),
        completedDays: 0,
      );

  // ── Computed ───────────────────────────────────────────────────────────────

  /// Daily reading in pages (derived from qty type & value).
  int get dailyPages {
    switch (dailyQtyType) {
      case DailyQtyType.juz:
        return dailyQtyValue * 20;
      case DailyQtyType.half:
        return dailyQtyValue * 10;
      case DailyQtyType.hizb:
        return dailyQtyValue * 4;
      case DailyQtyType.quarter:
        return dailyQtyValue * 2;
      case DailyQtyType.pages:
        return dailyQtyValue;
    }
  }

  /// Start page of today's wird (from start of khatma + completed days).
  int get todayStartPage {
    final p = startPage + (completedDays * dailyPages);
    return p.clamp(1, 604);
  }

  /// End page of today's wird (inclusive).
  int get todayEndPage {
    final p = todayStartPage + dailyPages - 1;
    return p.clamp(1, 604);
  }

  /// Overall progress fraction 0.0 → 1.0.
  double get progressFraction {
    final totalPages = 604 - startPage + 1;
    if (totalPages <= 0) return 1.0;
    final done = (currentPage - startPage).clamp(0, totalPages);
    return done / totalPages;
  }

  /// Days remaining (based on target).
  int get daysRemaining => (targetDays - completedDays).clamp(0, targetDays);

  bool get isComplete => currentPage >= 604;

  // ── Serialization ──────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'targetDays': targetDays,
        'dailyQtyType': dailyQtyType.name,
        'dailyQtyValue': dailyQtyValue,
        'startType': startType.name,
        'startPage': startPage,
        'currentPage': currentPage,
        'currentJuz': currentJuz,
        'startDate': startDate.toIso8601String(),
        'completedDays': completedDays,
      };

  factory KhatmaPlan.fromMap(Map<String, dynamic> map) {
    DailyQtyType qty = DailyQtyType.pages;
    for (final v in DailyQtyType.values) {
      if (v.name == map['dailyQtyType']) qty = v;
    }
    KhatmaStartType st = KhatmaStartType.beginning;
    for (final v in KhatmaStartType.values) {
      if (v.name == map['startType']) st = v;
    }
    return KhatmaPlan(
      id: map['id'] ?? 'default',
      name: map['name'] ?? 'ختمتي',
      targetDays: map['targetDays'] ?? 30,
      dailyQtyType: qty,
      dailyQtyValue: map['dailyQtyValue'] ?? 20,
      startType: st,
      startPage: map['startPage'] ?? 1,
      currentPage: map['currentPage'] ?? 1,
      currentJuz: map['currentJuz'] ?? 1,
      startDate: DateTime.tryParse(map['startDate'] ?? '') ?? DateTime.now(),
      completedDays: map['completedDays'] ?? 0,
    );
  }

  String toJson() => json.encode(toMap());

  factory KhatmaPlan.fromJson(String source) =>
      KhatmaPlan.fromMap(json.decode(source));

  KhatmaPlan copyWith({
    String? id,
    String? name,
    int? targetDays,
    DailyQtyType? dailyQtyType,
    int? dailyQtyValue,
    KhatmaStartType? startType,
    int? startPage,
    int? currentPage,
    int? currentJuz,
    DateTime? startDate,
    int? completedDays,
  }) {
    return KhatmaPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      targetDays: targetDays ?? this.targetDays,
      dailyQtyType: dailyQtyType ?? this.dailyQtyType,
      dailyQtyValue: dailyQtyValue ?? this.dailyQtyValue,
      startType: startType ?? this.startType,
      startPage: startPage ?? this.startPage,
      currentPage: currentPage ?? this.currentPage,
      currentJuz: currentJuz ?? this.currentJuz,
      startDate: startDate ?? this.startDate,
      completedDays: completedDays ?? this.completedDays,
    );
  }
}
