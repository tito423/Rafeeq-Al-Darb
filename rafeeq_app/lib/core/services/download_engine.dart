import 'dart:async';
import '../i18n/isolate_strings.dart';

import 'package:background_downloader/background_downloader.dart';

/// The one place `background_downloader` is configured for the whole app.
///
/// Everything that downloads a file — offline packs, books, the hadith
/// database, adhan clips, and every ayah of a recitation — goes through this
/// engine rather than through an in-Dart `dio` loop. That is the fix for the
/// download that "always stops at سورة البقرة":
///
///  * **The OS does the transferring.** `background_downloader` hands each
///    task to Android's own `WorkManager` service, so a transfer keeps going
///    when the app is backgrounded, and survives the process being killed —
///    where the old `dio` loop died with the isolate.
///  * **Requests run in parallel.** Al-Baqarah is 286 separate ayah files;
///    fetching them strictly one after another (the old behaviour) took
///    minutes and read as a freeze. [recitationQueue] runs several at once
///    while capping how many hit the same host, which is both far faster and
///    politer to the CDN than an unbounded burst.
///  * **Progress is reported by the platform**, not by counting bytes in
///    Dart and awaiting a notification rebuild on every chunk — which is what
///    made the old engine slower the more it had to report.
///
/// Notifications use `groupNotificationId`, so a 286-file surah download
/// collapses into **one** status-bar entry showing "n of 286 finished"
/// instead of flooding the shade.
class DownloadEngine {
  DownloadEngine._();

  /// Files: offline packs, books, the hadith DB, adhan clips.
  static const String groupFiles = 'rafeeq_files';

  /// Whole-surah recitation files, for «تحميل تلاوات القرآن».
  static const String groupQuranAudio = 'rafeeq_quran_audio';

  /// The ruqyah recordings. Same queue as [groupFiles]; a group of their own
  /// only so their notification can say what they are — «خلي في إشعار تنزيل
  /// الرقية اسمها تحميل ملفات الرقية الصوتية».
  static const String groupRuqyah = 'rafeeq_ruqyah';

  static const String _notifGroupRuqyah = 'rafeeq_ruqyah_group';

  /// The per-ayah downloads that were removed in 3.17.0 — «شيل خيار تحميل
  /// التلاوات على الجهاز ده خالص». Kept only so their leftover tasks can be
  /// cancelled once; nothing enqueues into it any more.
  static const String legacyGroupRecitations = 'rafeeq_recitations';

  /// One status-bar entry for all file downloads.
  static const String _notifGroupFiles = 'rafeeq_files_group';

  /// One status-bar entry for all recitation downloads.
  static const String _notifGroupQuranAudio = 'rafeeq_quran_audio_group';

  /// Large artifacts, a couple at a time — they are big enough that more
  /// parallelism just splits the same bandwidth and makes each one look
  /// stalled.
  /// **Why this is 8 and not 2.** He downloaded four mushafs at once and
  /// reported «التنزيلات بتقف خالص لما أجي أنزل حاجات كتيرة». They were not
  /// stopping. Every file the app fetches that is not an ayah goes through
  /// this one queue — mushaf pages, books, the hadith database, adhan clips —
  /// and it was two wide **in total**. Four mushafs is 4 × 604 = 2,416 page
  /// tasks sharing two slots, so the third and fourth genuinely do not move
  /// until the first two are done. From the outside that is indistinguishable
  /// from stalled.
  ///
  /// `maxConcurrentByHost` is what keeps it polite, and that is the number
  /// that must stay modest — the global cap only ever hurt. Measured against
  /// both audio hosts before changing it: 16 simultaneous requests were served
  /// without a single refusal (`scripts`-side probe, 2026-09-10), so 4 per
  /// host is well inside what they will take.
  static final MemoryTaskQueue fileQueue = MemoryTaskQueue()
    ..maxConcurrent = 8
    ..maxConcurrentByHost = 4;

  /// How many times one task may be put back after the platform refused to
  /// accept it, before it is left for «إصلاح التحميلات».
  static const int _maxReEnqueue = 3;

  static final Map<String, int> _reEnqueueAttempts = {};

  /// Tasks whose slot this engine had to free by hand, for the repair report.
  static int _slotsRecovered = 0;

  static int get slotsRecovered => _slotsRecovered;

  /// Frees the queue slots of tasks the platform is not actually running.
  ///
  /// **This is the jam.** `MemoryTaskQueue.advanceQueue` counts a task as
  /// active the moment it hands it to the platform:
  ///
  /// ```dart
  /// enqueued.add(task);
  /// _incrementCounts(task);
  /// enqueue(task).then((success) async {
  ///   if (!success) {
  ///     _log.warning('TaskId ... did not enqueue successfully and will be ignored');
  ///     ...
  ///   }
  /// ```
  ///
  /// On failure it logs, and **it never removes the task or decrements the
  /// counters** — only `taskFinished` does that, and `taskFinished` is driven
  /// by a status update that a task which never started will never produce.
  /// So every refused enqueue burns one slot permanently. Eight of them kill
  /// [fileQueue] and twelve kill [recitationQueue] for the life of the
  /// process: «لما تقف التلاوة بتهنج تماما». And «إصلاح التحميلات» adds to
  /// the same dead queue, which is why it «ولا بيعمل اي حاجة نهائي».
  ///
  /// [liveTaskIds] is what the platform says it is actually working on.
  /// Anything the queue believes is active and the platform has never heard of
  /// is a leaked slot, and gets it back. Pure so it can be tested without a
  /// device.
  static int releaseStuckTasks(
    MemoryTaskQueue queue,
    Set<String> liveTaskIds,
  ) {
    var freed = 0;
    for (final task in queue.enqueued.toList(growable: false)) {
      if (liveTaskIds.contains(task.taskId)) continue;
      queue.taskFinished(task); // removes it and decrements the counters
      freed++;
    }
    _slotsRecovered += freed;
    return freed;
  }

  /// Asks the platform which tasks are really in flight and unjams both
  /// queues against that answer. Returns the number of slots recovered.
  static Future<int> unjamQueues() async {
    final live = <String>{};
    for (final group in [groupFiles, groupRuqyah, groupQuranAudio]) {
      try {
        final tasks = await FileDownloader().allTasks(group: group);
        live.addAll(tasks.map((t) => t.taskId));
      } catch (_) {
        // If the platform cannot answer, treat nothing as live rather than
        // everything: a wrong "everything is running" would leave the jam in
        // place, which is the failure we are here to fix.
      }
    }
    return releaseStuckTasks(fileQueue, live);
  }

  /// When each task last said anything.
  static final Map<String, DateTime> _lastSeen = {};

  /// Cancels whole-surah downloads the platform still calls running but that
  /// have reported nothing for [after] — a connection that died without an
  /// error holds its slot for ever otherwise. Only this queue: its owner,
  /// `QuranAudioLibrary`, re-queues what was asked for on its next repair.
  static Future<int> cancelStalled({
    Duration after = const Duration(minutes: 2),
  }) async {
    final now = DateTime.now();
    final ids = <String>[];
    try {
      for (final t in await FileDownloader().allTasks(group: groupQuranAudio)) {
        final seen = _lastSeen[t.taskId];
        if (seen != null && now.difference(seen) > after) ids.add(t.taskId);
      }
      if (ids.isNotEmpty) await FileDownloader().cancelTasksWithIds(ids);
    } catch (_) {}
    return ids.length;
  }

  /// Puts a refused task back, a bounded number of times.
  ///
  /// The slot is freed first — without that, a queue that has refused
  /// [fileQueue.maxConcurrent] tasks can never enqueue anything again, so the
  /// retry would sit in `waiting` for ever.
  static void _onEnqueueRefused(MemoryTaskQueue queue, Task task) {
    queue.taskFinished(task);
    _slotsRecovered++;
    final attempts = (_reEnqueueAttempts[task.taskId] ?? 0) + 1;
    if (attempts > _maxReEnqueue) {
      _reEnqueueAttempts.remove(task.taskId);
      return; // left for «إصلاح التحميلات»; the file is still incomplete
    }
    _reEnqueueAttempts[task.taskId] = attempts;
    Timer(Duration(seconds: attempts * 2), () => queue.add(task));
  }

  static bool _ready = false;

  /// A broadcast fan-out of the plugin's own update stream.
  ///
  /// `FileDownloader().updates` is backed by a plain `StreamController`, i.e.
  /// **single-subscription**: the second listener to attach gets
  /// "Bad state: Stream has already been listened to" and then never receives
  /// anything. Two services here need those updates — `DownloadManager` for
  /// the hadith DB, books and adhan clips, and `AyahAudioService` for every
  /// ayah of a recitation — so whichever happened to attach second was
  /// silently deaf for the whole session.
  ///
  /// That is not a cosmetic bug. A service that never sees a status update
  /// never marks its tasks finished: recitation progress freezes mid-surah,
  /// the multi-host fallback that retries an ayah on the next CDN never
  /// fires, "download whole reciter" never advances past its first surah,
  /// and on the other side the hadith zip is never unpacked and registered
  /// even though the bytes arrived. It also depended on load order, which is
  /// why it looked intermittent.
  ///
  /// Everything now listens here instead, and this subscribes exactly once.
  static final StreamController<TaskUpdate> _updates =
      StreamController<TaskUpdate>.broadcast();

  /// Task updates for every consumer in the app. Safe to listen to any number
  /// of times, and from anywhere.
  static Stream<TaskUpdate> get updates => _updates.stream;

  static StreamSubscription<TaskUpdate>? _sourceSub;

  static bool _askedNotifications = false;

  /// Android 13+ will not show any of the notifications below without the
  /// runtime grant. Asked once, and only from a path that is really about to
  /// move bytes.
  ///
  /// This used to live inside [ensureInitialized], with a comment claiming it
  /// meant "the first download prompts, rather than the app demanding it at
  /// launch". That was not what happened: `main()` calls
  /// [resumeFromBackground], which calls [ensureInitialized], so on a fresh
  /// install the POST_NOTIFICATIONS dialog came up about 4.8 seconds into the
  /// cold start — measured on emulator-5554 from logcat, `START ...
  /// REQUEST_PERMISSIONS ... from uid (com.tito.rafeeq_aldarb)`, 4.8s after
  /// the activity started — which is squarely in the middle of the ~8s splash
  /// video. That is the owner's «أخّر الأذونات عشان تظهر الاسبلاش اسكرين
  /// كاملة».
  static Future<void> ensureNotificationPermission() async {
    if (_askedNotifications) return;
    _askedNotifications = true;
    try {
      await FileDownloader().permissions.request(PermissionType.notifications);
    } catch (_) {
      // Notifications are a convenience; a refused grant must not stop a
      // download from running.
    }
  }

  /// Idempotent — safe to call from every entry point that might be first.
  ///
  /// [askForNotifications] is false only for the startup reconciliation, which
  /// runs while the splash is on screen and enqueues nothing of its own.
  static Future<void> ensureInitialized({
    bool askForNotifications = true,
  }) async {
    if (askForNotifications) await ensureNotificationPermission();
    if (_ready) return;
    _ready = true;

    final downloader = FileDownloader();

    // Resolved off the translation asset rather than through `.tr()`:
    // this method can run in a headless isolate where
    // `Localization.instance` does not exist and `.tr()` silently
    // returns the key — which is exactly what shipped to the shade.
    final t = <String, String>{
      'notif.dl_files_complete_body': await IsolateStrings.tr('notif.dl_files_complete_body'),
      'notif.dl_files_complete_title': await IsolateStrings.tr('notif.dl_files_complete_title'),
      'notif.dl_files_error_body': await IsolateStrings.tr('notif.dl_files_error_body'),
      'notif.dl_files_error_title': await IsolateStrings.tr('notif.dl_files_error_title'),
      'notif.dl_files_running_body': await IsolateStrings.tr('notif.dl_files_running_body'),
      'notif.dl_files_running_title': await IsolateStrings.tr('notif.dl_files_running_title'),
      'notif.dl_paused_body': await IsolateStrings.tr('notif.dl_paused_body'),
      'notif.dl_paused_title': await IsolateStrings.tr('notif.dl_paused_title'),
      'notif.dl_recit_complete_body': await IsolateStrings.tr('notif.dl_recit_complete_body'),
      'notif.dl_recit_complete_title': await IsolateStrings.tr('notif.dl_recit_complete_title'),
      'notif.dl_recit_error_body': await IsolateStrings.tr('notif.dl_recit_error_body'),
      'notif.dl_recit_error_title': await IsolateStrings.tr('notif.dl_recit_error_title'),
      'notif.dl_recit_paused_title': await IsolateStrings.tr('notif.dl_recit_paused_title'),
      'notif.dl_recit_running_body': await IsolateStrings.tr('notif.dl_recit_running_body'),
      'notif.dl_recit_running_title': await IsolateStrings.tr('notif.dl_recit_running_title'),
      'notif.dl_ruqyah_running_title': await IsolateStrings.tr('notif.dl_ruqyah_running_title'),
      'notif.dl_ruqyah_complete_title': await IsolateStrings.tr('notif.dl_ruqyah_complete_title'),
      'notif.dl_ruqyah_error_title': await IsolateStrings.tr('notif.dl_ruqyah_error_title'),
    };


    // ── One grouped notification per kind ────────────────────────────────
    // With `groupNotificationId` set, the plugin posts a single entry whose
    // progress bar counts *finished tasks out of total*, and removes it when
    // the group drains. This is what keeps a whole-surah or whole-reciter
    // download from filling the shade with hundreds of rows.
    downloader.configureNotificationForGroup(
      groupFiles,
      running: TaskNotification(t['notif.dl_files_running_title']!,
          t['notif.dl_files_running_body']!),
      complete: TaskNotification(t['notif.dl_files_complete_title']!,
          t['notif.dl_files_complete_body']!),
      error: TaskNotification(t['notif.dl_files_error_title']!,
          t['notif.dl_files_error_body']!),
      paused: TaskNotification(t['notif.dl_paused_title']!,
          t['notif.dl_paused_body']!),
      progressBar: true,
      groupNotificationId: _notifGroupFiles,
    );

    downloader.configureNotificationForGroup(
      groupQuranAudio,
      running: TaskNotification(t['notif.dl_recit_running_title']!,
          t['notif.dl_recit_running_body']!),
      complete: TaskNotification(t['notif.dl_recit_complete_title']!,
          t['notif.dl_recit_complete_body']!),
      error: TaskNotification(t['notif.dl_recit_error_title']!,
          t['notif.dl_recit_error_body']!),
      paused: TaskNotification(t['notif.dl_recit_paused_title']!,
          t['notif.dl_paused_body']!),
      progressBar: true,
      groupNotificationId: _notifGroupQuranAudio,
    );

    downloader.configureNotificationForGroup(
      groupRuqyah,
      running: TaskNotification(t['notif.dl_ruqyah_running_title']!,
          t['notif.dl_files_running_body']!),
      complete: TaskNotification(t['notif.dl_ruqyah_complete_title']!,
          t['notif.dl_files_complete_body']!),
      error: TaskNotification(t['notif.dl_ruqyah_error_title']!,
          t['notif.dl_files_error_body']!),
      paused: TaskNotification(t['notif.dl_paused_title']!,
          t['notif.dl_paused_body']!),
      progressBar: true,
      groupNotificationId: _notifGroupRuqyah,
    );

    downloader.addTaskQueue(fileQueue);

    // «تنزيل التلاوة الكاملة لو حطّيت التطبيق في الخلفية التنزيل بيقف ويعلّق
    // ويرجع يبتدي من الأول». Two causes, both fixed here:
    //  * the whole-surah files waited in a Dart queue, and a Dart queue does
    //    not advance while Android has the app's isolate paused in the
    //    background — the three transfers in flight finished and nothing
    //    followed. They are now handed to the plugin's NATIVE holding queue,
    //    which starts the next one itself (at most 3 per group, 4 per host);
    //  * the transfers ran as ordinary background work that Android is free to
    //    stop. They run as foreground work now, with their notification.
    // A transfer that is interrupted anyway resumes from its bytes rather than
    // from zero: the tasks allow pause, and mp3quran answers range requests.
    try {
      await downloader.configure(
        globalConfig: [(Config.holdingQueue, (null, 4, 3))],
        androidConfig: [(Config.runInForeground, Config.always)],
      );
    } catch (_) {}

    // A refused enqueue is the one event that leaks a queue slot for ever —
    // see `releaseStuckTasks`. The plugin publishes it and then forgets it;
    // this is the only listener that can give the slot back.
    fileQueue.enqueueErrors
        .listen((task) => _onEnqueueRefused(fileQueue, task));


    // Keeps task records in the plugin's own database so a transfer that
    // outlived the app can be reconciled on the next launch instead of
    // showing as lost.
    await downloader.trackTasksInGroup(groupFiles);
    await downloader.trackTasksInGroup(groupRuqyah);
    await downloader.trackTasksInGroup(groupQuranAudio);

    // The one and only subscription to the plugin's single-subscription
    // stream; everyone else reads [updates].
    _sourceSub ??= downloader.updates.listen(
      (u) {
        _lastSeen[u.task.taskId] = DateTime.now();
        _updates.add(u);
      },
      onError: _updates.addError,
    );
  }

  /// Cancels, once, whatever the removed per-ayah downloads left with the
  /// platform — a surah that «حمّل الفاتحة بس ووقف» was still sitting there as
  /// hundreds of queued ayah tasks with a notification of its own.
  static Future<void> purgeLegacyRecitationTasks() async {
    try {
      await FileDownloader().reset(group: legacyGroupRecitations);
    } catch (_) {}
  }

  /// Re-attaches to transfers the OS kept running while the app was gone.
  /// Called once at startup; without it, a download that completed in the
  /// background would never post its completion back into the app.
  static Future<void> resumeFromBackground() async {
    // No permission prompt from here: this runs from `main()` with the splash
    // still on screen. The grant is asked for after the splash (see
    // `AlarmPermissionsService.requestStartupPermissions`), and again by the
    // first real download if it was refused then.
    await ensureInitialized(askForNotifications: false);
    try {
      await FileDownloader().resumeFromBackground();
    } catch (_) {
      // Nothing to reconcile, or the platform declined — not fatal.
    }
  }
}
