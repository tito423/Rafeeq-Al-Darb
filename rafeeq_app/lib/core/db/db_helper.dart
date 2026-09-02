import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Copies a bundled SQLite asset into app storage (once) and opens it.
///
/// The app ships real databases inside the APK; this helper materialises
/// them under the app-support directory so sqflite can open them read-only.
class DbHelper {
  static final DbHelper instance = DbHelper._();
  DbHelper._();

  final Map<String, Database> _cache = {};

  /// Opens [assetName] (e.g. "data/quran_local.db").
  /// [stamp] busts the cache when the bundled DB is upgraded.
  Future<Database> openBundled(
    String assetName, {
    String stamp = 'v1',
    bool readOnly = true,
  }) async {
    if (_cache[assetName] != null) return _cache[assetName]!;

    final supportDir = await getApplicationSupportDirectory();
    final dbDir = p.join(supportDir.path, 'databases');
    await Directory(dbDir).create(recursive: true);

    final fileName = p.basename(assetName);
    final dbPath = p.join(dbDir, fileName);
    final stampPath = p.join(dbDir, '$fileName.stamp');

    final needsCopy = !File(dbPath).existsSync() ||
        !File(stampPath).existsSync() ||
        (File(stampPath).existsSync() &&
            File(stampPath).readAsStringSync() != stamp);

    if (needsCopy) {
      final data = await rootBundle.load('assets/$assetName');
      final tmpPath = '$dbPath.tmp';
      final tmp = File(tmpPath);
      await tmp.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
      // Atomic swap so a crash never leaves a truncated DB.
      final dest = File(dbPath);
      if (dest.existsSync()) await dest.delete();
      tmp.renameSync(dbPath);
      File(stampPath).writeAsStringSync(stamp);
    }

    // A read-only bundled DB must not be opened with `version:` — sqflite would
    // run `PRAGMA user_version = …`, a write, and fail with SQLITE_READONLY.
    final db = readOnly
        ? await openReadOnlyDatabase(dbPath)
        : await openDatabase(dbPath, version: 1);
    _cache[assetName] = db;
    return db;
  }

  /// Opens a downloaded database (e.g. hadith.db placed by the download
  /// engine). Returns null when the file isn't present yet.
  Future<Database?> openDownloaded(String fileName) async {
    if (_cache[fileName] != null) return _cache[fileName]!;
    final supportDir = await getApplicationSupportDirectory();
    final dbPath = p.join(supportDir.path, 'databases', fileName);
    if (!File(dbPath).existsSync()) return null;
    final db = await openDatabase(dbPath, readOnly: false, version: 1);
    _cache[fileName] = db;
    return db;
  }

  Future<void> deleteDownloaded(String fileName) async {
    _cache.remove(fileName);
    final supportDir = await getApplicationSupportDirectory();
    final dbPath = p.join(supportDir.path, 'databases', fileName);
    final f = File(dbPath);
    if (f.existsSync()) await f.delete();
  }

  Future<bool> isDownloaded(String fileName) async {
    final supportDir = await getApplicationSupportDirectory();
    return File(p.join(supportDir.path, 'databases', fileName)).existsSync();
  }
}
