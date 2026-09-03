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

  /// P3‑19: Android 14+ (API 34) requires a *separate*, user-granted toggle
  /// for full-screen-intent notifications, beyond the `USE_FULL_SCREEN_INTENT`
  /// manifest permission this app already declares — without it, Android
  /// silently downgrades the Adhan alert to an ordinary heads-up
  /// notification instead of waking the screen over the lock screen. Always
  /// `true` below API 34 (nothing extra to grant there). `null` on error —
  /// treated as "can't tell," not as a hard "no."
  static Future<bool?> canUseFullScreenIntent() async {
    try {
      return await _channel.invokeMethod<bool>('canUseFullScreenIntent');
    } catch (_) {
      return null;
    }
  }

  /// Opens the system settings screen where the user grants the toggle
  /// above. A no-op below API 34.
  static Future<void> openFullScreenIntentSettings() async {
    try {
      await _channel.invokeMethod<void>('openFullScreenIntentSettings');
    } catch (_) {}
  }
}
