import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/services/download_engine.dart';
import 'mp3quran_api.dart';

enum SurahAudioState { none, queued, running, done, failed }

class SurahAudioStatus {
  final SurahAudioState state;

  /// 0..1 while running; the platform's own figure, not a byte count guessed
  /// in Dart.
  final double progress;
  const SurahAudioStatus(this.state, [this.progress = 0]);

  static const none = SurahAudioStatus(SurahAudioState.none);
  static const done = SurahAudioStatus(SurahAudioState.done, 1);

  bool get isActive =>
      state == SurahAudioState.queued || state == SurahAudioState.running;
}

/// One recitation on the device — a folder under its reciter, holding one
/// file per surah: `quran_audio/<moshafId>/NNN.mp3`.
class LibraryEntry {
  final int reciterId;
  final String reciterName;
  final Mp3Moshaf moshaf;

  /// Surahs asked for and not on disk yet. Written to `library.json`, so a
  /// download the process died in the middle of is resumed, not forgotten.
  final Set<int> pending;
  bool paused;

  LibraryEntry({
    required this.reciterId,
    required this.reciterName,
    required this.moshaf,
    Set<int>? pending,
    this.paused = false,
  }) : pending = pending ?? <int>{};

  int get moshafId => moshaf.id;

  Map<String, dynamic> toJson() => {
        'reciter_id': reciterId,
        'reciter_name': reciterName,
        'moshaf': moshaf.toJson(),
        'pending': pending.toList()..sort(),
        'paused': paused,
      };

  factory LibraryEntry.fromJson(Map<String, dynamic> j) => LibraryEntry(
        reciterId: (j['reciter_id'] as num).toInt(),
        reciterName: j['reciter_name'] as String? ?? '',
        moshaf: Mp3Moshaf.fromJson(j['moshaf'] as Map<String, dynamic>),
        pending: {
          for (final s in (j['pending'] as List<dynamic>? ?? const []))
            (s as num).toInt(),
        },
        paused: j['paused'] as bool? ?? false,
      );
}

/// «خلّي التلاوات اللي تتحمّل تبقى تلاوات كاملة وتشتغل على البلاير وتبقى
/// إندكسد وفولدرات».
///
/// Whole-surah files from mp3quran.net, downloaded through the platform's own
/// downloader (`DownloadEngine.quranAudioQueue`), so a transfer keeps going
/// with the app in the background and a 255 MB surah is one task rather than
/// 286 ayah files. Nothing here is tied to a mushaf.
///
/// What is on disk is read from the disk: a file exists at its final path only
/// once the platform has finished it (it writes to a temporary file and moves
/// it on completion), so "downloaded" is never a flag that can disagree with
/// the folder.
class QuranAudioLibrary extends ChangeNotifier {
  QuranAudioLibrary._();
  static final QuranAudioLibrary instance = QuranAudioLibrary._();

  static const _dirName = 'quran_audio';
  static const _audioExtensions = {'.mp3', '.m4a', '.aac', '.ogg', '.opus', '.wav', '.flac'};

  late Directory _root;
  final Map<int, LibraryEntry> _entries = {};
  final Map<int, Set<int>> _onDisk = {};
  final Map<String, SurahAudioStatus> _status = {};
  Future<void>? _ready;
  StreamSubscription<TaskUpdate>? _sub;
  Timer? _notifyTimer;

  static String _key(int moshafId, int surah) => '$moshafId/$surah';
  static String taskIdFor(int moshafId, int surah) => 'qa_${moshafId}_$surah';
  static String fileNameFor(int surah) =>
      '${surah.toString().padLeft(3, '0')}.mp3';

  static (int, int)? _parseTaskId(String id) {
    final parts = id.split('_');
    if (parts.length != 3 || parts[0] != 'qa') return null;
    final m = int.tryParse(parts[1]);
    final s = int.tryParse(parts[2]);
    return (m == null || s == null) ? null : (m, s);
  }

  Future<void> ensureReady() => _ready ??= _load();

  Future<void> _load() async {
    final base = await getApplicationDocumentsDirectory();
    _root = Directory(p.join(base.path, _dirName));
    if (!_root.existsSync()) await _root.create(recursive: true);
    final index = File(p.join(_root.path, 'library.json'));
    if (index.existsSync()) {
      try {
        for (final e in jsonDecode(await index.readAsString()) as List<dynamic>) {
          final entry = LibraryEntry.fromJson(e as Map<String, dynamic>);
          _entries[entry.moshafId] = entry;
        }
      } catch (_) {
        // A damaged index loses the bookkeeping, not the files.
      }
    }
    for (final id in _entries.keys) {
      _scan(id);
    }
    await DownloadEngine.ensureInitialized(askForNotifications: false);
    _sub ??= DownloadEngine.updates.listen(_onUpdate);
    notifyListeners();
    unawaited(repair());
  }

  void _scan(int moshafId) {
    final dir = Directory(p.join(_root.path, '$moshafId'));
    final found = <int>{};
    if (dir.existsSync()) {
      for (final f in dir.listSync()) {
        if (f is! File || !f.path.endsWith('.mp3')) continue;
        final n = int.tryParse(p.basenameWithoutExtension(f.path));
        if (n != null && f.lengthSync() > 0) found.add(n);
      }
    }
    _onDisk[moshafId] = found;
  }

  Future<void> _save() async {
    final index = File(p.join(_root.path, 'library.json'));
    await index.writeAsString(
      jsonEncode([for (final e in _entries.values) e.toJson()]),
      flush: true,
    );
  }

  // ── Reading ──────────────────────────────────────────────────────────────

  /// Recitations with something on the device or on the way, grouped the way
  /// they are shown: by reciter, then by recitation.
  List<LibraryEntry> get entries => _entries.values
      .where((e) => downloadedCount(e.moshafId) > 0 || e.pending.isNotEmpty)
      .toList()
    ..sort((a, b) {
      final r = a.reciterName.compareTo(b.reciterName);
      return r != 0 ? r : a.moshaf.name.compareTo(b.moshaf.name);
    });

  LibraryEntry? entry(int moshafId) => _entries[moshafId];

  int downloadedCount(int moshafId) => _onDisk[moshafId]?.length ?? 0;

  bool isDownloaded(int moshafId, int surah) =>
      _onDisk[moshafId]?.contains(surah) ?? false;

  File fileFor(int moshafId, int surah) =>
      File(p.join(_root.path, '$moshafId', fileNameFor(surah)));

  SurahAudioStatus statusOf(int moshafId, int surah) =>
      isDownloaded(moshafId, surah)
          ? SurahAudioStatus.done
          : _status[_key(moshafId, surah)] ?? SurahAudioStatus.none;

  /// Bytes on disk and the number of things holding them (recitations with
  /// files, plus imported files), for the storage screen.
  Future<(int, int)> usage() async {
    await ensureReady();
    var bytes = 0;
    for (final f in _root.listSync(recursive: true)) {
      if (f is File && !f.path.contains('${p.separator}cache${p.separator}')) {
        bytes += f.lengthSync();
      }
    }
    final items = _entries.keys.where((id) => downloadedCount(id) > 0).length +
        (await localFiles()).length;
    return (bytes, items);
  }

  // ── Downloading ──────────────────────────────────────────────────────────

  /// Queues every surah of [moshaf] that is not on the device, or only
  /// [only]. Returns how many were queued.
  Future<int> download(
    Mp3Reciter reciter,
    Mp3Moshaf moshaf, {
    Iterable<int>? only,
  }) async {
    await ensureReady();
    final e = _entries.putIfAbsent(
      moshaf.id,
      () => LibraryEntry(
        reciterId: reciter.id,
        reciterName: reciter.name,
        moshaf: moshaf,
      ),
    );
    e.paused = false;
    final want = [
      for (final s in only ?? moshaf.surahs)
        if (moshaf.surahs.contains(s) && !isDownloaded(moshaf.id, s)) s,
    ];
    e.pending.addAll(want);
    await _save();
    unawaited(DownloadEngine.ensureNotificationPermission());
    for (final s in want) {
      _enqueue(e, s);
    }
    _notifyNow();
    return want.length;
  }

  void _enqueue(LibraryEntry e, int surah) {
    final key = _key(e.moshafId, surah);
    if (_status[key]?.isActive ?? false) return;
    _status[key] = const SurahAudioStatus(SurahAudioState.queued);
    DownloadEngine.quranAudioQueue.add(
      DownloadTask(
        taskId: taskIdFor(e.moshafId, surah),
        url: e.moshaf.urlFor(surah),
        filename: fileNameFor(surah),
        baseDirectory: BaseDirectory.applicationDocuments,
        directory: '$_dirName/${e.moshafId}',
        group: DownloadEngine.groupQuranAudio,
        updates: Updates.statusAndProgress,
        retries: 3,
        displayName: e.reciterName,
        metaData: '$surah',
      ),
    );
  }

  void _onUpdate(TaskUpdate u) {
    if (u.task.group != DownloadEngine.groupQuranAudio) return;
    final id = _parseTaskId(u.task.taskId);
    if (id == null) return;
    final (m, s) = id;
    final key = _key(m, s);
    if (u is TaskStatusUpdate) {
      final status = u.status;
      if (status == TaskStatus.complete) {
        (_onDisk[m] ??= <int>{}).add(s);
        _status.remove(key);
        final e = _entries[m];
        if (e != null && e.pending.remove(s)) unawaited(_save());
      } else if (status == TaskStatus.enqueued ||
          status == TaskStatus.running ||
          status == TaskStatus.waitingToRetry) {
        _status[key] = SurahAudioStatus(
            SurahAudioState.running, _status[key]?.progress ?? 0);
      } else if (status == TaskStatus.failed || status == TaskStatus.notFound) {
        _status[key] = const SurahAudioStatus(SurahAudioState.failed);
      } else {
        // canceled / paused: back to "not downloaded"; still pending if it
        // was a pause of the whole recitation, which [resume] picks up.
        _status.remove(key);
      }
      _notifyNow();
    } else if (u is TaskProgressUpdate) {
      if (u.progress >= 0 && u.progress <= 1) {
        _status[key] = SurahAudioStatus(SurahAudioState.running, u.progress);
        _notifySoon();
      }
    }
  }

  /// Stops a recitation's download and keeps what finished. A surah that was
  /// half-way starts again on [resume] — it is one file, and a clean restart
  /// cannot leave a queue slot held by a paused transfer.
  Future<void> pause(int moshafId) async {
    final e = _entries[moshafId];
    if (e == null) return;
    e.paused = true;
    await _save();
    await _stopTasks(moshafId, e.pending);
    _notifyNow();
  }

  Future<void> resume(int moshafId) async {
    final e = _entries[moshafId];
    if (e == null) return;
    e.paused = false;
    e.pending.removeWhere((s) => isDownloaded(moshafId, s));
    await _save();
    for (final s in e.pending) {
      _enqueue(e, s);
    }
    _notifyNow();
  }

  Future<void> cancel(int moshafId) async {
    final e = _entries[moshafId];
    if (e == null) return;
    final stopping = Set<int>.of(e.pending);
    e.pending.clear();
    e.paused = false;
    await _save();
    await _stopTasks(moshafId, stopping);
    _notifyNow();
  }

  Future<void> cancelSurah(int moshafId, int surah) async {
    final e = _entries[moshafId];
    e?.pending.remove(surah);
    if (e != null) await _save();
    await _stopTasks(moshafId, {surah});
    _notifyNow();
  }

  Future<void> _stopTasks(int moshafId, Set<int> surahs) async {
    final ids = [for (final s in surahs) taskIdFor(moshafId, s)];
    DownloadEngine.quranAudioQueue.removeTasksWithIds(ids);
    try {
      await FileDownloader().cancelTasksWithIds(ids);
    } catch (_) {}
    for (final s in surahs) {
      _status.remove(_key(moshafId, s));
    }
  }

  /// Re-queues every surah that was asked for, is not on disk, and that
  /// neither the platform nor the queue is working on. Returns how many.
  Future<int> repair() async {
    await ensureReady();
    final live = <String>{};
    try {
      live.addAll((await FileDownloader()
              .allTasks(group: DownloadEngine.groupQuranAudio))
          .map((t) => t.taskId));
    } catch (_) {}
    final queue = DownloadEngine.quranAudioQueue;
    live
      ..addAll(queue.enqueued.map((t) => t.taskId))
      ..addAll(queue.waiting.unorderedElements.map((t) => t.taskId));
    var count = 0;
    for (final e in _entries.values) {
      if (e.paused) continue;
      e.pending.removeWhere((s) => isDownloaded(e.moshafId, s));
      for (final s in e.pending) {
        if (live.contains(taskIdFor(e.moshafId, s))) continue;
        _status.remove(_key(e.moshafId, s));
        _enqueue(e, s);
        count++;
      }
    }
    await _save();
    _notifyNow();
    return count;
  }

  Future<void> deleteRecitation(int moshafId) async {
    await cancel(moshafId);
    final dir = Directory(p.join(_root.path, '$moshafId'));
    if (dir.existsSync()) await dir.delete(recursive: true);
    _onDisk.remove(moshafId);
    _entries.remove(moshafId);
    await _save();
    _notifyNow();
  }

  Future<void> deleteSurah(int moshafId, int surah) async {
    final f = fileFor(moshafId, surah);
    if (f.existsSync()) await f.delete();
    _onDisk[moshafId]?.remove(surah);
    _notifyNow();
  }

  /// Everything this section holds — recitations and imported files.
  Future<void> freeAll() async {
    await ensureReady();
    for (final id in _entries.keys.toList()) {
      await deleteRecitation(id);
    }
    final local = Directory(p.join(_root.path, 'local'));
    if (local.existsSync()) await local.delete(recursive: true);
    _notifyNow();
  }

  // ── Files from the device ────────────────────────────────────────────────

  Directory get _localDir => Directory(p.join(_root.path, 'local'));

  Future<List<File>> localFiles() async {
    await ensureReady();
    if (!_localDir.existsSync()) return const [];
    return _localDir
        .listSync()
        .whereType<File>()
        .where((f) =>
            _audioExtensions.contains(p.extension(f.path).toLowerCase()))
        .toList()
      ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
  }

  /// Copies picked files into the library. A file the picker already copied
  /// into this app's cache is moved instead of copied twice; anything else is
  /// copied, so a file in his own storage is never moved out of it.
  Future<int> importFiles(Iterable<String> paths) async {
    await ensureReady();
    if (!_localDir.existsSync()) await _localDir.create(recursive: true);
    final cache = (await getTemporaryDirectory()).path;
    var count = 0;
    for (final path in paths) {
      final src = File(path);
      if (!src.existsSync()) continue;
      final stem = p.basenameWithoutExtension(path);
      final ext = p.extension(path);
      var dest = File(p.join(_localDir.path, '$stem$ext'));
      for (var i = 2; dest.existsSync(); i++) {
        dest = File(p.join(_localDir.path, '$stem ($i)$ext'));
      }
      try {
        if (p.isWithin(cache, path)) {
          await src.rename(dest.path);
        } else {
          await src.copy(dest.path);
        }
        count++;
      } catch (_) {
        try {
          await src.copy(dest.path);
          count++;
        } catch (_) {}
      }
    }
    _notifyNow();
    return count;
  }

  Future<void> deleteLocal(File f) async {
    if (f.existsSync()) await f.delete();
    _notifyNow();
  }

  // ── Notifying ────────────────────────────────────────────────────────────

  void _notifyNow() {
    _notifyTimer?.cancel();
    _notifyTimer = null;
    notifyListeners();
  }

  /// Progress arrives many times a second per file; a quarter-second is
  /// enough for a bar to move smoothly without rebuilding a 114-row list on
  /// every chunk.
  void _notifySoon() {
    _notifyTimer ??= Timer(const Duration(milliseconds: 250), () {
      _notifyTimer = null;
      notifyListeners();
    });
  }
}
