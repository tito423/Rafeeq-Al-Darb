import 'package:flutter/services.dart';

/// Bridges to `MainActivity.kt`'s FileProvider helper — Dart cannot mint a
/// `content://` URI on its own, and the native notification-sound API needs
/// one to play a custom (user-imported) adhan file.
class AdhanUriBridge {
  static const _channel = MethodChannel('com.tito.rafeeq_aldarb/adhan');

  static Future<String?> contentUriForFile(String path) async {
    try {
      return await _channel
          .invokeMethod<String>('contentUriForFile', {'path': path});
    } catch (_) {
      return null;
    }
  }
}
