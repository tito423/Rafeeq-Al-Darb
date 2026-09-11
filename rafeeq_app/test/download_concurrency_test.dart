import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// What the app's download concurrency actually is, and one hypothesis about
/// it that was tested on a device and **rejected**.
///
/// The owner reported «التلاوة بتقف تنزيل لما بحمل حاجات كتير في نفس الوقت».
///
/// THE HYPOTHESIS, AND WHY IT LOOKED RIGHT. `background_downloader` runs every
/// transfer as a WorkManager Worker, and WorkManager's default executor — read
/// out of `work-runtime-2.11.0.aar`, `ConfigurationKt.createDefaultExecutor` —
/// compiles to
///
///     Executors.newFixedThreadPool(max(2, min(availableProcessors - 1, 4)))
///
/// i.e. **four threads at most on any device**, while `DownloadEngine` allows
/// 20 tasks in flight. That reads like sixteen tasks waiting on a thread.
///
/// THE MEASUREMENT THAT KILLED IT, on emulator-5554: two mushafs and
/// al-Baqarah's 286 ayahs downloading together, counting the app's established
/// TCP connections out of `/proc/net/tcp`.
///
///   * a 20-thread pool → **11 connections**, al-Baqarah at 10/286 climbing;
///   * a **2**-thread pool → **10 connections**, al-Baqarah at 53/286.
///
/// No difference. The reason is in the plugin: `TaskWorker` is a
/// `CoroutineWorker`, so `doWork` runs on the coroutine context and the
/// transfer itself sits in `withContext(Dispatchers.IO)` — it never occupies
/// a WorkManager executor thread at all. The pool was reverted rather than
/// shipped with a story attached to it.
///
/// So what this test guards is what is actually true: the Dart-side queues are
/// the app's real limits, and the per-host caps are the measured, polite ones.
/// **The owner's stall is not reproduced and not explained** — see
/// `WORK_QUEUE.md` C2.
void main() {
  final engine =
      File('lib/core/services/download_engine.dart').readAsStringSync();

  List<int> fieldValues(String field) {
    final hits = RegExp('$field = (\\d+)')
        .allMatches(engine)
        .map((m) => int.parse(m.group(1)!))
        .toList();
    expect(hits, isNotEmpty, reason: 'no $field in DownloadEngine');
    return hits;
  }

  test('the file queue is wide, the whole-surah queue is not', () {
    // The file queue was 2 and was widened after he first reported downloads
    // «بتقف خالص» with four mushafs going. The second queue carries whole
    // surahs since 3.17.0 — files up to 255 MB — where a dozen at once only
    // splits the line; three is deliberate.
    final caps = fieldValues(r'\.\.maxConcurrent');
    expect(caps, [8, 3]);
  });

  test('per-host politeness is capped, and measured', () {
    // 16 simultaneous requests were served by both audio hosts without a
    // refusal (probe, 2026-09-10), so 4 and 6 are well inside what they take.
    // This is the number that must stay modest: the global cap only ever hurt.
    final hostCaps = fieldValues('maxConcurrentByHost');
    expect(hostCaps.length, 2);
    for (final c in hostCaps) {
      expect(c, lessThanOrEqualTo(6));
      expect(c, greaterThanOrEqualTo(2));
    }
  });

  test('recitations and files do not share a queue', () {
    // They are separate `MemoryTaskQueue`s on purpose: a surah of 286 small
    // ayah files and a 604-page mushaf have nothing to gain from queueing
    // behind each other, and each queue counts its hosts separately.
    expect(engine, contains('MemoryTaskQueue fileQueue'));
    expect(engine, contains('MemoryTaskQueue quranAudioQueue'));
    expect(engine, contains('addTaskQueue(fileQueue)'));
    expect(engine, contains('addTaskQueue(quranAudioQueue)'));
  });
}
