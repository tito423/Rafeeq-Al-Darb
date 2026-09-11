import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/quran/data/mushaf_edition.dart';
import '../config/app_config.dart';
import 'download_foreground_service.dart';
import 'download_notifications.dart';

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

  /// When [done] last moved. Repair uses it to tell a slow download from one
  /// that is not moving at all.
  DateTime lastTick = DateTime.now();

  double get fraction => total == 0 ? 0 : done / total;

  void _set({int? done, int? total, bool? running, bool? paused}) {
    if (done != null) {
      this.done = done;
      lastTick = DateTime.now();
    }
    if (total != null) this.total = total;
    if (running != null) this.running = running;
    if (paused != null) this.paused = paused;
    notifyListeners();
    if (running != null || (done != null && done % 10 == 0)) {
      MushafPageService.instance.changes.value++;
    }
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

  /// Bumped when any edition download starts, stops, or moves ten pages — for
  /// a screen that shows totals rather than one edition.
  final ValueNotifier<int> changes = ValueNotifier(0);

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

  /// The Hafs/Madinah page count, and the default for anything that hasn't
  /// been told otherwise. It is NOT true of every edition: the raster
  /// printings paginate differently (Shamarly is 521 pages, the Indo-Pak
  /// colour-coded one 564), so anything that walks or bounds a page range
  /// must take the edition's own `pages` rather than assume this.
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

  /// Raster editions: the on-disk scan for [page] if already downloaded, else
  /// null (the reader streams it from the network instead). Stored in the same
  /// per-edition dir the SVG cache uses, so `cachedPages`/`cacheSizeBytes`/
  /// `clearCache` cover raster editions unchanged.
  Future<File?> cachedImageFile(String editionId, int page,
      {String ext = 'jpg'}) async {
    final dir = await _pageDir(editionId);
    final f = File(p.join(dir.path, '${page.toString().padLeft(3, '0')}.$ext'));
    return (f.existsSync() && await f.length() > 4096) ? f : null;
  }

  /// Downloads one raster page scan to disk (skips one already present). Used by
  /// [prefetchEdition] for image editions — the raster counterpart of
  /// [svgForPage]'s network branch.
  Future<void> _fetchImageToDisk(
      String editionId, String imagePath, int page, String imageExt) async {
    final dir = await _pageDir(editionId);
    final file =
        File(p.join(dir.path, '${page.toString().padLeft(3, '0')}.$imageExt'));
    if (file.existsSync() && await file.length() > 4096) return;
    final res = await _dio.get<List<int>>(
      AppConfig.mushafImageUrl(imagePath, page, ext: imageExt),
      options: Options(
        responseType: ResponseType.bytes,
        receiveTimeout: const Duration(seconds: 40),
      ),
    );
    final bytes = res.data ?? const <int>[];
    if (bytes.length < 4096) {
      throw StateError('Incomplete mushaf scan $page (${bytes.length} bytes)');
    }
    final tmp = File('${file.path}.part');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(file.path);
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

  // ── Downloads he asked for, remembered ──────────────────────────────────
  //
  // «لما بضغط على زر الإصلاح بيقوللي لا توجد تحميلات غير مكتملة وهو أصلا مش
  // بيحمل ومعلق». Repair used to look only at the page cache: an edition with
  // no page on disk yet was "not started", and one whose loop was alive but
  // paused or stuck was "running" — so both answered «لا يوجد». What was asked
  // for is now written down when a download starts and cleared only when every
  // page is on disk or he cancels it, and that record is what repair and the
  // next launch resume from.

  static const _kWantedKey = 'mushaf.wanted_downloads_v1';

  Future<Set<String>> wantedEditions() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_kWantedKey) ?? const <String>[]).toSet();
  }

  Future<void> _setWanted(String editionId, bool wanted) async {
    final prefs = await SharedPreferences.getInstance();
    final set = (prefs.getStringList(_kWantedKey) ?? const <String>[]).toSet();
    final changed = wanted ? set.add(editionId) : set.remove(editionId);
    if (changed) await prefs.setStringList(_kWantedKey, set.toList());
  }

  Future<void> _start(MushafEdition e) => prefetchEdition(
        editionId: e.id,
        sourcePath: e.sourcePath,
        imagePath: e.imagePath,
        imageExt: e.imageExt,
        toPage: e.pages,
        title: e.nameAr,
      );

  /// A download with no page arriving for this long is stuck, not slow: one
  /// page is at most a 20 s connect plus a 40 s receive timeout.
  static const _stalledAfter = Duration(seconds: 90);

  /// Repairs every edition download that is not finishing, and returns how
  /// many it touched: a paused one is resumed, a stuck one is restarted, and
  /// one that was asked for and is not on the device — including one with no
  /// page downloaded yet — is started again.
  Future<int> repairPartialEditions(List<MushafEdition> editions) async {
    final wanted = await wantedEditions();
    var repaired = 0;
    for (final e in editions) {
      if (isPrefetching(e.id)) {
        if (_paused.contains(e.id)) {
          resumePrefetch(e.id);
          repaired++;
        } else if (DateTime.now().difference(progressFor(e.id).lastTick) >
            _stalledAfter) {
          _stopLoop(e.id);
          unawaited(_start(e));
          repaired++;
        }
        continue;
      }
      final cached = await cachedPages(e.id, totalPages: e.pages);
      if (cached.length >= e.pages) {
        await _setWanted(e.id, false);
        continue;
      }
      if (cached.isEmpty && !wanted.contains(e.id)) continue;
      unawaited(_start(e));
      repaired++;
    }
    return repaired;
  }

  /// Picks up, after a launch, every download that was asked for and never
  /// finished — the process that was running it is gone.
  Future<int> resumeWantedDownloads(List<MushafEdition> editions) async {
    final wanted = await wantedEditions();
    var resumed = 0;
    for (final e in editions) {
      if (!wanted.contains(e.id) || isPrefetching(e.id)) continue;
      final cached = await cachedPages(e.id, totalPages: e.pages);
      if (cached.length >= e.pages) {
        await _setWanted(e.id, false);
        continue;
      }
      unawaited(_start(e));
      resumed++;
    }
    return resumed;
  }

  /// Each run of [prefetchEdition] owns a generation number, so a restarted
  /// download and the loop it replaced can never both be writing pages.
  final Map<String, int> _generation = {};

  void _stopLoop(String editionId) {
    _generation[editionId] = (_generation[editionId] ?? 0) + 1;
    _prefetching.remove(editionId);
    _paused.remove(editionId);
  }

  /// Downloads a whole edition for offline reading. Pages already cached are
  /// skipped, so an interrupted download resumes where it stopped; a page that
  /// fails is left for the next run, and three failures in a row stop this
  /// one (no network, or the host refusing) while the download stays wanted.
  Future<void> prefetchEdition({
    required String editionId,
    required String sourcePath,
    int fromPage = firstPage,
    int toPage = lastPage,
    void Function(int done, int total)? onProgress,
    String? title,
    String? imagePath,
    String imageExt = 'jpg',
  }) async {
    if (_prefetching.contains(editionId)) return;
    _prefetching.add(editionId);
    _userCancelled.remove(editionId);
    final gen = (_generation[editionId] ?? 0) + 1;
    _generation[editionId] = gen;
    bool mine() =>
        _generation[editionId] == gen && _prefetching.contains(editionId);

    await _setWanted(editionId, true);
    final total = toPage - fromPage + 1;
    final progress = progressFor(editionId)
      .._set(done: 0, total: total, running: true, paused: false);
    final notifTitle = title ?? editionId;
    await DownloadNotifications.instance.ensureInitialized();
    var stopped = false;
    await DownloadForegroundServiceBridge.acquire(title: notifTitle);
    try {
      var done = 0;
      var consecutiveErrors = 0;
      for (var page = fromPage; page <= toPage; page++) {
        if (!mine()) {
          stopped = true;
          break;
        }
        while (_paused.contains(editionId) && mine()) {
          if (!progress.paused) {
            progress._set(paused: true);
            await DownloadForegroundServiceBridge.update(
              title: notifTitle,
              done: done,
              total: total,
              text: 'downloads.paused'.tr(),
              force: true,
            );
          }
          await Future<void>.delayed(const Duration(milliseconds: 400));
        }
        if (progress.paused) progress._set(paused: false);
        if (!mine()) {
          stopped = true;
          break;
        }
        try {
          if (imagePath != null) {
            await _fetchImageToDisk(editionId, imagePath, page, imageExt);
          } else {
            await svgForPage(
              editionId: editionId,
              sourcePath: sourcePath,
              page: page,
            );
          }
          consecutiveErrors = 0;
        } catch (_) {
          consecutiveErrors++;
          if (consecutiveErrors >= 3) {
            stopped = true;
            break;
          }
        }
        if (!mine()) {
          stopped = true;
          break;
        }
        done++;
        progress._set(done: done);
        onProgress?.call(done, total);
        await DownloadForegroundServiceBridge.update(
          title: notifTitle,
          done: done,
          total: total,
        );
      }
    } finally {
      final stillMine = _generation[editionId] == gen;
      if (stillMine) {
        _prefetching.remove(editionId);
        _paused.remove(editionId);
        progress._set(running: false, paused: false);
      }
      if (_userCancelled.remove(editionId)) {
        await _setWanted(editionId, false);
      } else if (stillMine && !stopped) {
        final have = await cachedPages(editionId, totalPages: toPage);
        if (have.length >= toPage) {
          await _setWanted(editionId, false);
          await DownloadNotifications.instance
              .showComplete(id: 'mushaf_$editionId', title: notifTitle);
        }
      }
      await DownloadForegroundServiceBridge.release();
    }
  }

  /// Editions he stopped himself — the only stop that forgets the download.
  final Set<String> _userCancelled = {};

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

  void cancelPrefetch(String editionId) {
    if (!_prefetching.contains(editionId)) {
      unawaited(_setWanted(editionId, false));
      return;
    }
    _userCancelled.add(editionId);
    _prefetching.remove(editionId);
  }

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
  Future<Set<int>> cachedPages(String editionId, {int? totalPages}) async {
    final last = totalPages ?? lastPage;
    if (_kBundledMushafEditions.contains(editionId)) {
      return {for (var p = firstPage; p <= last; p++) p};
    }
    final dir = await _pageDir(editionId);
    if (!dir.existsSync()) return <int>{};
    final pages = <int>{};
    for (final entity in dir.listSync()) {
      if (entity is! File) continue;
      final n = int.tryParse(p.basenameWithoutExtension(entity.path));
      if (n != null && n >= firstPage && n <= last) pages.add(n);
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

  /// Deletes the page cache of any printing that is no longer in the
  /// catalogue, and returns the bytes recovered.
  ///
  /// Three printings were removed in v3.16.0 because they paginate their own
  /// way and so can carry no ayah regions — the owner's «شيله من التطبيق كله».
  /// Without this their downloaded pages would sit on the device for ever:
  /// `storageSummaryProvider` walks the CATALOGUE, so a directory whose
  /// edition is gone is invisible in «التنزيلات» and there is no button left
  /// that could free it. Nothing here can touch a printing that still exists,
  /// because the set of live ids is passed in rather than assumed.
  Future<int> purgeUnknownEditions(Iterable<String> liveIds) async {
    final live = liveIds.toSet()..addAll(_kBundledMushafEditions);
    final base = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(base.path, 'mushaf'));
    if (!root.existsSync()) return 0;
    var freed = 0;
    for (final entity in root.listSync()) {
      if (entity is! Directory) continue;
      final id = p.basename(entity.path);
      if (live.contains(id)) continue;
      for (final f in entity.listSync(recursive: true)) {
        if (f is File) freed += f.lengthSync();
      }
      _memory.removeWhere((k, _) => k.startsWith('$id/'));
      entity.deleteSync(recursive: true);
    }
    return freed;
  }

  Future<void> clearCache(String editionId) async {
    cancelPrefetch(editionId);
    await _setWanted(editionId, false);
    _memory.removeWhere((k, _) => k.startsWith('$editionId/'));
    final dir = await _pageDir(editionId);
    if (dir.existsSync()) await dir.delete(recursive: true);
  }
}
