import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Dart download queues are only real if the platform underneath them is
/// at least as wide.
///
/// The owner reported «التلاوة بتقف تنزيل لما بحمل حاجات كتير في نفس الوقت».
/// Nothing was failing: `background_downloader` runs every transfer as a
/// WorkManager Worker, and WorkManager's default executor — read out of
/// `work-runtime-2.11.0.aar`, `ConfigurationKt.createDefaultExecutor` —
/// is
///
///     Executors.newFixedThreadPool(max(2, min(availableProcessors - 1, 4)))
///
/// **four threads at most, on any device.** `DownloadEngine` allows 20 tasks
/// in flight; sixteen of them were waiting on a thread. Widening the Dart
/// queues (which a previous session did, 2 → 8 and 6 → 12) could not help.
///
/// So this test ties the two together: whatever the queues are set to, the
/// pool in `RafeeqApplication` has to cover them.
void main() {
  final engine =
      File('lib/core/services/download_engine.dart').readAsStringSync();
  final application = File(
    'android/app/src/main/kotlin/com/tito/rafeeq_aldarb/RafeeqApplication.kt',
  ).readAsStringSync();

  int sumOf(RegExp re, String src) {
    final hits = re.allMatches(src).map((m) => int.parse(m.group(1)!));
    expect(hits, isNotEmpty, reason: 'nothing matched ${re.pattern}');
    return hits.reduce((a, b) => a + b);
  }

  test('the WorkManager pool covers both download queues', () {
    // `maxConcurrentByHost` also ends in `Concurrent...`, so the match is
    // anchored on the exact field name.
    final queued = sumOf(
      RegExp(r'\.\.maxConcurrent = (\d+)'),
      engine,
    );
    expect(queued, greaterThanOrEqualTo(12),
        reason: 'the queues were widened for a reason; this reads them');

    final pool = RegExp(r'ThreadPoolExecutor\(\s*(\d+),').firstMatch(application);
    expect(pool, isNotNull,
        reason: 'RafeeqApplication no longer sizes a pool — WorkManager is '
            'back to its 4-thread default and the recitation will stall '
            'behind any other download');
    expect(int.parse(pool!.group(1)!), greaterThanOrEqualTo(queued),
        reason: 'the queues allow $queued tasks in flight and the platform '
            'pool is narrower, so that many can never actually run');
  });

  test('the pool is actually handed to WorkManager', () {
    // A pool that is built and not passed to `Configuration.Builder` changes
    // nothing at all, and would still satisfy the test above.
    expect(application, contains('.setExecutor('));
    expect(application, contains('Configuration.Provider'));
  });

  test('the pool lets its threads go when nothing is downloading', () {
    // 20 threads that never die would be 20 threads on a phone that is just
    // reading the mushaf.
    expect(application, contains('allowCoreThreadTimeOut(true)'));
  });

  test('per-host politeness is unchanged', () {
    // Widening the pool must not turn into a burst at one CDN: the host caps
    // are what keep this polite, and they are the numbers that were measured
    // against the real hosts.
    final hostCaps = RegExp(r'maxConcurrentByHost = (\d+)')
        .allMatches(engine)
        .map((m) => int.parse(m.group(1)!))
        .toList();
    expect(hostCaps, isNotEmpty);
    for (final c in hostCaps) {
      expect(c, lessThanOrEqualTo(6));
    }
  });
}
