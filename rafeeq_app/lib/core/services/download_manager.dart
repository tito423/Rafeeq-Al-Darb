import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:background_downloader/background_downloader.dart' as bd;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'download_engine.dart';

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

  /// The `background_downloader` task actually carrying the bytes. Kept so
  /// pause/resume/cancel act on the real platform transfer rather than on a
  /// Dart-side flag.
  bd.DownloadTask? platformTask;

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

/// True offline download engine, running on the platform's own background
/// downloader.
///
/// Rebuilt (was a hand-rolled `dio` streaming loop): transfers are handed to
/// Android's `WorkManager` through [DownloadEngine], so they continue while
/// the app is backgrounded and survive the process being killed — the old
/// loop lived in the Dart isolate and died with it, which is the honest
/// reason a large download "stopped for no reason". Pause/resume are the
/// platform's own Range-based ones, retries are automatic, and the whole
/// queue shows as a single grouped status-bar notification instead of one
/// row per file.
///
/// The public surface is unchanged, so every feature module that already
/// enqueues work here keeps working untouched.
class DownloadManager {
  DownloadManager._();
  static final DownloadManager instance = DownloadManager._();

  static const registryKey = 'download_registry_v1';

  final Map<String, DownloadTask> _tasks = {};
  final StreamController<List<DownloadTask>> _controller =
      StreamController<List<DownloadTask>>.broadcast();

  /// platform taskId -> our task id.
  final Map<String, String> _byPlatformId = {};

  StreamSubscription<bd.TaskUpdate>? _updates;
  bool _wired = false;

  Stream<List<DownloadTask>> get stream => _controller.stream;
  List<DownloadTask> get tasks => _tasks.values.toList();
  DownloadTask? taskById(String id) => _tasks[id];

  /// Subscribes to the platform's update stream once. Every status and
  /// progress event for our group lands here, including events for a
  /// transfer that completed while the app was not running.
  Future<void> _ensureWired() async {
    if (_wired) return;
    _wired = true;
    await DownloadEngine.ensureInitialized();
    // Via DownloadEngine's broadcast fan-out — the plugin's own stream is
    // single-subscription and AyahAudioService needs it too.
    _updates = DownloadEngine.updates.listen(_onUpdate);
    await DownloadEngine.resumeFromBackground();
  }

  void _onUpdate(bd.TaskUpdate update) {
    if (update.task.group != DownloadEngine.groupFiles) return;
    final id = _byPlatformId[update.task.taskId];
    if (id == null) return;
    final task = _tasks[id];
    if (task == null) return;

    switch (update) {
      case bd.TaskStatusUpdate():
        switch (update.status) {
          case bd.TaskStatus.enqueued:
            task.status = DownloadStatus.queued;
          case bd.TaskStatus.running:
            task.status = DownloadStatus.downloading;
            task.error = null;
          case bd.TaskStatus.paused:
            task.status = DownloadStatus.paused;
          case bd.TaskStatus.canceled:
            task.status = DownloadStatus.canceled;
          case bd.TaskStatus.waitingToRetry:
            task.status = DownloadStatus.downloading;
          case bd.TaskStatus.complete:
            unawaited(_finish(task));
          case bd.TaskStatus.notFound:
            task.status = DownloadStatus.failed;
            task.error = 'الملف غير موجود على الخادم (404)';
          case bd.TaskStatus.failed:
            task.status = DownloadStatus.failed;
            task.error = update.exception?.description ?? 'تعذّر التنزيل';
        }
      case bd.TaskProgressUpdate():
        // A negative progress value is the plugin's way of signalling a
        // non-progress condition (paused, failed, …) — those arrive as status
        // updates above, so only real 0..1 fractions move the bar.
        if (update.progress >= 0) {
          if (update.expectedFileSize > 0) {
            task.total = update.expectedFileSize;
            task.received = (update.expectedFileSize * update.progress).round();
          } else {
            // Unknown size: keep a usable fraction for the UI anyway.
            task.total = 1000000;
            task.received = (1000000 * update.progress).round();
          }
        }
    }
    _notify();
  }

  /// Post-transfer work: unzip a pack, stamp its version, register it.
  Future<void> _finish(DownloadTask task) async {
    try {
      final dir = await downloadDir;
      final finalPath = p.join(dir.path, task.fileName);
      var registered = finalPath;

      if (task.unzipToDatabases &&
          task.fileName.toLowerCase().endsWith('.zip')) {
        registered = await _unzipToDatabases(finalPath);
        if (task.dbVersion != null) {
          await File(
            '$registered.version',
          ).writeAsString(task.dbVersion!, flush: true);
        }
      }

      if (task.total == null || task.total == 0) {
        final f = File(registered);
        if (f.existsSync()) {
          task.total = f.lengthSync();
          task.received = task.total!;
        }
      }
      task.status = DownloadStatus.completed;
      await _registerCompleted(task, registered);
    } catch (e) {
      task.status = DownloadStatus.failed;
      task.error = e.toString();
    }
    _notify();
  }

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

  /// Where finished files land. `background_downloader` writes them here too
  /// (`BaseDirectory.applicationSupport` + `downloads`), so the paths the
  /// registry records are unchanged from the previous engine and already
  /// downloaded content keeps resolving.
  Future<Directory> get downloadDir async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'downloads'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

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
    await _ensureWired();

    final task = DownloadTask(
      id: id,
      url: url,
      category: category,
      fileName: fileName,
      unzipToDatabases: unzipToDatabases,
      dbVersion: dbVersion,
      title: title,
    );

    final platform = bd.DownloadTask(
      url: url,
      filename: fileName,
      baseDirectory: bd.BaseDirectory.applicationSupport,
      directory: 'downloads',
      group: DownloadEngine.groupFiles,
      updates: bd.Updates.statusAndProgress,
      // Range-based resume, so a dropped connection continues instead of
      // starting the file over — the whole point for multi-hundred-MB packs.
      allowPause: true,
      retries: 3,
      displayName: task.title,
      metaData: id,
    );

    task.platformTask = platform;
    _tasks[id] = task;
    _byPlatformId[platform.taskId] = id;
    _notify();

    // Through the queue rather than straight to `enqueue`, so the concurrency
    // caps in DownloadEngine actually apply.
    DownloadEngine.fileQueue.add(platform);
  }

  void pause(String id) {
    final t = _tasks[id];
    final platform = t?.platformTask;
    if (t == null || platform == null) return;
    unawaited(bd.FileDownloader().pause(platform));
    // Optimistic: the authoritative state still arrives on the update stream.
    if (t.status == DownloadStatus.downloading) {
      t.status = DownloadStatus.paused;
      _notify();
    }
  }

  void resume(String id) {
    final t = _tasks[id];
    final platform = t?.platformTask;
    if (t == null || platform == null) return;
    if (t.status == DownloadStatus.paused) {
      unawaited(() async {
        // A paused task can only truly resume while the platform still holds
        // its partial file; if it cannot, re-queue it from scratch rather
        // than leaving the user with a dead button.
        final ok = await bd.FileDownloader().resume(platform);
        if (!ok) DownloadEngine.fileQueue.add(platform);
      }());
    } else if (t.status == DownloadStatus.failed ||
        t.status == DownloadStatus.canceled ||
        t.status == DownloadStatus.queued) {
      DownloadEngine.fileQueue.add(platform);
    }
    t.status = DownloadStatus.queued;
    _notify();
  }

  void cancel(String id) {
    final t = _tasks[id];
    final platform = t?.platformTask;
    if (t == null) return;
    if (platform != null) {
      DownloadEngine.fileQueue.removeTasksWithIds([platform.taskId]);
      unawaited(bd.FileDownloader().cancelTaskWithId(platform.taskId));
    }
    if (t.status == DownloadStatus.downloading ||
        t.status == DownloadStatus.queued ||
        t.status == DownloadStatus.paused) {
      t.status = DownloadStatus.canceled;
    }
    _notify();
  }

  /// Attempts to resume all paused or failed downloads, clearing any error state.
  /// Also picks up tasks from `background_downloader`'s own database.
  Future<void> resumeAll() async {
    await _ensureWired();
    // 1. Ask the plugin to resume everything it knows about.
    await bd.FileDownloader().resumeFromBackground();
    // 2. Retry our local tasks that failed or paused.
    for (final task in _tasks.values) {
      if (task.status == DownloadStatus.paused || task.status == DownloadStatus.failed) {
        if (task.platformTask != null) {
          task.error = null;
          task.status = DownloadStatus.queued;
          bd.FileDownloader().resume(task.platformTask!);
        } else {
          // If no platform task exists, restart it entirely
          enqueue(
            id: task.id,
            url: task.url,
            category: task.category,
            fileName: task.fileName,
            unzipToDatabases: task.unzipToDatabases,
            dbVersion: task.dbVersion,
            title: task.title,
          );
        }
      }
    }
    _notify();
  }

  Future<void> remove(String id) async {
    cancel(id);
    final t = _tasks.remove(id);
    if (t?.platformTask != null) {
      _byPlatformId.remove(t!.platformTask!.taskId);
    }

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
    // still reads as "downloaded" on the next launch.
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

  void dispose() {
    _updates?.cancel();
    _controller.close();
  }

  void _notify() {
    if (!_controller.isClosed) _controller.add(tasks);
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
