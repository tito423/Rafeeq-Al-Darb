import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/khatma/data/khatma_model.dart';

/// «ضيف ختمة القران امكانية التعديل عليها في كل امكاناتها» (owner,
/// 2026-11-02): Khatma.edited changes the plan of a khatma already running.
void main() {
  final at = DateTime(2026, 11, 1, 20);
  Khatma base() => Khatma(
        id: 'k',
        startDate: DateTime(2026, 10, 2),
        mode: KhatmaMode.dailyPages,
        dailyAmount: 10,
        pagesRead: 30,
        portionsRead: 3,
        streak: 3,
        wirds: [
          const WirdRecord(from: 0, to: 10),
          WirdRecord(from: 10, to: 20, at: at),
          WirdRecord(from: 20, to: 30, at: at),
        ],
      );

  test('a new amount and unit keep the page reached', () {
    final k = base().edited(
      startPage: 1,
      mode: KhatmaMode.dailyJuz,
      dailyAmount: 1,
      reachedPage: 31,
      reminderTime: const TimeOfDay(hour: 21, minute: 30),
    );
    expect(k.mode, KhatmaMode.dailyJuz);
    expect(k.dailyAmount, 1);
    expect(k.currentPage, 31);
    expect(k.wirds.length, 3);
    expect(k.reminderTime, const TimeOfDay(hour: 21, minute: 30));
    expect(k.streak, 3);
    expect(k.id, 'k');
  });

  test('going back un-reads the wirds past the page reached', () {
    final k = base().edited(
      startPage: 1,
      mode: KhatmaMode.dailyPages,
      dailyAmount: 10,
      reachedPage: 15,
    );
    expect(k.pagesRead, 14);
    expect(k.currentPage, 15);
    // Pages 11-14 stay read, as one undated wird.
    expect([for (final w in k.wirds) w.to], [10, 14]);
    expect(k.wirds.last.at, isNull);
  });

  test('a jump forward is one undated wird, no invented date', () {
    final k = base().edited(
      startPage: 1,
      mode: KhatmaMode.dailyPages,
      dailyAmount: 10,
      reachedPage: 101,
    );
    expect(k.pagesRead, 100);
    expect(k.wirds.last.from, 30);
    expect(k.wirds.last.to, 100);
    expect(k.wirds.last.at, isNull);
  });

  test('moving the start keeps the reader on the same mushaf page', () {
    final k = base().edited(
      startPage: 11,
      mode: KhatmaMode.dailyPages,
      dailyAmount: 10,
      reachedPage: 31,
    );
    expect(k.startPage, 11);
    expect(k.currentPage, 31);
    expect(k.pagesRead, 20);
    // The wird on pages 1-10 is before the new start: no longer this plan's.
    expect([for (final w in k.wirds) '${w.from}-${w.to}'], ['0-10', '10-20']);
  });

  test('reaching the end completes it; going back reopens it', () {
    final done = base().edited(
      startPage: 1,
      mode: KhatmaMode.dailyPages,
      dailyAmount: 10,
      reachedPage: 605,
    );
    expect(done.isCompleted, isTrue);
    final reopened = done.edited(
      startPage: 1,
      mode: KhatmaMode.dailyPages,
      dailyAmount: 10,
      reachedPage: 600,
    );
    expect(reopened.isCompleted, isFalse);
    expect(reopened.currentPage, 600);
  });

  test('the reminder can be removed', () {
    final k = base()
        .copyWith(reminderTime: const TimeOfDay(hour: 5, minute: 0))
        .edited(
          startPage: 1,
          mode: KhatmaMode.dailyPages,
          dailyAmount: 10,
          reachedPage: 31,
        );
    expect(k.reminderTime, isNull);
  });
}
