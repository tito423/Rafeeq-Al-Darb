import 'package:flutter/services.dart';

/// P3-46: thin bridge to the real Android foreground service
/// (`DownloadForegroundService.kt`) that keeps this process from being
/// frozen/killed by the OS while backgrounded during an active download —
/// see that class's own doc comment for the full reasoning.
///
/// Every download-performing service in the app (`DownloadManager`,
/// `AyahAudioService`, `AdhanCatalogService`, `MushafPageService`) shares
/// this ONE reference count via [acquire]/[release] rather than each calling
/// the platform channel directly — several of them can have downloads in
/// flight at once, and the service must only actually start on the true
/// 0→1 transition and stop on the true "nothing left running" transition,
/// not once per individual download. Always call [release] in a `finally`
/// block paired with an [acquire] — an unbalanced call leaves either a
/// phantom permanent notification or, worse, an unprotected download.
/// Never throws — a device that refuses the foreground-service start (or
/// isn't Android at all) must not affect the download itself, which runs in
/// Dart regardless of this signal.
class DownloadForegroundServiceBridge {
  DownloadForegroundServiceBridge._();

  static const _channel = MethodChannel('com.tito.rafeeq_aldarb/download_service');
  static int _active = 0;

  /// Call right before starting a download; pair with [release] in a
  /// `finally` once it settles (success, failure, or cancel).
  static Future<void> acquire({required String title}) async {
    _active++;
    if (_active == 1) {
      try {
        await _channel.invokeMethod<bool>('start', {'title': title});
      } catch (_) {
        // Best-effort — see class doc.
      }
    }
  }

  static Future<void> release() async {
    if (_active == 0) return; // defensive: an unmatched release is a no-op, not a crash
    _active--;
    if (_active == 0) {
      try {
        await _channel.invokeMethod<void>('stop');
      } catch (_) {
        // Best-effort — see class doc.
      }
    }
  }
}
