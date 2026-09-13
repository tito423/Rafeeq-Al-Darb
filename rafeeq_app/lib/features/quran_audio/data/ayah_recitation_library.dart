import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/download_engine.dart';
import '../../../core/services/recitation_source.dart';

/// Progress snapshot for one reciter's per-ayah download.
class AyahDlProgress {
  final int downloaded;
  final int total;
  final bool paused;

  const AyahDlProgress({
    this.downloaded = 0,
    this.total = 6236,
    this.paused = false,
  });

  double get fraction =>
      total <= 0 ? 0 : (downloaded / total).clamp(0.0, 1.0);
  bool get isComplete => downloaded >= total && total > 0;
}

/// One reciter whose ayahs are being (or have been) downloaded.
class AyahDlEntry {
  final String edition;

  /// everyayah folder for this reciter.
  final String folder;

  /// Surahs still to go. Serialised so a session that dies mid-download can
  /// resume exactly where it left off.
  final Set<int> pendingSurahs;
  bool paused;

  AyahDlEntry({
    required this.edition,
    required this.folder,
    Set<int>? pendingSurahs,
    this.paused = false,
  }) : pendingSurahs = pendingSurahs ?? <int>{};

  Map<String, dynamic> toJson() => {
        'edition': edition,
        'folder': folder,
        'pending_surahs': pendingSurahs.toList()..sort(),
        'paused': paused,
      };

  factory AyahDlEntry.fromJson(Map<String, dynamic> j) => AyahDlEntry(
        edition: j['edition'] as String,
        folder: j['folder'] as String,
        pendingSurahs: {
          for (final s in (j['pending_surahs'] as List<dynamic>? ?? const []))
            (s as num).toInt(),
        },
        paused: j['paused'] as bool? ?? false,
      );
}

/// Per-ayah recitation downloads — the rebuilt version of the feature that
/// was removed in 3.17.0 for crashing.
///
/// Built on `background_downloader` through [DownloadEngine.fileQueue], so
/// transfers survive the app being backgrounded or killed. Each ayah is one
/// file under `ayah_recitations/<edition>/SSSAAA.mp3` in the documents dir.
///
/// Only reciters in [RecitationSource._everyAyahFolders] are offered,
/// because everyayah.com is the only host that was verified to answer Range
/// requests (HTTP 206, confirmed live) — which is what makes a dropped
/// connection resume from its bytes instead of restarting.
class AyahRecitationLibrary extends ChangeNotifier {
  AyahRecitationLibrary._();
  static final AyahRecitationLibrary instance = AyahRecitationLibrary._();

  static const _dirName = 'ayah_recitations';

  /// The number of ayahs in each surah (1-indexed: index 0 is unused).
  /// From the standard Hafs mushaf.
  static const List<int> _ayahCounts = [
    0, // placeholder for 1-indexing
    7, 286, 200, 176, 120, 165, 206, 75, 129, 109,
    123, 111, 43, 52, 99, 128, 111, 110, 98, 135,
    112, 78, 118, 64, 77, 227, 93, 88, 69, 60,
    34, 30, 73, 54, 45, 83, 182, 88, 75, 85,
    54, 53, 89, 59, 37, 35, 38, 29, 18, 45,
    60, 49, 62, 55, 78, 96, 29, 22, 24, 13,
    14, 11, 11, 18, 12, 12, 30, 52, 52, 44,
    28, 28, 20, 56, 40, 31, 50, 40, 46, 42,
    29, 19, 36, 25, 22, 17, 19, 26, 30, 20,
    15, 21, 11, 8, 8, 19, 5, 8, 8, 11,
    11, 8, 3, 9, 5, 4, 7, 6, 3, 6,
    4, 5, 6, 8, 4, // surahs 110-114
  ];

  /// Total ayahs in the Quran.
  static const int totalAyahs = 6236;

  late Directory _root;
  final Map<String, AyahDlEntry> _entries = {};

  /// edition -> set of (surah, ayah) pairs on disk, cached from scanning.
  final Map<String, int> _downloadedCounts = {};

  StreamSubscription<TaskUpdate>? _sub;
  Future<void>? _ready;
  Timer? _notifyTimer;

  Future<void> ensureReady() => _ready ??= _load();

  Future<void> _load() async {
    final base = await getApplicationDocumentsDirectory();
    _root = Directory(p.join(base.path, _dirName));
    if (!_root.existsSync()) await _root.create(recursive: true);
    final index = File(p.join(_root.path, 'library.json'));
    if (index.existsSync()) {
      try {
        for (final e
            in jsonDecode(await index.readAsString()) as List<dynamic>) {
          final entry = AyahDlEntry.fromJson(e as Map<String, dynamic>);
          _entries[entry.edition] = entry;
        }
      } catch (_) {}
    }
    for (final edition in _entries.keys) {
      _countDownloaded(edition);
    }
    await DownloadEngine.ensureInitialized(askForNotifications: false);
    _sub ??= DownloadEngine.updates.listen(_onUpdate);
    notifyListeners();
    unawaited(repair());
  }

  void _countDownloaded(String edition) {
    final dir = Directory(p.join(_root.path, edition));
    var count = 0;
    if (dir.existsSync()) {
      for (final f in dir.listSync()) {
        if (f is! File || !f.path.endsWith('.mp3')) continue;
        if (f.lengthSync() > 0) count++;
      }
    }
    _downloadedCounts[edition] = count;
  }

  Future<void> _save() async {
    final index = File(p.join(_root.path, 'library.json'));
    await index.writeAsString(
      jsonEncode([for (final e in _entries.values) e.toJson()]),
      flush: true,
    );
  }

  // ── Reading ──────────────────────────────────────────────────────────────

  /// All reciters with something downloaded or in progress.
  List<AyahDlEntry> get entries => _entries.values.toList();

  int downloadedCount(String edition) => _downloadedCounts[edition] ?? 0;

  AyahDlProgress progressOf(String edition) {
    final entry = _entries[edition];
    return AyahDlProgress(
      downloaded: downloadedCount(edition),
      total: totalAyahs,
      paused: entry?.paused ?? false,
    );
  }

  bool isDownloaded(String edition, int surah, int ayah) {
    final f = fileFor(edition, surah, ayah);
    return f.existsSync() && f.lengthSync() > 0;
  }

  File fileFor(String edition, int surah, int ayah) => File(p.join(
        _root.path,
        edition,
        _fileName(surah, ayah),
      ));

  static String _fileName(int surah, int ayah) =>
      '${surah.toString().padLeft(3, '0')}'
      '${ayah.toString().padLeft(3, '0')}.mp3';

  static String _taskId(String edition, int surah, int ayah) =>
      'ayah_${edition}_${surah}_$ayah';

  static (String, int, int)? _parseTaskId(String id) {
    if (!id.startsWith('ayah_')) return null;
    final rest = id.substring(5);
    // edition is like 'ar.alafasy', so split from the end
    final lastUnderscore = rest.lastIndexOf('_');
    if (lastUnderscore < 0) return null;
    final ayahStr = rest.substring(lastUnderscore + 1);
    final beforeAyah = rest.substring(0, lastUnderscore);
    final secondLastUnderscore = beforeAyah.lastIndexOf('_');
    if (secondLastUnderscore < 0) return null;
    final surahStr = beforeAyah.substring(secondLastUnderscore + 1);
    final edition = beforeAyah.substring(0, secondLastUnderscore);
    final surah = int.tryParse(surahStr);
    final ayah = int.tryParse(ayahStr);
    if (surah == null || ayah == null || edition.isEmpty) return null;
    return (edition, surah, ayah);
  }

  /// Editions with verified everyayah mirrors — the only ones this library
  /// can download. The list is [RecitationSource]'s, not duplicated.
  static List<String> get availableEditions {
    final out = <String>[];
    // Walk through the editions that have verified mirrors.
    for (final edition in [
      'ar.abdulbasitmurattal',
      'ar.abdullahbasfar',
      'ar.abdurrahmaansudais',
      'ar.shaatree',
      'ar.ahmedajamy',
      'ar.alafasy',
      'ar.faresabbad',
      'ar.hanirifai',
      'ar.hudhaify',
      'ar.husary',
      'ar.husarymujawwad',
      'ar.mahermuaiqly',
      'ar.minshawi',
      'ar.minshawimujawwad',
      'ar.mohamedtablawi',
      'ar.muhammadayyoub',
      'ar.muhammadjibreel',
      'ar.nasseralqatami',
      'ar.saoodshuraym',
    ]) {
      if (RecitationSource.hasVerifiedMirror(edition)) out.add(edition);
    }
    return out;
  }

  // ── Downloading ──────────────────────────────────────────────────────────

  /// Downloads every ayah for [edition] that is not already on disk.
  Future<int> downloadReciter(String edition) async {
    await ensureReady();
    final folder = RecitationSource.folderFor(edition);
    if (folder == null) return 0;

    final entry = _entries.putIfAbsent(
      edition,
      () => AyahDlEntry(edition: edition, folder: folder),
    );
    entry.paused = false;

    var queued = 0;
    for (var s = 1; s <= 114; s++) {
      final count = _ayahCounts[s];
      for (var a = 1; a <= count; a++) {
        if (isDownloaded(edition, s, a)) continue;
        entry.pendingSurahs.add(s);
        _enqueueAyah(entry, s, a);
        queued++;
      }
    }
    await _save();
    if (queued > 0) unawaited(DownloadEngine.ensureNotificationPermission());
    _notifyNow();
    return queued;
  }

  /// Downloads every ayah of one surah for [edition].
  Future<int> downloadSurah(String edition, int surahId) async {
    await ensureReady();
    final folder = RecitationSource.folderFor(edition);
    if (folder == null) return 0;
    if (surahId < 1 || surahId > 114) return 0;

    final entry = _entries.putIfAbsent(
      edition,
      () => AyahDlEntry(edition: edition, folder: folder),
    );
    entry.paused = false;

    final count = _ayahCounts[surahId];
    var queued = 0;
    for (var a = 1; a <= count; a++) {
      if (isDownloaded(edition, surahId, a)) continue;
      entry.pendingSurahs.add(surahId);
      _enqueueAyah(entry, surahId, a);
      queued++;
    }
    await _save();
    if (queued > 0) unawaited(DownloadEngine.ensureNotificationPermission());
    _notifyNow();
    return queued;
  }

  void _enqueueAyah(AyahDlEntry entry, int surah, int ayah) {
    final url = AppConfig.everyAyahUrl(entry.folder, surah, ayah);
    final dir = p.join(_dirName, entry.edition);

    DownloadEngine.fileQueue.add(DownloadTask(
      taskId: _taskId(entry.edition, surah, ayah),
      url: url,
      filename: _fileName(surah, ayah),
      baseDirectory: BaseDirectory.applicationDocuments,
      directory: dir,
      group: DownloadEngine.groupFiles,
      updates: Updates.statusAndProgress,
      retries: 3,
      allowPause: true,
    ));
  }

  void _onUpdate(TaskUpdate u) {
    if (u.task.group != DownloadEngine.groupFiles) return;
    final parsed = _parseTaskId(u.task.taskId);
    if (parsed == null) return;
    final (edition, surah, _) = parsed;

    if (u is TaskStatusUpdate && u.status == TaskStatus.complete) {
      final prev = _downloadedCounts[edition] ?? 0;
      _downloadedCounts[edition] = prev + 1;
      // Check if the whole surah is now done.
      final count = _ayahCounts[surah];
      var surahDone = true;
      for (var a = 1; a <= count; a++) {
        if (!isDownloaded(edition, surah, a)) {
          surahDone = false;
          break;
        }
      }
      if (surahDone) {
        final entry = _entries[edition];
        if (entry != null && entry.pendingSurahs.remove(surah)) {
          unawaited(_save());
        }
      }
      _notifyNow();
    } else if (u is TaskProgressUpdate) {
      // Throttled: progress arrives many times a second per file.
      _notifySoon();
    }
  }

  Future<void> pause(String edition) async {
    final entry = _entries[edition];
    if (entry == null) return;
    entry.paused = true;
    await _save();
    // Cancel all pending tasks for this edition.
    final ids = <String>[];
    for (var s = 1; s <= 114; s++) {
      final count = _ayahCounts[s];
      for (var a = 1; a <= count; a++) {
        ids.add(_taskId(edition, s, a));
      }
    }
    try {
      await FileDownloader().cancelTasksWithIds(ids);
    } catch (_) {}
    _notifyNow();
  }

  Future<void> resume(String edition) async {
    final entry = _entries[edition];
    if (entry == null) return;
    entry.paused = false;
    await _save();
    // Re-queue all pending surahs.
    for (final s in entry.pendingSurahs.toList()) {
      final count = _ayahCounts[s];
      for (var a = 1; a <= count; a++) {
        if (!isDownloaded(edition, s, a)) {
          _enqueueAyah(entry, s, a);
        }
      }
    }
    _notifyNow();
  }

  Future<void> cancel(String edition) async {
    final entry = _entries[edition];
    if (entry == null) return;
    entry.pendingSurahs.clear();
    entry.paused = false;
    await _save();
    // Cancel all running tasks.
    final ids = <String>[];
    for (var s = 1; s <= 114; s++) {
      final count = _ayahCounts[s];
      for (var a = 1; a <= count; a++) {
        ids.add(_taskId(edition, s, a));
      }
    }
    try {
      await FileDownloader().cancelTasksWithIds(ids);
    } catch (_) {}
    _notifyNow();
  }

  /// Delete all downloaded ayahs for [edition].
  Future<void> deleteReciter(String edition) async {
    await cancel(edition);
    final dir = Directory(p.join(_root.path, edition));
    if (dir.existsSync()) await dir.delete(recursive: true);
    _downloadedCounts.remove(edition);
    _entries.remove(edition);
    await _save();
    _notifyNow();
  }

  /// Re-queues anything that was asked for, isn't on disk, and isn't running.
  Future<int> repair() async {
    await ensureReady();
    final live = <String>{};
    try {
      live.addAll(
        (await FileDownloader().allTasks(group: DownloadEngine.groupFiles))
            .map((t) => t.taskId),
      );
    } catch (_) {}
    var count = 0;
    for (final entry in _entries.values) {
      if (entry.paused) continue;
      for (final s in entry.pendingSurahs.toList()) {
        final ayahCount = _ayahCounts[s];
        for (var a = 1; a <= ayahCount; a++) {
          if (isDownloaded(entry.edition, s, a)) continue;
          if (live.contains(_taskId(entry.edition, s, a))) continue;
          _enqueueAyah(entry, s, a);
          count++;
        }
      }
    }
    _notifyNow();
    return count;
  }

  /// Bytes on disk and the number of reciters with files, for the storage hub.
  Future<(int, int)> usage() async {
    await ensureReady();
    var bytes = 0;
    var items = 0;
    for (final edition in _entries.keys) {
      final dir = Directory(p.join(_root.path, edition));
      if (!dir.existsSync()) continue;
      var has = false;
      for (final f in dir.listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.mp3')) continue;
        bytes += f.lengthSync();
        has = true;
      }
      if (has) items++;
    }
    return (bytes, items);
  }

  /// Delete everything.
  Future<void> freeAll() async {
    await ensureReady();
    for (final edition in _entries.keys.toList()) {
      await deleteReciter(edition);
    }
    _notifyNow();
  }

  // ── Notifying ────────────────────────────────────────────────────────────

  void _notifyNow() {
    _notifyTimer?.cancel();
    _notifyTimer = null;
    notifyListeners();
  }

  void _notifySoon() {
    _notifyTimer ??= Timer(const Duration(milliseconds: 250), () {
      _notifyTimer = null;
      notifyListeners();
    });
  }
}
