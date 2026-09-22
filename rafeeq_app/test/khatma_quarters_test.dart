import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/khatma/data/khatma_store.dart';

/// P3‑43 #9: the real quarter-hizb data + `KhatmaMode.dailyQuarters` math,
/// verified directly rather than only by hand through a flaky emulator UI
/// tap sequence (this session's own manual attempts to click through the
/// wizard hit repeated, unrelated tap-coordinate misses) — a permanent
/// regression test is the more reliable, durable check anyway.
void main() {
  late List<int> rubPages;

  setUpAll(() {
    final raw = File(
      'assets/data/mushaf/rub_el_hizb_pages.json',
    ).readAsStringSync();
    rubPages = (jsonDecode(raw) as List<dynamic>).cast<int>();
  });

  test(
    'rub_el_hizb_pages.json has exactly 240 non-decreasing entries starting at page 1',
    () {
      expect(rubPages.length, 240);
      expect(rubPages.first, 1);
      for (var i = 1; i < rubPages.length; i++) {
        expect(rubPages[i], greaterThanOrEqualTo(rubPages[i - 1]));
      }
    },
  );

  test(
    'a fresh khatma due 3 quarters/day matches the real page span of رُبع 1-3',
    () {
      final khatma = Khatma(
        id: 't1',
        startDate: DateTime(2026, 1, 1),
        mode: KhatmaMode.dailyQuarters,
        dailyAmount: 3,
      );
      final due = khatma.duePages(const {}, rubPages);
      // رُبع 4 starts where رُبع 1-3 end, per the real fetched data.
      final expected = rubPages[3] - rubPages[0];
      expect(due, expected);
    },
  );

  test('4 quarters/day (a full hizb) matches the real page span exactly', () {
    final khatma = Khatma(
      id: 't2',
      startDate: DateTime(2026, 1, 1),
      mode: KhatmaMode.dailyQuarters,
      dailyAmount: 4,
    );
    final due = khatma.duePages(const {}, rubPages);
    expect(due, rubPages[4] - rubPages[0]);
  });

  test(
    'dailyQuarters pacing starting mid-mushaf uses the real rub at that page, not page 1\'s',
    () {
      // Start on رُبع 10's own real first page.
      final startPage = rubPages[9];
      final khatma = Khatma(
        id: 't3',
        startDate: DateTime(2026, 1, 1),
        mode: KhatmaMode.dailyQuarters,
        dailyAmount: 2,
        startPage: startPage,
      );
      final due = khatma.duePages(const {}, rubPages);
      expect(due, rubPages[11] - rubPages[9]);
    },
  );

  test(
    'an existing dailyJuz khatma is unaffected by dailyQuarters existing',
    () {
      final khatma = Khatma(
        id: 't4',
        startDate: DateTime(2026, 1, 1),
        mode: KhatmaMode.dailyJuz,
        dailyAmount: 1,
      );
      final juzStartPages = {for (var j = 1; j <= 30; j++) j: (j - 1) * 20 + 1};
      // Same result with or without rubPages passed — dailyJuz never reads it.
      final dueWithout = khatma.duePages(juzStartPages);
      final dueWith = khatma.duePages(juzStartPages, rubPages);
      expect(dueWith, dueWithout);
    },
  );

  test('portionsRemaining counts the real quarter wirds to the end', () {
    final khatma = Khatma(
      id: 't5',
      startDate: DateTime(2026, 1, 1),
      mode: KhatmaMode.dailyQuarters,
      dailyAmount: 1,
    );
    final wirds = khatma.upcomingWirds(const {}, rubPages);
    expect(khatma.portionsRemaining(const {}, rubPages), wirds.length);
    // Contiguous, starting at 0 and ending on the last page of the plan.
    expect(wirds.first.from, 0);
    expect(wirds.last.to, khatma.totalPagesInPlan);
    for (var i = 1; i < wirds.length; i++) {
      expect(wirds[i].from, wirds[i - 1].to);
    }
  });
}
