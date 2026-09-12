import 'package:flutter/services.dart';

import '../../../core/services/notification_router.dart';

/// The native half of routing a tap on a **grouped** download notification.
///
/// `background_downloader` cannot do this itself — see `MainActivity.kt`'s
/// `pendingDownloadTap` for the reading of its source that establishes why,
/// and for the device measurement that found it. The short version: a group
/// notification's tap intent carries an empty task, and the plugin's own
/// handler skips it, so `taskNotificationTapCallback` never fires for any
/// download this app posts.
///
/// So Kotlin reads the intent and hands over which queue was tapped. Two
/// paths, because a notification can be tapped either while the app is
/// running or to launch it cold:
///
///  * `onNewIntent` → the channel pushes `tap` straight away;
///  * a cold start → nothing is listening yet, so the destination is held and
///    [takePending] collects it once the tree is up.
class DownloadTapChannel {
  DownloadTapChannel._();
  static final DownloadTapChannel instance = DownloadTapChannel._();

  static const _channel =
      MethodChannel('com.tito.rafeeq_aldarb/download_tap');

  bool _wired = false;

  /// Starts listening, and collects a tap that launched the app.
  Future<void> start() async {
    if (_wired) return;
    _wired = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'tap') {
        final what = call.arguments as String?;
        if (what != null) _route(what);
      }
      return null;
    });
    await takePending();
  }

  /// The destination of the notification that launched the app, if that is
  /// why it started. Safe to call more than once — Kotlin clears it.
  Future<void> takePending() async {
    try {
      final what = await _channel.invokeMethod<String>('takePending');
      if (what != null) _route(what);
    } catch (_) {
      // No native side (a test, or another platform) — nothing to route.
    }
  }

  void _route(String what) =>
      NotificationRouter.route('${NotificationRouter.downloadPrefix}$what');
}
