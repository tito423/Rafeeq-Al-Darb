import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

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

  Future<File> _cache() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'quran_audio', 'cache'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return File(p.join(dir.path, 'device_audio.json'));
  }

  Future<void> loadCached() async {
    if (_loaded) return;
    _loaded = true;
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
