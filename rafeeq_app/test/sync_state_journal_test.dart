import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/services/sync_service.dart';
import 'package:rafeeq_app/core/services/sync_state_journal.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });
  test('A04 persists an offline edit across journal restart', () async {
    await prefs.setInt('quran_last_page', 541);
    final journal = SyncStateJournal(
      prefs,
      null,
      clock: () => DateTime.fromMillisecondsSinceEpoch(200),
    );
    await journal.record('quran_last_page');
    final reopened = SyncStateJournal(prefs, null);
    expect(reopened.dirty(SyncService.syncedStateKeys), [
      {'key': 'quran_last_page', 'value': '541', 'updated_at': 200},
    ]);
  });
  test('A04 unchanged values do not acquire a newer timestamp', () async {
    await prefs.setInt('quran_last_page', 541);
    var now = 200;
    final journal = SyncStateJournal(
      prefs,
      'one',
      clock: () => DateTime.fromMillisecondsSinceEpoch(now),
    );
    await journal.record('quran_last_page');
    now = 500;
    await journal.record('quran_last_page');
    expect(journal.entries['quran_last_page']!['t'], 200);
  });
  test(
    'A04 clock rollback cannot revert a learned modification time',
    () async {
      await prefs.setInt('quran_last_page', 541);
      final journal = SyncStateJournal(
        prefs,
        'one',
        clock: () => DateTime.fromMillisecondsSinceEpoch(100),
      );
      await journal.received('quran_last_page', '541', 500);
      await prefs.setInt('quran_last_page', 542);
      await journal.record('quran_last_page');
      expect(journal.entries['quran_last_page']!['t'], 501);
      expect(journal.accepts('quran_last_page', '540', 500), isFalse);
    },
  );
  test(
    'A04 a stale upload acknowledgement cannot clear a newer edit',
    () async {
      await prefs.setInt('quran_last_page', 541);
      var now = 200;
      final journal = SyncStateJournal(
        prefs,
        'one',
        clock: () => DateTime.fromMillisecondsSinceEpoch(now),
      );
      await journal.record('quran_last_page');
      final old = journal.dirty(SyncService.syncedStateKeys);
      await prefs.setInt('quran_last_page', 543);
      now++;
      await journal.record('quran_last_page');
      await journal.acknowledge(old);
      expect(journal.entries['quran_last_page']!['d'], isTrue);
      expect(journal.dirty(SyncService.syncedStateKeys).single['value'], '543');
      await journal.acknowledge(journal.dirty(SyncService.syncedStateKeys));
      expect(journal.entries['quran_last_page']!['d'], isFalse);
    },
  );
  test(
    'A04 adopted device notes cannot be inherited by a later account',
    () async {
      await prefs.setString(
        'ayah_notes_v1',
        jsonEncode({'2:255': 'Local ownership regression'}),
      );
      final device = SyncStateJournal(prefs, null);
      await device.record('ayah_notes_v1');
      final one = await device.switchAccount(
        'one',
        SyncService.syncedStateKeys,
        SyncService.syncedCounterKeys,
      );
      expect(prefs.containsKey(device.storageKey), isFalse);
      expect(one.entries['ayah_notes_v1'], isNotNull);
      final two = await one.switchAccount(
        'two',
        SyncService.syncedStateKeys,
        SyncService.syncedCounterKeys,
      );
      expect(two.entries['ayah_notes_v1'], isNull);
      expect(prefs.getString('ayah_notes_v1'), isNull);
    },
  );
  test(
    'A04 account switch and switch back preserve each local state and counter',
    () async {
      await prefs.setInt('quran_last_page', 541);
      await prefs.setInt('tasbeeh_total', 5);
      final device = SyncStateJournal(prefs, null);
      await device.record('quran_last_page');
      final one = await device.switchAccount(
        'one',
        SyncService.syncedStateKeys,
        SyncService.syncedCounterKeys,
      );
      final two = await one.switchAccount(
        'two',
        SyncService.syncedStateKeys,
        SyncService.syncedCounterKeys,
      );
      expect(prefs.getInt('quran_last_page'), isNull);
      expect(prefs.getInt('tasbeeh_total'), isNull);
      await prefs.setInt('quran_last_page', 540);
      await prefs.setInt('tasbeeh_total', 7);
      await two.record('quran_last_page');
      final restored = await two.switchAccount(
        'one',
        SyncService.syncedStateKeys,
        SyncService.syncedCounterKeys,
      );
      expect(restored.entries['quran_last_page']!['v'], '541');
      expect(prefs.getInt('quran_last_page'), 541);
      expect(prefs.getInt('tasbeeh_total'), 5);
      await restored.switchAccount(
        'two',
        SyncService.syncedStateKeys,
        SyncService.syncedCounterKeys,
      );
      expect(prefs.getInt('quran_last_page'), 540);
      expect(prefs.getInt('tasbeeh_total'), 7);
    },
  );
  test(
    'A04 keeps deletes as timestamped JSON null using the existing wire shape',
    () async {
      await prefs.setInt('tasbeeh_custom_target', 50);
      final journal = SyncStateJournal(prefs, 'one');
      await journal.record('tasbeeh_custom_target');
      await prefs.remove('tasbeeh_custom_target');
      await journal.record('tasbeeh_custom_target');
      expect(
        journal.dirty(SyncService.syncedStateKeys).single['value'],
        'null',
      );
      expect(validSyncStateValue('tasbeeh_custom_target', null), isTrue);
    },
  );
  test('A04 malformed metadata preserves original preference values', () async {
    await prefs.setInt('quran_last_page', 541);
    final journal = SyncStateJournal(prefs, 'one');
    await prefs.setString(journal.storageKey, '{');
    final reopened = SyncStateJournal(prefs, 'one');
    expect(reopened.entries, isEmpty);
    expect(prefs.getInt('quran_last_page'), 541);
    await reopened.record('quran_last_page');
    expect(reopened.dirty(SyncService.syncedStateKeys).single['value'], '541');
  });
}
