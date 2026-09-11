import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One audio file Android's media index knows about.
class DeviceAudio {
  final int id;
  final String uri;
  final String title;
  final String? artist;
  final String? album;
  final String folder;
  final int durationMs;
  final int size;

  const DeviceAudio({
    required this.id,
    required this.uri,
    required this.title,
    required this.artist,
    required this.album,
    required this.folder,
    required this.durationMs,
    required this.size,
  });

  /// Android writes `<unknown>` where a file carries no tag.
  static String? _tag(Object? v) {
    final s = (v as String?)?.trim();
    return (s == null || s.isEmpty || s == '<unknown>') ? null : s;
  }

  factory DeviceAudio.fromMap(Map<dynamic, dynamic> m) => DeviceAudio(
        id: (m['id'] as num).toInt(),
        uri: m['uri'] as String,
        title: (m['title'] as String? ?? '').trim(),
        artist: _tag(m['artist']),
        album: _tag(m['album']),
        folder: (m['folder'] as String? ?? '').trim(),
        durationMs: (m['duration'] as num? ?? 0).toInt(),
        size: (m['size'] as num? ?? 0).toInt(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'uri': uri,
        'title': title,
        'artist': artist,
        'album': album,
        'folder': folder,
        'duration': durationMs,
        'size': size,
      };
}

/// «اِدّي إمكانية لمشغّل القرآن إنه يعمل اسكان على كل ملفات الصوت في الجهاز
/// ويضيفها، ويعملها إندكسينج بالفولدرات والألبومات وأصحاب التراكات».
///
/// Asks for the phone's audio permission, reads the media index once, and
/// keeps the result on disk so the list opens instantly next time; «فحص من
/// جديد» reads it again.
class DeviceAudioScanner extends ChangeNotifier {
  DeviceAudioScanner._();
  static final DeviceAudioScanner instance = DeviceAudioScanner._();

  static const _channel = MethodChannel('com.tito.rafeeq_aldarb/media_audio');

  List<DeviceAudio> items = const [];
  bool scanning = false;
  bool denied = false;
  bool _loaded = false;

  static const _foldersKey = 'quran_audio.user_folders_v1';
  static const _autoKey = 'quran_audio.auto_scan_v1';
  static const audioExtensions = {'.mp3', '.m4a', '.aac', '.ogg', '.opus', '.wav', '.flac'};

  /// Folders he added himself, each with the audio files under it.
  /// «يقدر يضيف ملفات أو فولدرات كاملة من اختياري».
  Map<String, List<String>> userFolders = const {};

  /// «أول ما أفتح المشغّل يعمل اسكان أوتوماتيك أو مانيوال».
  bool autoScan = true;

  Future<void> _loadFolders() async {
    final prefs = await SharedPreferences.getInstance();
    autoScan = prefs.getBool(_autoKey) ?? true;
    await _refreshFolders(prefs.getStringList(_foldersKey) ?? const []);
  }

  Future<void> _refreshFolders(List<String> paths) async {
    final exts = audioExtensions;
    final listed = await Isolate.run(() {
      final out = <String, List<String>>{};
      for (final path in paths) {
        final dir = Directory(path);
        if (!dir.existsSync()) continue;
        try {
          final files = [
            for (final e in dir.listSync(recursive: true, followLinks: false))
              if (e is File && exts.contains(p.extension(e.path).toLowerCase())) e.path,
          ]..sort();
          out[path] = files;
        } catch (_) {
          out[path] = const [];
        }
      }
      return out;
    });
    userFolders = listed;
    notifyListeners();
  }

  Future<void> addFolder(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final list = {...prefs.getStringList(_foldersKey) ?? const <String>[], path}.toList();
    await prefs.setStringList(_foldersKey, list);
    await _refreshFolders(list);
  }

  Future<void> removeFolder(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final list = [for (final x in prefs.getStringList(_foldersKey) ?? const <String>[]) if (x != path) x];
    await prefs.setStringList(_foldersKey, list);
    await _refreshFolders(list);
  }

  Future<void> setAutoScan(bool value) async {
    autoScan = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoKey, value);
  }

  /// Runs a scan by itself when the player opens — only when automatic
  /// scanning is on and the permission is already granted, so opening the
  /// player never raises a dialog on its own.
  Future<void> autoScanIfAllowed() async {
    await loadCached();
    if (!autoScan || scanning) return;
    final granted = await Permission.audio.isGranted || await Permission.storage.isGranted;
    if (granted) await scan();
  }

  Future<File> _cache() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'quran_audio', 'cache'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return File(p.join(dir.path, 'device_audio.json'));
  }

  Future<void> loadCached() async {
    if (_loaded) return;
    _loaded = true;
    await _loadFolders();
    try {
      final f = await _cache();
      if (!f.existsSync()) return;
      items = [
        for (final m in jsonDecode(await f.readAsString()) as List<dynamic>)
          DeviceAudio.fromMap(m as Map<String, dynamic>),
      ];
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> _permission() async {
    final results = await [Permission.audio, Permission.storage].request();
    return results.values.any((s) => s.isGranted || s.isLimited);
  }

  Future<void> scan() async {
    if (scanning) return;
    scanning = true;
    notifyListeners();
    try {
      if (!await _permission()) {
        denied = true;
        return;
      }
      denied = false;
      final raw = await _channel.invokeMethod<List<dynamic>>('scan') ?? const [];
      items = [for (final m in raw) DeviceAudio.fromMap(m as Map<dynamic, dynamic>)];
      final f = await _cache();
      await f.writeAsString(jsonEncode([for (final a in items) a.toMap()]));
    } catch (_) {
      // Leave the last good list in place.
    } finally {
      scanning = false;
      notifyListeners();
    }
  }

  /// Opens the app's system settings page, for a permission refused for good.
  Future<void> openSettings() => openAppSettings();
}
