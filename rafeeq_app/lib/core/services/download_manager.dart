import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'download_foreground_service.dart';

/// Status of a single download task.
enum DownloadStatus { queued, downloading, paused, completed, failed, canceled }

/// One downloadable artifact (offline pack, PDF, audio...).
class DownloadTask {
  final String id;
  final String url;
  final String category;
  final String fileName;
  final bool unzipToDatabases;
  final String title;

  /// For `unzipToDatabases` tasks only: written next to the extracted `.db`
  /// as `<dbPath>.version` once the download completes, so `DbHelper
  /// .openDownloaded(expectedVersion: ...)` can tell a stale copy (already
  /// on disk from before this content changed) from a current one and
  /// prompt a re-download instead of silently opening old data — see
  /// `AppConfig.hadithDbVersion`'s doc for why this exists.
  final String? dbVersion;

  int received = 0;
  int? total;
  DownloadStatus status = DownloadStatus.queued;
  String? error;

  DownloadTask({
    required this.id,
    required this.url,
    required this.category,
    required this.fileName,
    this.unzipToDatabases = false,
    this.dbVersion,
    String? title,
  }) : title = title ?? fileName;

  double get progress =>
      total == null || total! <= 0 ? 0 : min(1.0, received / total!);
}

/// True offline download engine.
///
/// - Real streaming downloads via dio with Range-resume support.
/// - Live progress for the UI (broadcast stream) AND the Android status bar
///   (progress notification via [DownloadNotifications]).
/// - Unzips offline packs (e.g. the hadith database) into place atomically.
/// - Completed artifacts are registered in SharedPreferences so feature
///   modules can discover what is available offline.
class DownloadManager {
  DownloadManager._();
  static final DownloadManager instance = DownloadManager._();

  static const registryKey = 'download_registry_v1';

  // P3‑47: timeouts so a stalled/blocked connection fails fast instead of
  // hanging a download forever with no error and no progress (see the same
  // fix + reasoning in ayah_audio_service.dart). receiveTimeout is per-read-
  // gap for a streamed body, not the whole-file duration, so a big book/db
  // still downloads fine as long as bytes keep arriving.
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 60),
    sendTimeout: const Duration(seconds: 20),
  ));
  final Map<String, CancelToken> _tokens = {};
  final Map<String, DownloadTask> _tasks = {};
  final StreamController<List<DownloadTask>> _controller =
      StreamController<List<DownloadTask>>.broadcast();

  /// P3‑53 — FIFO download queue. Only [maxConcurrent] file(s) actually
  /// transfer at once; everything else waits its turn as [DownloadStatus
  /// .queued]. Set to 1 on purpose: real-device testing showed that starting
  /// 7 video downloads in parallel saturated CPU + RAM and froze the whole app
  /// (and flooded the status bar with 7 competing notifications). One-at-a-time
  /// keeps each transfer fast and the UI responsive, and lets a single
  /// aggregated progress notification replace the flood. `_tasks` is a
  /// `LinkedHashMap`, so iterating it yields tasks in the order they were
  /// enqueued — that ordering *is* the FIFO queue.
  static const int maxConcurrent = 1;
  int _active = 0;

  /// Starts as many queued tasks as the concurrency limit allows, oldest
  /// first, then returns. Re-invoked every time a slot frees (a task finishes)
  /// or a new task is enqueued/resumed.
  void _pump() {
    while (_active < maxConcurrent) {
      DownloadTask? next;
      for (final t in _tasks.values) {
        if (t.status == DownloadStatus.queued) {
          next = t;
          break;
        }
      }
      if (next == null) break;
      _active++;
      next.status = DownloadStatus.downloading;
      _notify();
      unawaited(_run(next).whenComplete(() {
        _active--;
        _pump();
        unawaited(_refreshAggregate());
      }));
    }
    unawaited(_refreshAggregate());
  }

  /// One aggregated status-bar notification for the whole queue instead of one
  /// per file: shows the file currently transferring, its %, and how many more
  /// are still waiting. Cleared when the queue drains.
  Future<void> _refreshAggregate() async {
    DownloadTask? current;
    var queued = 0;
    for (final t in _tasks.values) {
      if (t.status == DownloadStatus.downloading) {
        current ??= t;
      } else if (t.status == DownloadStatus.queued) {
        queued++;
      }
    }
    if (current == null) {
      await DownloadNotifications.instance.clearAggregate();
      return;
    }
    await DownloadNotifications.instance.aggregate(
      title: current.title,
      done: current.received,
      total: current.total ?? 0,
      remaining: queued,
    );
  }

  Stream<List<DownloadTask>> get stream => _controller.stream;
  List<DownloadTask> get tasks => _tasks.values.toList();
  DownloadTask? taskById(String id) => _tasks[id];

  /// Artifacts that finished downloading (id -> info map).
  Future<List<Map<String, dynamic>>> registeredArtifacts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(registryKey);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<String?> registeredPath(String id) async {
    final all = await registeredArtifacts();
    for (final a in all) {
      if (a['id'] == id) return a['path'] as String?;
    }
    return null;
  }

  Future<void> _registerCompleted(DownloadTask task, String finalPath) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(registryKey);
    List<dynamic> list = [];
    if (raw != null) {
      try {
        list = jsonDecode(raw) as List<dynamic>;
      } catch (_) {}
    }
    list.removeWhere((e) => e is Map && e['id'] == task.id);
    list.add({
      'id': task.id,
      'category': task.category,
      'fileName': task.fileName,
      'title': task.title,
      'path': finalPath,
      'size': task.total ?? 0,
      'completedAt': DateTime.now().toIso8601String(),
    });
    await prefs.setString(registryKey, jsonEncode(list));
  }

  Future<Directory> get downloadDir async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'downloads'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  File _partialFile(String finalPath) => File('$finalPath.part');

  /// Enqueue (or re-enqueue) a download.
  Future<void> enqueue({
    required String id,
    required String url,
    required String category,
    required String fileName,
    bool unzipToDatabases = false,
    String? dbVersion,
    String? title,
  }) async {
    final current = _tasks[id];
    if (current != null &&
        (current.status == DownloadStatus.downloading ||
            current.status == DownloadStatus.queued)) {
      return;
    }
    final task = DownloadTask(
      id: id,
      url: url,
      category: category,
      fileName: fileName,
      unzipToDatabases: unzipToDatabases,
      dbVersion: dbVersion,
      title: title,
    );
    // Enters the queue as `queued`; `_pump` promotes it to `downloading` only
    // when a concurrency slot is free (see [maxConcurrent]).
    _tasks[id] = task;
    _notify();
    await DownloadNotifications.instance.ensureInitialized();
    _pump();
  }

  void pause(String id) {
    _tokens[id]?.cancel('paused');
    final t = _tasks[id];
    if (t != null && t.status == DownloadStatus.downloading) {
      t.status = DownloadStatus.paused;
    }
    _notify();
  }

  void resume(String id) {
    final t = _tasks[id];
    if (t == null) return;
    if (t.status == DownloadStatus.paused ||
        t.status == DownloadStatus.failed ||
        t.status == DownloadStatus.canceled ||
        t.status == DownloadStatus.queued) {
      // Re-queue (don't run directly) so it obeys the same one-at-a-time limit
      // as every other task instead of racing them.
      t.status = DownloadStatus.queued;
      _notify();
      _pump();
    }
  }

  void cancel(String id) {
    _tokens[id]?.cancel('canceled');
    final t = _tasks[id];
    if (t != null && t.status == DownloadStatus.downloading) {
      t.status = DownloadStatus.canceled;
    }
    _notify();
  }

  Future<void> remove(String id) async {
    cancel(id);
    final t = _tasks.remove(id);

    // Delete the on-disk artifact. Prefer the registry's recorded path (it may
    // be a `.db` under `databases/` or an unzipped folder, not just
    // `downloads/<fileName>`), then also sweep the raw download names.
    final registered = await registeredPath(id);
    if (registered != null) {
      final entity = FileSystemEntity.typeSync(registered);
      if (entity == FileSystemEntityType.directory) {
        await Directory(registered).delete(recursive: true);
      } else if (entity == FileSystemEntityType.file) {
        await File(registered).delete();
      }
    }
    if (t != null) {
      final dir = await downloadDir;
      for (final name in [t.fileName, '${t.fileName}.part']) {
        final f = File(p.join(dir.path, name));
        if (f.existsSync()) await f.delete();
      }
    }

    // Purge the completed-artifacts registry entry — without this the item
    // still reads as "downloaded" on the next launch (P2‑4's حذف button).
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(registryKey);
    if (raw != null) {
      try {
        final list = (jsonDecode(raw) as List<dynamic>)
          ..removeWhere((e) => e is Map && e['id'] == id);
        await prefs.setString(registryKey, jsonEncode(list));
      } catch (_) {}
    }

    _notify();
  }

  /// Bytes an already-downloaded artifact occupies on disk (0 if unknown).
  Future<int> artifactSize(String id) async {
    final path = await registeredPath(id);
    if (path == null) return 0;
    try {
      final type = FileSystemEntity.typeSync(path);
      if (type == FileSystemEntityType.file) return File(path).lengthSync();
      if (type == FileSystemEntityType.directory) {
        var total = 0;
        for (final e in Directory(path).listSync(recursive: true)) {
          if (e is File) total += e.lengthSync();
        }
        return total;
      }
    } catch (_) {}
    return 0;
  }

  void dispose() => _controller.close();

  void _notify() {
    if (!_controller.isClosed) _controller.add(tasks);
  }

  Future<void> _run(DownloadTask task) async {
    final token = CancelToken();
    _tokens[task.id] = token;
    task.status = DownloadStatus.downloading;
    task.error = null;
    _notify();
    // P3-46: see DownloadForegroundServiceBridge's own doc — protects this
    // process from being frozen/killed by the OS while backgrounded during
    // this download. Paired release() in `finally` below, whatever the
    // outcome (success, failure, or cancel).
    await DownloadForegroundServiceBridge.acquire(title: task.title);

    try {
      final dir = await downloadDir;
      final finalPath = p.join(dir.path, task.fileName);
      final partial = _partialFile(finalPath);
      var existing = partial.existsSync() ? partial.lengthSync() : 0;

      final response = await _dio.get<ResponseBody>(
        task.url,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: true,
          headers: existing > 0 ? {'range': 'bytes=$existing-'} : null,
        ),
        cancelToken: token,
      );

      final status = response.statusCode ?? 200;
      var start = existing;
      if (existing > 0 && status != 206) {
        // Server ignored the Range header â€” restart cleanly.
        start = 0;
        await partial.writeAsBytes([], flush: true);
      }

      if (status == 206) {
        final cr = response.headers.value('content-range');
        final m =
            cr == null ? null : RegExp(r'bytes \d+-\d+/(\d+)').firstMatch(cr);
        if (m != null) {
          task.total = int.parse(m.group(1)!);
        }
      } else {
        final cl = response.headers.value('content-length');
        final n = cl == null ? null : int.tryParse(cl);
        task.total = n == null ? null : start + n;
      }
      task.received = start;
      _notify();
      await _refreshAggregate();

      final raf = await partial.open(mode: FileMode.append);
      try {
        await for (final chunk in response.data!.stream) {
          await raf.writeFrom(chunk);
          task.received += chunk.length;
          _notify();
          await _refreshAggregate();
        }
      } finally {
        await raf.close();
      }

      if (task.total != null && task.received < task.total!) {
        throw const DownloadIncomplete();
      }
      await partial.rename(finalPath);

      var registeredPath = finalPath;
      if (task.unzipToDatabases &&
          task.fileName.toLowerCase().endsWith('.zip')) {
        registeredPath = await _unzipToDatabases(finalPath);
        if (task.dbVersion != null) {
          await File('$registeredPath.version')
              .writeAsString(task.dbVersion!, flush: true);
        }
      }

      task.status = DownloadStatus.completed;
      await _registerCompleted(task, registeredPath);
      // No per-file "done" toast — the aggregate notification (refreshed by
      // `_pump` when this slot frees) reflects the queue as a whole, and the
      // in-app downloads list shows each item's completed state.
      _notify();
    } on DioException catch (e) {
      if (!CancelToken.isCancel(e)) {
        task.status = DownloadStatus.failed;
        // e.message is frequently null for connectionError/badCertificate
        // types — the real detail lives on e.error (the wrapped underlying
        // exception, e.g. a SocketException or HandshakeException). Falling
        // straight to the generic "network error" string hid that detail.
        task.error = e.message ?? e.error?.toString() ?? e.type.name;
      }
      _notify();
    } catch (e) {
      task.status = DownloadStatus.failed;
      task.error = e.toString();
      _notify();
    } finally {
      _tokens.remove(task.id);
      await DownloadForegroundServiceBridge.release();
    }
  }

  /// Unzips a pack. A single `.db` inside is installed into `databases/<stem>`;
  /// otherwise the archive is extracted under `downloads/<stem>/`.
  Future<String> _unzipToDatabases(String zipPath) async {
    final support = await getApplicationSupportDirectory();
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    ArchiveFile? singleDb;
    for (final entry in archive) {
      if (entry.isFile && entry.name.toLowerCase().endsWith('.db')) {
        singleDb = entry;
        break;
      }
    }

    final dbDir = p.join(support.path, 'databases');
    await Directory(dbDir).create(recursive: true);

    if (singleDb != null) {
      final stem = p.basenameWithoutExtension(zipPath);
      final target = p.join(dbDir, '$stem.db');
      final f = File('$target.tmp');
      await f.writeAsBytes(singleDb.content as List<int>, flush: true);
      final dest = File(target);
      if (dest.existsSync()) await dest.delete();
      await f.rename(target);
      await File(zipPath).delete();
      return target;
    }

    final stem = p.basenameWithoutExtension(zipPath);
    final outDir = Directory(p.join(p.dirname(zipPath), stem));
    if (!outDir.existsSync()) outDir.createSync(recursive: true);
    for (final entry in archive) {
      if (!entry.isFile) continue;
      final f = File(p.join(outDir.path, entry.name));
      await f.parent.create(recursive: true);
      await f.writeAsBytes(entry.content as List<int>, flush: true);
    }
    return outDir.path;
  }
}

/// Raised when a stream ends before the advertised content length.
class DownloadIncomplete implements Exception {
  const DownloadIncomplete();
  @override
  String toString() => 'incomplete download';
}

/// Android status-bar progress for downloads (real notification progress).
class DownloadNotifications {
  DownloadNotifications._();
  static final DownloadNotifications instance = DownloadNotifications._();

  static const _channelId = 'rafeeq_downloads';
  static const _channelName = 'Downloads';
  bool _ready = false;

  Future<void> ensureInitialized() async {
    if (_ready) return;
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await plugin.initialize(
        const InitializationSettings(android: android),
        onDidReceiveNotificationResponse: (_) {},
      );
      // Android 13+ needs the runtime POST_NOTIFICATIONS grant before any
      // progress notification will show. Ask once, on the first download.
      final androidImpl = plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();
      _ready = true;
    } catch (_) {
      // Notifications are optional; downloads still work without them.
    }
  }

  int _notificationId(String id) => 4700 + _hash(id);

  static int _hash(String s) {
    var h = 0;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h % 300;
  }

  /// Last time a progress notification was posted for an id — used to throttle
  /// updates to ~1/sec so a fast download doesn't spam the shade.
  final Map<String, DateTime> _lastPost = {};

  // ── generic entry points (used by every download kind: DownloadManager
  //    files, mushaf-page prefetch, per-surah recitation, …) ──────────────

  /// Post/refresh an ongoing progress notification for [id]. [done]/[total]
  /// drive a determinate bar; pass [total] <= 0 for an indeterminate one.
  /// [detail] overrides the auto "NN%" line (e.g. "١٢ / ١١٤ صفحة").
  Future<void> showProgress({
    required String id,
    required String title,
    required int done,
    required int total,
    String? detail,
    bool force = false,
  }) async {
    if (!_ready || !Platform.isAndroid) return;
    final now = DateTime.now();
    final last = _lastPost[id];
    final complete = total > 0 && done >= total;
    if (!force && !complete && last != null &&
        now.difference(last) < const Duration(milliseconds: 900)) {
      return;
    }
    _lastPost[id] = now;
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      final hasSize = total > 0;
      final pct = hasSize ? ((done / total) * 100).round() : 0;
      final android = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Offline content download progress',
        importance: Importance.low,
        priority: Priority.low,
        onlyAlertOnce: true,
        ongoing: true,
        showProgress: hasSize,
        maxProgress: 100,
        progress: pct,
        indeterminate: !hasSize,
      );
      await plugin.show(
        _notificationId(id),
        title,
        detail ?? (hasSize ? '$pct%' : '$done'),
        NotificationDetails(android: android),
      );
    } catch (_) {}
  }

  /// Replace the ongoing notification for [id] with a short auto-dismissing
  /// "downloaded" one.
  Future<void> showComplete({required String id, required String title}) async {
    if (!_ready || !Platform.isAndroid) return;
    _lastPost.remove(id);
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin.cancel(_notificationId(id));
      const android = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Offline content download progress',
        importance: Importance.low,
        priority: Priority.low,
      );
      await plugin.show(
        _notificationId(id) + 1000,
        title,
        'تم التنزيل — جاهز للاستخدام بدون إنترنت',
        const NotificationDetails(android: android),
      );
    } catch (_) {}
  }

  /// Remove the ongoing notification for [id] (cancel / failure — no toast).
  Future<void> clear(String id) async {
    _lastPost.remove(id);
    if (!_ready || !Platform.isAndroid) return;
    try {
      await FlutterLocalNotificationsPlugin().cancel(_notificationId(id));
    } catch (_) {}
  }

  // ── DownloadManager aggregated queue notification ───────────────────────
  // P3‑53: ONE ongoing notification for the whole download queue (the file
  // transferring now + how many are still waiting), instead of one per file.

  static const _aggregateId = 4699;
  DateTime? _aggregateLastPost;

  /// Post/refresh the single queue notification. [remaining] is how many other
  /// files are still queued behind the current one. Throttled to ~1/sec.
  Future<void> aggregate({
    required String title,
    required int done,
    required int total,
    required int remaining,
  }) async {
    if (!_ready || !Platform.isAndroid) return;
    final hasSize = total > 0;
    final pct = hasSize ? ((done / total) * 100).round() : 0;
    final complete = hasSize && done >= total;
    final now = DateTime.now();
    if (!complete &&
        _aggregateLastPost != null &&
        now.difference(_aggregateLastPost!) < const Duration(milliseconds: 900)) {
      return;
    }
    _aggregateLastPost = now;
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      final body = StringBuffer(hasSize ? '$pct%' : 'جارٍ التنزيل…');
      if (remaining > 0) body.write('  •  $remaining في الانتظار');
      final android = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Offline content download progress',
        importance: Importance.low,
        priority: Priority.low,
        onlyAlertOnce: true,
        ongoing: true,
        showProgress: hasSize,
        maxProgress: 100,
        progress: pct,
        indeterminate: !hasSize,
      );
      await plugin.show(
        _aggregateId,
        title,
        body.toString(),
        NotificationDetails(android: android),
      );
    } catch (_) {}
  }

  /// Remove the queue notification (the queue has fully drained).
  Future<void> clearAggregate() async {
    _aggregateLastPost = null;
    if (!_ready || !Platform.isAndroid) return;
    try {
      await FlutterLocalNotificationsPlugin().cancel(_aggregateId);
    } catch (_) {}
  }
}
