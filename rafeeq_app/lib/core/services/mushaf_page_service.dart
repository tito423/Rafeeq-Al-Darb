import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';
import 'download_foreground_service.dart';
import 'download_manager.dart' show DownloadNotifications;

/// P3‑41: the owner asked directly for the default mushaf to be "built
/// in" — bundled inside the APK, not fetched over the network at all, the
/// same way `assets/data/hadith.db` now is. All 604 real pages for the
/// default edition ship as `assets/mushaf/<id>/NNN.svg`; other editions
/// (Shubah, Duri, Qalun, Warsh) are deliberately **not** bundled — the
/// owner only asked for "hafs madina", and bundling all five would be
/// ~5× the app size for editions most readers never switch to. Keying
/// this by edition id (not a single `bool`) means bundling a second
/// edition later is just adding its id here, no other code changes.
const _kBundledMushafEditions = {'hafs_kfqc'};

/// Live state of a whole-edition download. Lives on [MushafPageService] (not
/// on any widget) so a Downloads tile that is rebuilt — a tab switch, a list
/// recycle — can re-attach to a running job instead of losing it. This is the
/// root fix for the P2‑1.4 "download stops when you leave the Mushafs tab"
/// bug; P2‑5 folds it into a unified download manager.
class PrefetchProgress extends ChangeNotifier {
  int done = 0;
  int total = 0;
  bool running = false;
  bool paused = false;

  double get fraction => total == 0 ? 0 : done / total;

  void _set({int? done, int? total, bool? running, bool? paused}) {
    if (done != null) this.done = done;
    if (total != null) this.total = total;
    if (running != null) this.running = running;
    if (paused != null) this.paused = paused;
    notifyListeners();
  }
}

/// Fetches mushaf pages and keeps them on disk, so a page opened once stays
/// readable with no network (offline-first mushaf).
///
/// Pages are vector SVG, not raster scans: the whole 604-page mushaf is a few
/// tens of MB instead of hundreds, stays sharp at any zoom level, and carries
/// the ayah hit layer that [AyahCoordsRepository] was built from.
class MushafPageService {
  MushafPageService._();
  static final MushafPageService instance = MushafPageService._();

  // P3‑47: add a connectTimeout (the per-request receiveTimeout on
  // svgForPage was already set) so a stalled connection can't hang a page
  // fetch forever — same reasoning as ayah_audio_service.dart.
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
  ));
  /// Keyed `'<editionId>/<page>'` so switching edition cannot serve a
  /// cached page from the previous one.
  final Map<String, String> _memory = {};

  static const int firstPage = 1;
  static const int lastPage = 604;

  /// A page is only trusted when it is a complete XML document. A truncated
  /// download otherwise renders as a blank page with no error, and its ayah
  /// polygons silently disappear.
  static bool _isIntact(String svg) =>
      svg.length > 4096 && svg.trimRight().endsWith('</svg>');

  Future<Directory> _pageDir(String editionId) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'mushaf', editionId));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  File _fileFor(Directory dir, int page) =>
      File(p.join(dir.path, '${page.toString().padLeft(3, '0')}.svg'));

  /// Returns the SVG markup for [page] of [editionId], from memory, then disk,
  /// then network. Throws when the page is not cached and cannot be fetched.
  Future<String> svgForPage({
    required String editionId,
    required String sourcePath,
    required int page,
  }) async {
    final key = '$editionId/$page';
    final cached = _memory[key];
    if (cached != null) return cached;

    if (_kBundledMushafEditions.contains(editionId)) {
      try {
        final asset = await rootBundle.loadString(
          'assets/mushaf/$editionId/${page.toString().padLeft(3, '0')}.svg',
        );
        if (_isIntact(asset)) return _remember(key, asset);
      } catch (_) {
        // Asset missing for this page (shouldn't happen for a bundled
        // edition, but never let that crash the reader) — fall through
        // to the disk-cache/network path below exactly as if this
        // edition weren't bundled at all.
      }
    }

    final dir = await _pageDir(editionId);
    final file = _fileFor(dir, page);

    if (file.existsSync()) {
      final onDisk = await file.readAsString();
      if (_isIntact(onDisk)) return _remember(key, onDisk);
      await file.delete(); // partial write from an interrupted download
    }

    final res = await _dio.get<String>(
      AppConfig.mushafPageUrl(sourcePath, page),
      options: Options(
        responseType: ResponseType.plain,
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    final svg = res.data ?? '';
    if (!_isIntact(svg)) {
      throw StateError('Incomplete mushaf page $page (${svg.length} bytes)');
    }
    await file.writeAsString(svg, flush: true);
    return _remember(key, svg);
  }

  String _remember(String key, String svg) {
    // Small ring buffer: neighbouring pages stay hot while paging, without
    // holding all 604 pages (~350 MB uncompressed) in memory.
    if (_memory.length > 12) {
      _memory.remove(_memory.keys.first);
    }
    _memory[key] = svg;
    return svg;
  }

  /// Downloads a whole edition for offline reading.
  ///
  /// Pages already cached are skipped, so an interrupted download resumes
  /// where it stopped rather than starting over. Failures on individual pages
  /// are tolerated: the reader can still open everything that did arrive, and
  /// a later run fills the gaps.
  ///
  /// The job lives on this singleton, not on any widget, and its progress is
  /// published through [progressFor]. A Downloads tile that gets rebuilt
  /// (tab switch, list recycle — the P2‑1.4 bug) can therefore re-attach to a
  /// running download instead of losing it. P2‑5 folds this into a unified
  /// download manager.
  Future<void> prefetchEdition({
    required String editionId,
    required String sourcePath,
    int fromPage = firstPage,
    int toPage = lastPage,
    void Function(int done, int total)? onProgress,
    String? title,
  }) async {
    if (_prefetching.contains(editionId)) return;
    _prefetching.add(editionId);
    final total = toPage - fromPage + 1;
    final progress = progressFor(editionId).._set(done: 0, total: total, running: true);
    // P2‑5: every download posts a live status-bar progress notification.
    final notifId = 'mushaf_$editionId';
    final notifTitle = title ?? editionId;
    await DownloadNotifications.instance.ensureInitialized();
    var cancelled = false;
    // P3-46: see DownloadForegroundServiceBridge's own doc — protects this
    // process from being frozen/killed by the OS while backgrounded during
    // this download (604 sequential page fetches, the longest-running
    // download in the app).
    await DownloadForegroundServiceBridge.acquire(title: notifTitle);
    try {
      var done = 0;
      for (var page = fromPage; page <= toPage; page++) {
        if (!_prefetching.contains(editionId)) {
          cancelled = true;
          break;
        }
        // Pause: idle here (job stays alive, progress frozen) until resumed
        // or cancelled. Notification is cleared while paused, re-posted after.
        while (_paused.contains(editionId) &&
            _prefetching.contains(editionId)) {
          if (!progress.paused) {
            progress._set(paused: true);
            await DownloadNotifications.instance.clear(notifId);
          }
          await Future<void>.delayed(const Duration(milliseconds: 400));
        }
        if (progress.paused) progress._set(paused: false);
        if (!_prefetching.contains(editionId)) {
          cancelled = true;
          break;
        }
        try {
          await svgForPage(
            editionId: editionId,
            sourcePath: sourcePath,
            page: page,
          );
        } catch (_) {
          // leave this page for a later run
        }
        done++;
        progress._set(done: done);
        onProgress?.call(done, total);
        await DownloadNotifications.instance.showProgress(
          id: notifId,
          title: notifTitle,
          done: done,
          total: total,
          detail: '$done / $total',
        );
      }
    } finally {
      _prefetching.remove(editionId);
      _paused.remove(editionId);
      progress._set(running: false, paused: false); // listeners settle here
      if (cancelled) {
        await DownloadNotifications.instance.clear(notifId);
      } else {
        await DownloadNotifications.instance
            .showComplete(id: notifId, title: notifTitle);
      }
      await DownloadForegroundServiceBridge.release();
    }
  }

  final Set<String> _prefetching = {};
  final Set<String> _paused = {};

  void pausePrefetch(String editionId) => _paused.add(editionId);
  void resumePrefetch(String editionId) => _paused.remove(editionId);
  bool isPrefetchPaused(String editionId) => _paused.contains(editionId);

  /// Live progress of an in-flight [prefetchEdition], per edition id. Created
  /// on first request; a widget listens to re-sync after being rebuilt.
  final Map<String, PrefetchProgress> _progress = {};

  PrefetchProgress progressFor(String editionId) =>
      _progress.putIfAbsent(editionId, PrefetchProgress.new);

  bool isPrefetching(String editionId) => _prefetching.contains(editionId);

  void cancelPrefetch(String editionId) => _prefetching.remove(editionId);

  /// True when [page] of [editionId] is already readable with no network.
  Future<bool> isCached(String editionId, int page) async {
    if (_memory.containsKey('$editionId/$page')) return true;
    final file = _fileFor(await _pageDir(editionId), page);
    return file.existsSync() && await file.length() > 4096;
  }

  /// Pages of [editionId] already stored on this device — bundled editions
  /// (see `_kBundledMushafEditions`) are unconditionally "all of them",
  /// since every page ships in the APK itself rather than being written to
  /// the disk cache this scans; without this, a bundled edition's own
  /// "Download" tile would misleadingly show 0/604 despite every page
  /// already being instantly readable.
  Future<Set<int>> cachedPages(String editionId) async {
    if (_kBundledMushafEditions.contains(editionId)) {
      return {for (var p = firstPage; p <= lastPage; p++) p};
    }
    final dir = await _pageDir(editionId);
    if (!dir.existsSync()) return <int>{};
    final pages = <int>{};
    for (final entity in dir.listSync()) {
      if (entity is! File) continue;
      final n = int.tryParse(p.basenameWithoutExtension(entity.path));
      if (n != null && n >= firstPage && n <= lastPage) pages.add(n);
    }
    return pages;
  }

  /// Bytes the cached copy of [editionId] currently occupies. For a bundled
  /// edition this is a fixed, measured constant (the real total of its 604
  /// bundled SVGs) rather than a disk scan — there's no per-device
  /// variance to measure, it's exactly what shipped in the APK.
  static const _bundledSizeBytes = <String, int>{'hafs_kfqc': 365010757};

  Future<int> cacheSizeBytes(String editionId) async {
    final bundled = _bundledSizeBytes[editionId];
    if (bundled != null) return bundled;
    final dir = await _pageDir(editionId);
    if (!dir.existsSync()) return 0;
    var total = 0;
    for (final entity in dir.listSync()) {
      if (entity is File) total += entity.lengthSync();
    }
    return total;
  }

  Future<void> clearCache(String editionId) async {
    _memory.removeWhere((k, _) => k.startsWith('$editionId/'));
    final dir = await _pageDir(editionId);
    if (dir.existsSync()) await dir.delete(recursive: true);
  }
}
