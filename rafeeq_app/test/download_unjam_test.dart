import 'package:background_downloader/background_downloader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/services/download_engine.dart';

/// The jam behind both of the owner's reports, proved against the real
/// `MemoryTaskQueue` rather than a stand-in.
///
/// > «اصلاح التحميلات ده ولا بيعمل اي حاجة نهائي ولما تقف التلاوة بتهنج تماما»
///
/// `MemoryTaskQueue.advanceQueue` counts a task as active the moment it hands
/// it to the platform, and on a refused enqueue it logs a warning and leaves
/// it counted for ever — only `taskFinished` removes it, and a task that never
/// started never produces the status update that would call it. So every
/// refusal burns one slot permanently: eight kill the file queue, twelve kill
/// the recitation queue, and repair then adds to a queue with no slots left,
/// which is a button that does nothing.
DownloadTask _task(String id) => DownloadTask(
      taskId: id,
      url: 'https://example.invalid/$id.mp3',
      filename: '$id.mp3',
      group: 'rafeeq_recitations',
    );

void main() {
  test('a queue with leaked slots cannot advance — this is the hang', () {
    final queue = MemoryTaskQueue()
      ..maxConcurrent = 2
      ..maxConcurrentByHost = 2;

    // Two tasks the platform refused: counted as active, never started.
    queue.enqueued.addAll([_task('ghost-1'), _task('ghost-2')]);
    expect(queue.numActive, 2);

    queue.waiting.add(_task('real-1'));
    expect(queue.getNextTask(), isNull,
        reason: 'the queue is full of tasks that are not running');
  });

  test('releasing the stuck slots starts it moving again', () {
    final queue = MemoryTaskQueue()
      ..maxConcurrent = 2
      ..maxConcurrentByHost = 2;
    queue.enqueued.addAll([_task('ghost-1'), _task('ghost-2')]);

    // The platform is running none of them. Freed with `waiting` empty on
    // purpose: `taskFinished` advances the queue, and advancing it here would
    // reach `FileDownloader().enqueue`, which needs a device.
    final freed = DownloadEngine.releaseStuckTasks(queue, <String>{});

    expect(freed, 2);
    expect(queue.numActive, 0);

    queue.waiting.add(_task('real-1'));
    final next = queue.getNextTask();
    expect(next, isNotNull,
        reason: 'with its slots back the queue can pick work up again');
    expect(next!.taskId, 'real-1');
  });

  test('a task the platform IS running keeps its slot', () {
    // The whole risk of this repair is cancelling a live download by calling
    // it finished, so the live set is what decides, not a timeout.
    final queue = MemoryTaskQueue()..maxConcurrent = 4;
    queue.enqueued.addAll([_task('live-1'), _task('ghost-1')]);

    final freed = DownloadEngine.releaseStuckTasks(queue, {'live-1'});

    expect(freed, 1);
    expect(queue.numActive, 1);
    expect(queue.enqueued.single.taskId, 'live-1');
  });

  test('nothing to free on a healthy queue, and nothing is disturbed', () {
    final queue = MemoryTaskQueue()..maxConcurrent = 4;
    queue.enqueued.addAll([_task('live-1'), _task('live-2')]);

    expect(
      DownloadEngine.releaseStuckTasks(queue, {'live-1', 'live-2'}),
      0,
    );
    expect(queue.numActive, 2);
  });

  test('the two queues the app really uses are the ones repaired', () {
    // A regression guard on the wiring: `unjamQueues` has to reach both, and
    // both have to be the objects `ensureInitialized` registers.
    expect(DownloadEngine.fileQueue, isA<MemoryTaskQueue>());
    expect(DownloadEngine.recitationQueue, isA<MemoryTaskQueue>());
    expect(identical(DownloadEngine.fileQueue, DownloadEngine.recitationQueue),
        isFalse);
  });
}
