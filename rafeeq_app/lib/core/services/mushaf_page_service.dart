import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';

/// Fetches mushaf pages and keeps them on disk, so a page opened once stays
/// readable with no network (offline-first mushaf).
///
/// Pages are vector SVG, not raster scans: the whole 604-page mushaf is a few
/// tens of MB instead of hundreds, stays sharp at any zoom level, and carries
/// the ayah hit layer that [AyahCoordsRepository] was built from.
class MushafPageService {
  MushafPageService._();
  static final MushafPageService instance = MushafPageService._();

  final Dio _dio = Dio();
  /// Keyed '<editionId>/<page>' so switching edition cannot serve a
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

  /// True when [page] of [editionId] is already readable with no network.
  Future<bool> isCached(String editionId, int page) async {
    if (_memory.containsKey('$editionId/$page')) return true;
    final file = _fileFor(await _pageDir(editionId), page);
    return file.existsSync() && await file.length() > 4096;
  }

  /// Pages of [editionId] already stored on this device.
  Future<Set<int>> cachedPages(String editionId) async {
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

  /// Bytes the cached copy of [editionId] currently occupies.
  Future<int> cacheSizeBytes(String editionId) async {
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
