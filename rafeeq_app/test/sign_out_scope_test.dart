import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/services/sync_service.dart';

/// Signing out removes the ACCOUNT's data — the synced keys and counters —
/// and nothing else (audit 2026-09-24, D1: it used to clear every setting).
/// A counter synced from anywhere in lib/ must therefore be on the list, or
/// it would outlive the sign-out that is meant to take it away.
void main() {
  test('every synced counter is removed on sign-out', () {
    final used = <String>{};
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      for (final m in RegExp(r"incrementCounter\('([a-z_]+)'")
          .allMatches(f.readAsStringSync())) {
        used.add(m.group(1)!);
      }
    }
    expect(used, isNotEmpty);
    expect(SyncService.syncedCounterKeys.containsAll(used), isTrue,
        reason: 'synced but not cleared on sign-out: '
            '${used.difference(SyncService.syncedCounterKeys)}');
  });

  test('sign-out no longer clears every preference', () {
    // Code lines only: the doc comment names the old call to explain it.
    final code = File('lib/core/services/sync_service.dart')
        .readAsLinesSync()
        .where((l) => !l.trimLeft().startsWith('//'));
    expect(code.any((l) => l.contains('_prefs.clear()')), isFalse);
  });
}
