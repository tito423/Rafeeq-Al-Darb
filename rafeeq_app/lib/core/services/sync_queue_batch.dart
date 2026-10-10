import 'dart:convert';

/// Existing /sync limits, mirrored from sync_backend/src/index.ts.
/// A queue row is acknowledged only after its final entry has been sent.
class SyncQueueBatch {
  static const maxUpdates = 100;
  static const maxCounters = 1000;
  static const maxBodyBytes = 1048576;
  static const maxStateCharacters = 524288;

  final List<int> completedIds;
  final String body;

  SyncQueueBatch(
    List<Map<String, dynamic>> updates,
    List<Map<String, dynamic>> counters,
    List<int> ids,
  ) : completedIds = List.unmodifiable(ids),
      body = jsonEncode({'updates': updates, 'counters': counters});
}

/// Splitting a state row preserves its original payload until ALL parts
/// succeed. A retry can repeat state upserts; counter event IDs stay intact.
Iterable<SyncQueueBatch> syncQueueBatches(
  List<Map<String, Object?>> rows,
) sync* {
  var updates = <Map<String, dynamic>>[];
  var counters = <Map<String, dynamic>>[];
  var completed = <int>[];
  final emptyBytes = utf8.encode('{"updates":[],"counters":[]}').length;
  var bytes = emptyBytes;

  for (final row in rows) {
    final id = row['id'] as int;
    final state = row['type'] == 'state';
    if (!state && row['type'] != 'counter') {
      throw const FormatException('Unknown sync queue row type');
    }
    final payload = jsonDecode(row['payload'] as String);
    final entries = state
        ? List<Map<String, dynamic>>.from(payload as List)
        : [Map<String, dynamic>.from(payload as Map)];
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      if (state &&
          (entry['value'] as String).length >
              SyncQueueBatch.maxStateCharacters) {
        // The Worker otherwise silently ignores this value with HTTP 200.
        throw const FormatException('Sync state exceeds the Worker limit');
      }
      final entryBytes = utf8.encode(jsonEncode(entry)).length;
      if (emptyBytes + entryBytes > SyncQueueBatch.maxBodyBytes) {
        throw const FormatException('Sync entry exceeds the request limit');
      }
      var target = state ? updates : counters;
      final limit = state
          ? SyncQueueBatch.maxUpdates
          : SyncQueueBatch.maxCounters;
      if (target.length >= limit ||
          bytes + entryBytes + (target.isEmpty ? 0 : 1) >
              SyncQueueBatch.maxBodyBytes) {
        yield SyncQueueBatch(updates, counters, completed);
        updates = [];
        counters = [];
        completed = [];
        bytes = emptyBytes;
        target = state ? updates : counters;
      }
      bytes += entryBytes + (target.isEmpty ? 0 : 1);
      target.add(entry);
    }
    completed.add(id);
  }
  if (updates.isNotEmpty || counters.isNotEmpty || completed.isNotEmpty) {
    yield SyncQueueBatch(updates, counters, completed);
  }
}
