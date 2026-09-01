import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';

/// Downloads mushaf page images from the real CDN and caches them on disk,
/// so pages become available offline after first view (offline-first mushaf).
class MushafImageService {
  MushafImageService._();
  static final MushafImageService instance = MushafImageService._();

  final Dio _dio = Dio();

  /// Returns the local file path for [page], downloading it (and caching) if
  /// needed. Throws when the network is unavailable and no cache exists.
  Future<String> fileForPage(int page) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(dir.path, 'mushaf_pages'));
    await folder.create(recursive: true);

    final file = File(p.join(folder.path, 'page${page.toString().padLeft(3, '0')}.png'));
    if (file.existsSync() && file.lengthSync() > 1000) return file.path;

    await _dio.download(
      AppConfig.mushafImageUrl(page),
      file.path,
      options: Options(receiveTimeout: const Duration(seconds: 20)),
    );
    return file.path;
  }

  /// Lists pages already cached on this device (real offline page pack).
  Future<Set<int>> cachedPages() async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(dir.path, 'mushaf_pages'));
    if (!folder.existsSync()) return {};
    return folder
        .listSync()
        .whereType<File>()
        .map((f) => int.tryParse(p.basenameWithoutExtension(f.path).replaceAll('page', '')) ?? -1)
        .where((n) => n >= 1 && n <= 604)
        .toSet();
  }
}