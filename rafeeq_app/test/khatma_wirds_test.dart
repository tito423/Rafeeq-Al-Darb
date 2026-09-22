import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/khatma/data/khatma_store.dart';

/// «الأوراد السابقة» lists every wird already read and lets the reader go
/// back to any of them; «تراجع» is going back to the last one. These pin
/// the model those two features stand on.
void main() {
  Khatma pages10({int read = 0, List<WirdRecord> wirds = const []}) => Khatma(
    id: 'k',
    startDate: DateTime(2026, 9, 1),
    mode: KhatmaMode.dailyPages,
    dailyAmount: 10,
    pagesRead: read,
    portionsRead: read ~/ 10,
    wirds: wirds,
  );

  test('a khatma saved before records existed rebuilds its wirds exactly', () {
    // The owner's own khatma: 10 pages a day, two wirds read, no records.
    final k = pages10(read: 20);
    final prev = k.previousWirds(const {});
    expect(prev.map((w) => (w.from, w.to)), [(0, 10), (10, 20)]);
    expect(prev.every((w) => w.at == null), isTrue);
    // 604 pages at 10 a day is 61 wirds; two are behind, 59 ahead — the
    // numbers his screenshot showed.
    expect(k.portionsRemaining(const {}), 59);
  });

  test('rewinding to a wird un-reads it and everything after it', () {
    final at = DateTime(2026, 9, 20, 21);
    final k = pages10(
      read: 30,
      wirds: [
        WirdRecord(
          from: 20,
          to: 30,
          at: at,
          lastReadBefore: DateTime(2026, 9, 19),
          streakBefore: 4,
        ),
      ],
    ).copyWith(streak: 5, lastReadDate: at);
    final prev = k.previousWirds(const {});
    expect(prev.length, 3);

    final back = k.rewoundTo(prev[2], 2);
    expect(back.pagesRead, 20);
    expect(back.portionsRead, 2);
    expect(back.wirds, isEmpty);
    expect(back.streak, 4);
    expect(back.lastReadDate, DateTime(2026, 9, 19));
    expect(back.currentPage, 21);

    final start = k.rewoundTo(prev[0], 0);
    expect(start.pagesRead, 0);
    expect(start.previousWirds(const {}), isEmpty);
  });

  test('upcoming wirds start at the current one and meet the end', () {
    final k = pages10(read: 20);
    final up = k.upcomingWirds(const {});
    expect((up.first.from, up.first.to), (20, 30));
    expect(up.last.to, 604);
    expect(up.last.to - up.last.from, 4);
  });

  // What the owner's phone holds today: saved by 3.55.0, no «wirds» key.
  test('a khatma saved before this release still loads', () {
    final k = Khatma.fromJson({
      'id': '1',
      'startDate': '2026-09-19T08:00:00.000',
      'mode': 'dailyPages',
      'targetDate': null,
      'dailyAmount': 10,
      'startPage': 1,
      'pagesRead': 20,
      'portionsRead': 2,
      'lastReadDate': '2026-09-21T21:00:00.000',
      'streak': 2,
      'completedAt': null,
      'reminderHour': null,
      'reminderMinute': null,
    });
    expect(k.wirds, isEmpty);
    expect(k.previousWirds(const {}).length, 2);
    expect(k.currentPage, 21);
  });

  test('wird records survive a save and a restore', () {
    final k = pages10(
      read: 10,
      wirds: [
        WirdRecord(from: 0, to: 10, at: DateTime(2026, 9, 21), streakBefore: 0),
      ],
    );
    final back = Khatma.fromJson(
      jsonDecode(jsonEncode(k.toJson())) as Map<String, dynamic>,
    );
    expect(back.wirds.single.to, 10);
    expect(back.wirds.single.at, DateTime(2026, 9, 21));
    expect(back.wirds.single.streakBefore, 0);
  });
}
