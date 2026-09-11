import 'package:flutter/services.dart';

/// P3-46: thin bridge to the real Android foreground service
/// (`DownloadForegroundService.kt`) that keeps this process from being
/// frozen/killed by the OS while backgrounded during an active download.
///
/// Every caller shares this ONE reference count via [acquire]/[release]: the
/// service starts on the true 0→1 transition and stops on the true "nothing
/// left running" one. Always pair [release] with [acquire] in a `finally`.
/// Never throws — a device that refuses the foreground-service start must not
/// affect the download itself, which runs in Dart regardless.
///
/// **The service's notification is the download's only notification.** A
/// mushaf download used to post a second, `ongoing` progress notification of
/// its own through flutter_local_notifications. When Android killed the
/// process that one stayed — nothing was left to cancel it and an ongoing
/// notification cannot be swiped — which is «إشعار مصحف التجويد الملون يتابع
/// في الخلفية دايما معلق ودايما موجود». A foreground service's notification
/// goes away with the service, so progress is written into it via [update].
class DownloadForegroundServiceBridge {
  DownloadForegroundServiceBridge._();

  static const _channel = MethodChannel('com.tito.rafeeq_aldarb/download_service');
  static int _active = 0;
  static DateTime _lastUpdate = DateTime.fromMillisecondsSinceEpoch(0);

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

  /// Writes progress into the service's notification, at most about once a
  /// second unless [force] is set. A no-op when nothing holds the service.
  static Future<void> update({
    required String title,
    required int done,
    required int total,
    String? text,
    bool force = false,
  }) async {
    if (_active == 0) return;
    final now = DateTime.now();
    if (!force && now.difference(_lastUpdate) < const Duration(milliseconds: 900)) {
      return;
    }
    _lastUpdate = now;
    try {
      await _channel.invokeMethod<void>('update', {
        'title': title,
        'text': text ?? '$done / $total',
        'done': done,
        'total': total,
      });
    } catch (_) {}
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
