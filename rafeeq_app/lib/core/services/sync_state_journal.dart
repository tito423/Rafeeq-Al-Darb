import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Consumers reload persisted account data without recreating their notifiers.
final syncStateRevisionProvider = StateProvider<int>((ref) => 0);

class SyncStateJournal {
  static const ownerKey = 'local_sync_account_v2';
  static const prefix = 'local_sync_journal_v2:';
  static const maxTimestamp = 9007199254740991;
  final SharedPreferences prefs;
  final String? account;
  final Map<String, Map<String, dynamic>> entries = {};
  final DateTime Function() clock;
  Future<void> _saving = Future<void>.value();

  SyncStateJournal(this.prefs, this.account, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now {
    try {
      final raw = jsonDecode(prefs.getString(storageKey) ?? '{}') as Map;
      for (final item in raw.entries) {
        final row = Map<String, dynamic>.from(item.value as Map);
        if (validTimestamp(row['t']) &&
            row['v'] is String &&
            row['d'] is bool) {
          entries[item.key as String] = row;
        }
      }
    } catch (_) {
      // A legacy or damaged journal cannot erase the original preferences.
    }
  }

  String get storageKey =>
      '$prefix${account == null ? "device" : "account:$account"}';
  static bool validTimestamp(Object? value) =>
      value is int && value >= 0 && value <= maxTimestamp;
  String valueFor(String key) => jsonEncode(prefs.get(key));

  Future<void> save() {
    final snapshot = jsonEncode(entries);
    // Do not let an older in-flight disk write replace a newer journal.
    return _saving = _saving.catchError((Object _) {}).then((_) async {
      if (!await prefs.setString(storageKey, snapshot)) {
        throw StateError('Sync journal persistence failed');
      }
    });
  }

  Future<void> record(String key) async {
    await recordValue(key, valueFor(key));
  }

  Future<void> recordValue(String key, String value) async {
    final previous = entries[key];
    if (previous?['v'] == value) return;
    final last = previous?['t'] as int? ?? -1;
    final timestamp = math.max(clock().millisecondsSinceEpoch, last + 1);
    if (!validTimestamp(timestamp)) {
      throw StateError('Sync modification time exceeds the supported range');
    }
    entries[key] = {'v': value, 't': timestamp, 'd': true};
    await save();
  }

  /// Original queue timestamps remain authoritative when their value matches.
  void adoptQueued(Map<String, dynamic> row) {
    final key = row['key'];
    if (key is! String ||
        row['value'] is! String ||
        !validTimestamp(row['updated_at']) ||
        valueFor(key) != row['value']) {
      return;
    }
    final previous = entries[key];
    if (previous == null || (previous['t'] as int) < row['updated_at']) {
      entries[key] = {'v': row['value'], 't': row['updated_at'], 'd': true};
    }
  }

  List<Map<String, dynamic>> dirty(Set<String> keys) => [
    for (final item in entries.entries)
      if (keys.contains(item.key) && item.value['d'] == true)
        {
          'key': item.key,
          'value': item.value['v'],
          'updated_at': item.value['t'],
        },
  ];

  Future<void> acknowledge(List<dynamic> updates) async {
    for (final raw in updates) {
      final item = Map<String, Object?>.from(raw as Map);
      final row = entries[item['key']];
      if (row != null &&
          row['v'] == item['value'] &&
          row['t'] == item['updated_at']) {
        row['d'] = false;
      }
    }
    await save();
  }

  bool accepts(String key, String value, Object? timestamp) {
    if (!validTimestamp(timestamp)) return false;
    final local = entries[key];
    if (local == null) return prefs.get(key) == null;
    if (valueFor(key) != local['v']) return false;
    if (local['d'] == true) return false;
    return (timestamp as int) > (local['t'] as int);
  }

  Future<void> received(String key, String value, int timestamp) async {
    entries[key] = {'v': value, 't': timestamp, 'd': false};
    await save();
  }

  Future<SyncStateJournal> switchAccount(
    String nextAccount,
    Set<String> states,
    Set<String> counters, {
    SyncStateJournal? nextJournal,
  }) async {
    final previous = prefs.getString(ownerKey);
    if (previous == nextAccount && account == nextAccount) return this;
    await save();
    final next =
        nextJournal ?? SyncStateJournal(prefs, nextAccount, clock: clock);
    if (previous == null) {
      // Adopt device-only mutations once; retain their actual write times.
      for (final item in entries.entries) {
        if (!next.entries.containsKey(item.key)) {
          next.entries[item.key] = Map<String, dynamic>.from(item.value);
        }
      }
    } else if (previous != nextAccount) {
      for (final key in states) {
        if (prefs.containsKey(key) || entries.containsKey(key)) {
          await record(key);
        }
      }
      await prefs.setString(
        '$prefix$previous:counters',
        jsonEncode({for (final key in counters) key: prefs.getInt(key)}),
      );
      for (final key in states) {
        await writePreferenceValue(
          prefs,
          key,
          next.entries.containsKey(key)
              ? jsonDecode(next.entries[key]!['v'] as String)
              : null,
        );
      }
      Map savedCounters = {};
      try {
        savedCounters =
            jsonDecode(prefs.getString('$prefix$nextAccount:counters') ?? '{}')
                as Map;
      } catch (_) {}
      for (final key in counters) {
        final value = savedCounters[key];
        await writePreferenceValue(prefs, key, value is int ? value : null);
      }
    }
    await next.save();
    if (!await prefs.setString(ownerKey, nextAccount)) {
      throw StateError('Sync account ownership persistence failed');
    }
    if (previous == null && account == null) {
      // Once adopted, device notes must never be inherited by another account.
      await prefs.remove(storageKey);
    }
    return next;
  }
}

Future<bool> writePreferenceValue(
  SharedPreferences prefs,
  String key,
  Object? value,
) {
  if (value == null) return prefs.remove(key);
  if (value is String) return prefs.setString(key, value);
  if (value is int) return prefs.setInt(key, value);
  if (value is bool) return prefs.setBool(key, value);
  if (value is double) return prefs.setDouble(key, value);
  if (value is List && value.every((item) => item is String)) {
    return prefs.setStringList(key, value.cast<String>());
  }
  throw const FormatException('Unsupported preference value');
}

bool validSyncStateValue(String key, Object? value) {
  if (value == null) return true;
  if (key == 'quran_last_page') {
    return value is int && value >= 1 && value <= 604;
  }
  if (key == 'tasbeeh_custom_target') return value is int && value > 0;
  if (value is! String) return false;
  final decoded = jsonDecode(value);
  if (key == 'ayah_notes_v1') {
    return decoded is Map &&
        decoded.keys.every((k) => k is String) &&
        decoded.values.every((v) => v is String);
  }
  if (key == 'khatma_list_v1') {
    return decoded is List && decoded.every((v) => v is Map);
  }
  return false;
}
