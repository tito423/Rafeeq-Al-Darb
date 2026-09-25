import 'dart:collection';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:just_audio_background/just_audio_background.dart' show MediaItem;

import '../../../core/config/app_config.dart';
import '../../../core/services/download_engine.dart';
import '../../../core/services/recitation_source.dart';
import '../../../core/services/ayah_audio_service.dart';

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
  /// From the standard Hafs mushaf — read out of the bundled
  /// `quran_local.db` (`SELECT surah_id, COUNT(*) FROM ayahs GROUP BY
  /// surah_id`), which agrees with its own `surahs.ayahs_count` and totals
  /// 6,236.
  ///
  /// The previous table was right to surah 107 and wrong after it —
  /// al-Kawthar 6, al-Kafirun 3, an-Nasr 6, al-Masad 4, al-Ikhlas 5,
  /// al-Falaq 6, an-Nas 8, plus a 115th entry. Every one showed on the
  /// owner's phone: the library asked everyayah for ayahs that do not
  /// exist (an-Nasr 4-6, an-Nas 7-8), those tasks could never succeed, so
  /// the reciter sat at 6,232 / 6,236 for ever and «إصلاح التحميلات»
  /// re-queued the same impossible files every time — while al-Kafirun
  /// counted as complete with half its ayahs missing.
  /// `test/ayah_counts_test.dart` pins every value.
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
    11, 8, 3, 9, 5, 4, 7, 3, 6, 3,
    5, 4, 5, 6, // surahs 111-114
  ];

  /// Total ayahs in the Quran.
  static const int totalAyahs = 6236;

  late Directory _root;
  final Map<String, AyahDlEntry> _entries = {};

  /// edition -> the ayahs on disk, as `surah * 1000 + ayah`. Filled by one
  /// directory listing per reciter and kept by the completion events, so
  /// every «is it here» and every count is a set lookup, never a file stat.
  ///
  /// It replaced a counter that did `prev + 1` on every completion: a
  /// duplicate completion (a retry, an origin re-fetch, a replay after a
  /// restart) counted twice, and the owner's phone read «1488 من 1485»
  /// (2026-09-25). A set cannot count an ayah twice or pass 6,236.
  final Map<String, Set<int>> _have = {};

  static int _key(int surah, int ayah) => surah * 1000 + ayah;

  /// Ayahs asked for and not yet handed to the downloader, in order.
  ///
  /// THE ANR. `downloadReciter` used to add all 6,236 tasks to the plugin's
  /// `MemoryTaskQueue`, whose `getNextTask` - once four transfers hold the
  /// host - pops EVERY waiting task, parses its URL for the host, and pushes
  /// it back: 7.7 ms per call with 6,236 waiting, measured on the desktop
  /// (2026-09-25), and it runs twice per finished ayah. The main thread sat
  /// at ~50 % on emulator-5554 from the tap on, and the owner's Xiaomi went
  /// «isn't responding» the moment he tapped «تلاوة آية بآية». The plugin
  /// now holds at most [_window] of ours; [_pump] feeds it.
  final ListQueue<(String, int, int, bool)> _backlog = ListQueue();
  final Set<String> _backlogIds = {};

  /// Task ids handed to the plugin's queue that it has not reported on yet.
  final Set<String> _handed = {};
  static const _window = 12;

  StreamSubscription<TaskUpdate>? _sub;
  Future<void>? _ready;
  Timer? _notifyTimer;

  Future<void> ensureReady() => _ready ??= _load();

  Future<void> _load() async {
    final base = await getApplicationDocumentsDirectory();
    _root = Directory(p.join(base.path, _dirName));
    if (!_root.existsSync()) await _root.create(recursive: true);
    _rootSet = true;
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
    for (final entry in _entries.values) {
      _countDownloaded(entry.edition);
      // A surah with some of its ayahs on disk and not all was asked for and
      // never finished — whatever the pending list says. Under the old count
      // table al-Kafirun «finished» at 3 of 6 and left the list, so nothing
      // would ever have fetched ayahs 4-6; this puts it back for repair().
      for (var s = 1; s <= 114; s++) {
        final have = surahDownloadedCount(entry.edition, s);
        if (have > 0 && have < ayahCount(s)) entry.pendingSurahs.add(s);
      }
    }
    await DownloadEngine.ensureInitialized(askForNotifications: false);
    _sub ??= DownloadEngine.updates.listen(_onUpdate);
    notifyListeners();
    unawaited(repair());
  }

  /// Counts the files that are real ayahs. A name the Hafs count has no
  /// ayah for (left by the old table, which asked for an-Nas 7 and 8) is
  /// not a download and must not push the total past what exists.
  void _countDownloaded(String edition) {
    final dir = Directory(p.join(_root.path, edition));
    final have = <int>{};
    if (dir.existsSync()) {
      for (final f in dir.listSync()) {
        if (f is! File || !f.path.endsWith('.mp3')) continue;
        final name = p.basenameWithoutExtension(f.path);
        final surah = int.tryParse(name.length == 6 ? name.substring(0, 3) : '');
        final ayah = int.tryParse(name.length == 6 ? name.substring(3) : '');
        if (surah == null || ayah == null || ayah < 1 || ayah > ayahCount(surah)) {
          continue;
        }
        if (f.lengthSync() > 0) have.add(_key(surah, ayah));
      }
    }
    _have[edition] = have;
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

  int downloadedCount(String edition) => _have[edition]?.length ?? 0;

  /// Ayahs in [surah] in the Hafs count (1-based), or 0 out of range.
  static int ayahCount(int surah) =>
      surah >= 1 && surah <= 114 ? _ayahCounts[surah] : 0;

  /// How many of [surah]'s ayahs are on disk for [edition]. Read from the
  /// folder, so it is true after a restart and after a partial download.
  int surahDownloadedCount(String edition, int surah) {
    if (!_rootSet) return 0;
    var n = 0;
    for (var a = 1; a <= ayahCount(surah); a++) {
      if (isDownloaded(edition, surah, a)) n++;
    }
    return n;
  }

  /// Ayahs whose transfer failed this session, per `edition/surah`.
  final Map<String, Set<int>> _failed = {};

  /// Whether [surah] is queued (asked for and not finished) for [edition]
  /// AND still has something in flight. A surah whose every missing ayah
  /// has failed is not "downloading" — it showed a spinner for ever — so it
  /// reads as not pending, and its download button comes back as a retry.
  bool isSurahPending(String edition, int surah) {
    if (!(_entries[edition]?.pendingSurahs.contains(surah) ?? false)) {
      return false;
    }
    final failed = _failed['$edition/$surah'];
    if (failed == null || failed.isEmpty) return true;
    for (var a = 1; a <= ayahCount(surah); a++) {
      if (!failed.contains(a) && !isDownloaded(edition, surah, a)) return true;
    }
    return false;
  }

  AyahDlProgress progressOf(String edition) {
    final entry = _entries[edition];
    return AyahDlProgress(
      downloaded: downloadedCount(edition),
      total: totalAyahs,
      paused: entry?.paused ?? false,
    );
  }

  bool isDownloaded(String edition, int surah, int ayah) =>
      _have[edition]?.contains(_key(surah, ayah)) ?? false;

  /// The downloaded file for one ayah, or null when it is not on disk — or
  /// when the library has not loaded yet.
  ///
  /// That second case is why this exists. [RecitationSource.urlsFor] asked
  /// [fileFor] on every single-ayah play, and [fileFor] reads the `late`
  /// [_root], which is set only by [ensureReady] — called by the downloads
  /// screens and nothing else. So until the reader had opened «تلاوات الآيات»
  /// in that process, every `AyahAudioService.play` threw a
  /// LateInitializationError that `play` swallowed, and the button did
  /// nothing: the Tajweed lessons' «استمع» was dead that way.
  File? localFile(String edition, int surah, int ayah) {
    if (_ready == null) unawaited(ensureReady());
    if (!_rootSet) return null;
    final f = fileFor(edition, surah, ayah);
    return f.existsSync() && f.lengthSync() > 0 ? f : null;
  }

  bool _rootSet = false;

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
    _pump();
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
    _pump();
    if (queued > 0) unawaited(DownloadEngine.ensureNotificationPermission());
    _notifyNow();
    return queued;
  }

  /// Asks for one ayah: it joins the backlog, and [_pump] hands it to the
  /// downloader when there is room. [origin] skips the app's own mirror and
  /// asks everyayah directly - the retry for an ayah the mirror failed to
  /// deliver - and goes to the front, so a retry is not 6,000 ayahs away.
  void _enqueueAyah(AyahDlEntry entry, int surah, int ayah,
      {bool origin = false}) {
    _failed['${entry.edition}/$surah']?.remove(ayah);
    final id = _taskId(entry.edition, surah, ayah);
    if (_handed.contains(id)) return;
    if (!_backlogIds.add(id)) {
      if (!origin) return;
      _backlog.removeWhere((w) => _taskId(w.$1, w.$2, w.$3) == id);
    }
    final want = (entry.edition, surah, ayah, origin);
    origin ? _backlog.addFirst(want) : _backlog.addLast(want);
  }

  /// Tops the plugin's queue up to [_window] of ours. Cheap: it stops at a
  /// full window, and skips what was paused, cancelled or has arrived.
  void _pump() {
    while (_backlog.isNotEmpty && _handed.length < _window) {
      final (edition, surah, ayah, origin) = _backlog.removeFirst();
      final id = _taskId(edition, surah, ayah);
      _backlogIds.remove(id);
      final entry = _entries[edition];
      if (entry == null ||
          entry.paused ||
          !entry.pendingSurahs.contains(surah) ||
          isDownloaded(edition, surah, ayah)) {
        continue;
      }
      final url = !origin && RecitationSource.isMirroredOnR2(entry.folder)
          ? AppConfig.r2AyahUrl(entry.folder, surah, ayah)
          : AppConfig.everyAyahUrl(entry.folder, surah, ayah);
      _handed.add(id);
      DownloadEngine.fileQueue.add(DownloadTask(
        taskId: id,
        url: url,
        filename: _fileName(surah, ayah),
        baseDirectory: BaseDirectory.applicationDocuments,
        directory: p.join(_dirName, edition),
        group: DownloadEngine.groupFiles,
        updates: Updates.statusAndProgress,
        retries: 3,
        allowPause: true,
      ));
    }
  }

  /// Forgets everything queued for [edition] that has not started: our
  /// backlog, and the few tasks still waiting in the plugin's own queue
  /// (`allTasks` does not list those, so a cancel alone left them to run).
  void _dropQueued(String edition) {
    final prefix = 'ayah_${edition}_';
    _backlog.removeWhere((w) => w.$1 == edition);
    _backlogIds.removeWhere((id) => id.startsWith(prefix));
    final waiting = [
      for (final id in _handed)
        if (id.startsWith(prefix)) id,
    ];
    if (waiting.isNotEmpty) {
      DownloadEngine.fileQueue.removeTasksWithIds(waiting);
      _handed.removeAll(waiting);
    }
  }

  void _onUpdate(TaskUpdate u) {
    if (u.task.group != DownloadEngine.groupFiles) return;
    final parsed = _parseTaskId(u.task.taskId);
    if (parsed == null) return;
    final (edition, surah, _) = parsed;
    // Any status means the plugin has taken it out of its waiting queue.
    if (u is TaskStatusUpdate && _handed.remove(u.task.taskId)) _pump();

    if (u is TaskStatusUpdate && u.status == TaskStatus.complete) {
      // A transfer that finishes after its reciter was deleted is not a
      // download any more: its file goes, and nothing is counted.
      if (!_entries.containsKey(edition)) {
        final f = fileFor(edition, surah, parsed.$3);
        if (f.existsSync()) unawaited(f.delete());
        return;
      }
      final f = fileFor(edition, surah, parsed.$3);
      if (f.existsSync() && f.lengthSync() > 0) {
        (_have[edition] ??= <int>{}).add(_key(surah, parsed.$3));
      }
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
    } else if (u is TaskStatusUpdate &&
        (u.status == TaskStatus.failed || u.status == TaskStatus.notFound)) {
      // The mirror is the primary, not the only source: an ayah it could not
      // deliver is asked of everyayah before it is counted as failed.
      final entry = _entries[edition];
      if (entry != null && AppConfig.isOwnMirror(u.task.url)) {
        _enqueueAyah(entry, surah, parsed.$3, origin: true);
        _pump();
        return;
      }
      (_failed['$edition/$surah'] ??= <int>{}).add(parsed.$3);
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
    _dropQueued(edition);
    await _save();
    _notifyNow();
    await _cancelLiveTasks(edition);
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
    _pump();
    _notifyNow();
  }

  Future<void> cancel(String edition) async {
    final entry = _entries[edition];
    if (entry == null) return;
    entry.pendingSurahs.clear();
    entry.paused = false;
    _dropQueued(edition);
    await _save();
    await _cancelLiveTasks(edition);
    _notifyNow();
  }

  /// Cancels the tasks the downloader actually holds for [edition] — a
  /// handful at most — instead of sending it all 6,236 possible ids, which
  /// is a single platform call large enough to stall the screen behind it.
  Future<void> _cancelLiveTasks(String edition) async {
    try {
      final prefix = 'ayah_${edition}_';
      final live = await FileDownloader()
          .allTasks(group: DownloadEngine.groupFiles)
          .timeout(const Duration(seconds: 10));
      final ids = [
        for (final t in live)
          if (t.taskId.startsWith(prefix)) t.taskId,
      ];
      if (ids.isNotEmpty) {
        await FileDownloader()
            .cancelTasksWithIds(ids)
            .timeout(const Duration(seconds: 10));
      }
    } catch (_) {}
  }

  /// Delete all downloaded ayahs for [edition].
  ///
  /// «حذف» on the owner's phone left the reciter at 100 % — the files went
  /// only after a cancel call that had to finish first, and that call
  /// carried every possible task id. The record and the files go first now,
  /// so the screen empties the moment he confirms; the queue is cleared
  /// after, and any ayah that still lands is deleted with the folder again.
  Future<void> deleteReciter(String edition) async {
    await ensureReady();
    // Deleting the voice being listened to stops it first: its next
    // verses point at files about to go (audit 2026-09-24).
    final audio = AyahAudioService.instance;
    if (audio.continuous.value.active &&
        audio.continuousEdition == edition) {
      await audio.stopContinuous();
    }
    // A queue or single ayah of this reciter too (the reciter screen's own
    // play button, the hifz loop): checking continuous recitation alone let
    // a queue play on after its files were deleted, streaming the rest from
    // the network (emulator-5554, 2026-09-24). Every ayah source is tagged
    // `edition:global` (AyahAudioService._tag).
    final tag = audio.player.sequenceState.currentSource?.tag;
    if (tag is MediaItem && tag.id.split(':').first == edition) {
      await audio.stopQueue();
    }
    _entries.remove(edition);
    _have.remove(edition);
    _dropQueued(edition);
    await _save();
    _notifyNow();
    final dir = Directory(p.join(_root.path, edition));
    if (dir.existsSync()) await dir.delete(recursive: true);
    await _cancelLiveTasks(edition);
    if (dir.existsSync()) await dir.delete(recursive: true);
    _have.remove(edition);
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
    // A task the plugin refused past its retries never reports a status, so
    // it would hold a place in the window for ever. Anything neither running
    // nor waiting in the plugin's queue is handed back to the backlog below.
    final waiting = {
      for (final t in DownloadEngine.fileQueue.waiting.unorderedElements)
        t.taskId,
    };
    _handed.removeWhere((id) => !live.contains(id) && !waiting.contains(id));
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
    _pump();
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
