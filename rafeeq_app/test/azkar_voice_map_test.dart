import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Every dhikr in the bundled azkar.db must have its voicing in
/// assets/data/azkar_voice.json (3.90.0: all 302, none missing, none extra).
void main() {
  test('every dhikr has exactly one voice file entry', () async {
    final raw = jsonDecode(File('assets/data/azkar_voice.json').readAsStringSync())
        as Map<String, dynamic>;
    expect(raw['source'], 'azkar/rafeeq_voice/items/v1/');
    final items = raw['items'] as Map<String, dynamic>;
    for (final e in items.entries) {
      final m = e.value as Map<String, dynamic>;
      expect((m['bytes'] as num) > 1000, isTrue, reason: 'dhikr ${e.key} bytes');
      expect((m['seconds'] as num) > 0, isTrue, reason: 'dhikr ${e.key} seconds');
    }

    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(
        File('assets/data/azkar.db').absolute.path,
        options: OpenDatabaseOptions(readOnly: true));
    final ids = (await db.rawQuery('SELECT id FROM azkar_items'))
        .map((r) => '${r['id']}')
        .toSet();
    await db.close();
    expect(ids.length, 302);
    expect(items.keys.toSet(), ids);
  });
}
