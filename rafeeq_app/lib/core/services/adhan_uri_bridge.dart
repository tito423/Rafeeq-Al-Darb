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

  /// P3‑44: real-device feedback (a Honor phone, Magic OS) confirmed the
  /// long-flagged-but-not-yet-built gap in PHASE3.md — the Adhan
  /// notification got killed within seconds, a real Android-14 battery-
  /// optimization exemption doesn't fix, because OEMs like Honor/Huawei/
  /// Xiaomi/Oppo/Vivo/OnePlus run their own "auto-start"/"protected apps"
  /// manager on top of stock Android's own process-killing rules. There is
  /// no public API to query or grant this — only a well-known per-OEM
  /// settings Activity to launch directly (see `MainActivity.kt`).
  /// Whether this device's manufacturer is one this app knows a specific
  /// screen for — used to decide whether the settings card even shows,
  /// not a guarantee the underlying setting is actually granted (there's
  /// no API to check that either, unlike the other permission cards).
  static Future<bool> hasKnownAutostartSettings() async {
    try {
      return await _channel.invokeMethod<bool>('hasKnownAutostartSettings') ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Opens this device's real OEM auto-start/protected-apps manager if a
  /// known one exists for its manufacturer, else falls back to the plain
  /// App Info screen — never a silent no-op.
  static Future<void> openAutostartSettings() async {
    try {
      await _channel.invokeMethod<void>('openAutostartSettings');
    } catch (_) {}
  }
}
