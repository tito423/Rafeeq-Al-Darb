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

  /// Per-ayah recitation audio.
  static const String groupRecitations = 'rafeeq_recitations';

  /// One status-bar entry for all file downloads.
  static const String _notifGroupFiles = 'rafeeq_files_group';

  /// One status-bar entry for all recitation downloads.
  static const String _notifGroupRecitations = 'rafeeq_recitations_group';

  /// Large artifacts, a couple at a time — they are big enough that more
  /// parallelism just splits the same bandwidth and makes each one look
  /// stalled.
  static final MemoryTaskQueue fileQueue = MemoryTaskQueue()
    ..maxConcurrent = 2
    ..maxConcurrentByHost = 2;

  /// Ayah files are small and numerous, so the win here is concurrency. Six
  /// at a time turns a 286-request surah from a several-minute crawl into
  /// something that finishes while the user is still looking at it, without
  /// hammering the CDN hard enough to get rate-limited (which is its own way
  /// of "stopping at البقرة").
  static final MemoryTaskQueue recitationQueue = MemoryTaskQueue()
    ..maxConcurrent = 6
    ..maxConcurrentByHost = 6;

  static bool _ready = false;

  /// Idempotent — safe to call from every entry point that might be first.
  static Future<void> ensureInitialized() async {
    if (_ready) return;
    _ready = true;

    final downloader = FileDownloader();

    // Android 13+ will not show any of the notifications below without the
    // runtime grant. Asking here means the first download prompts, rather
    // than the app demanding it at launch for something the user may never use.
    await downloader.permissions.request(PermissionType.notifications);

    // ── One grouped notification per kind ────────────────────────────────
    // With `groupNotificationId` set, the plugin posts a single entry whose
    // progress bar counts *finished tasks out of total*, and removes it when
    // the group drains. This is what keeps a whole-surah or whole-reciter
    // download from filling the shade with hundreds of rows.
    downloader.configureNotificationForGroup(
      groupFiles,
      running: const TaskNotification('جارٍ التنزيل', 'الملفات المكتملة: {numFinished} من {numTotal}'),
      complete: const TaskNotification('اكتمل التنزيل', 'المحتوى جاهز للاستخدام بدون إنترنت'),
      error: const TaskNotification('تعذّر التنزيل', 'تعذّر إكمال بعض الملفات'),
      paused: const TaskNotification('التنزيل متوقف مؤقتًا', 'اضغط للمتابعة'),
      progressBar: true,
      groupNotificationId: _notifGroupFiles,
    );

    downloader.configureNotificationForGroup(
      groupRecitations,
      running: const TaskNotification('تنزيل التلاوة', 'الآيات المكتملة: {numFinished} من {numTotal}'),
      complete: const TaskNotification('اكتملت التلاوة', 'التلاوة جاهزة للاستماع بدون إنترنت'),
      error: const TaskNotification('تعذّر تنزيل التلاوة', 'تعذّر إكمال بعض الآيات'),
      paused: const TaskNotification('تنزيل التلاوة متوقف', 'اضغط للمتابعة'),
      progressBar: true,
      groupNotificationId: _notifGroupRecitations,
    );

    downloader
      ..addTaskQueue(fileQueue)
      ..addTaskQueue(recitationQueue);

    // Keeps task records in the plugin's own database so a transfer that
    // outlived the app can be reconciled on the next launch instead of
    // showing as lost.
    await downloader.trackTasksInGroup(groupFiles);
    await downloader.trackTasksInGroup(groupRecitations);
  }

  /// Re-attaches to transfers the OS kept running while the app was gone.
  /// Called once at startup; without it, a download that completed in the
  /// background would never post its completion back into the app.
  static Future<void> resumeFromBackground() async {
    await ensureInitialized();
    try {
      await FileDownloader().resumeFromBackground();
    } catch (_) {
      // Nothing to reconcile, or the platform declined — not fatal.
    }
  }
}
