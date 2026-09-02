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

  final Dio _dio = Dio();
  final Map<String, CancelToken> _tokens = {};
  final Map<String, DownloadTask> _tasks = {};
  final StreamController<List<DownloadTask>> _controller =
      StreamController<List<DownloadTask>>.broadcast();

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
      title: title,
    );
    _tasks[id] = task;
    _notify();
    await DownloadNotifications.instance.ensureInitialized();
    unawaited(_run(task));
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
      unawaited(_run(t));
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
    if (t != null) {
      final dir = await downloadDir;
      for (final name in [t.fileName, '${t.fileName}.part']) {
        final f = File(p.join(dir.path, name));
        if (f.existsSync()) await f.delete();
      }
    }
    _notify();
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
      await DownloadNotifications.instance.progress(task);

      final raf = await partial.open(mode: FileMode.append);
      try {
        await for (final chunk in response.data!.stream) {
          await raf.writeFrom(chunk);
          task.received += chunk.length;
          _notify();
          await DownloadNotifications.instance.progress(task);
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
      }

      task.status = DownloadStatus.completed;
      await _registerCompleted(task, registeredPath);
      await DownloadNotifications.instance.complete(task);
      _notify();
    } on DioException catch (e) {
      if (!CancelToken.isCancel(e)) {
        task.status = DownloadStatus.failed;
        // e.message is frequently null for connectionError/badCertificate
        // types — the real detail lives on e.error (the wrapped underlying
        // exception, e.g. a SocketException or HandshakeException). Falling
        // straight to the generic "network error" string hid that detail.
        task.error = e.message ?? e.error?.toString() ?? e.type.name;
        await DownloadNotifications.instance.failed(task);
      }
      _notify();
    } catch (e) {
      task.status = DownloadStatus.failed;
      task.error = e.toString();
      await DownloadNotifications.instance.failed(task);
      _notify();
    } finally {
      _tokens.remove(task.id);
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

  Future<void> progress(DownloadTask task) async {
    if (!_ready || !Platform.isAndroid) return;
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      final hasSize = task.total != null && task.total! > 0;
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
        progress: hasSize ? (task.progress * 100).round() : 0,
        indeterminate: !hasSize,
      );
      await plugin.show(
        _notificationId(task.id),
        task.title,
        hasSize ? '${(task.progress * 100).round()}%' : '${task.received} bytes',
        NotificationDetails(android: android),
      );
    } catch (_) {}
  }

  Future<void> complete(DownloadTask task) async {
    if (!_ready || !Platform.isAndroid) return;
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin.cancel(_notificationId(task.id));
      final android = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Offline content download progress',
        importance: Importance.low,
        priority: Priority.low,
      );
      await plugin.show(
        _notificationId(task.id) + 1000,
        task.title,
        'طھظ… ط§ظ„طھظ†ط²ظٹظ„ â€” ط¬ط§ظ‡ط² ظ„ظ„ط§ط³طھط®ط¯ط§ظ… ط¨ط¯ظˆظ† ط¥ظ†طھط±ظ†طھ',
        NotificationDetails(android: android),
      );
    } catch (_) {}
  }

  Future<void> failed(DownloadTask task) async {
    if (!_ready || !Platform.isAndroid) return;
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin.cancel(_notificationId(task.id));
    } catch (_) {}
  }
}
