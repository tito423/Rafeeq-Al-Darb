import 'dart:io';
import 'package:easy_localization/easy_localization.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_router.dart';

/// Android status-bar progress for the one download path that is **not** a
/// file transfer: `MushafPageService`'s page prefetch, which renders and
/// caches pages itself rather than handing a URL to the platform downloader.
///
/// Everything that really transfers files — offline packs, books, the hadith
/// database, adhan clips, and every ayah of a recitation — now goes through
/// `background_downloader` (see `DownloadEngine`), which posts its own
/// *grouped* notification: one status-bar entry counting finished tasks,
/// instead of one row per file. This helper is what is left for the
/// remaining case.
class DownloadNotifications {
  DownloadNotifications._();
  static final DownloadNotifications instance = DownloadNotifications._();

  static const _channelId = 'rafeeq_downloads';
  static const _channelName = 'Downloads';
  bool _ready = false;

  Future<void> ensureInitialized() async {
    if (_ready) return;
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      // Through the router. This used to install `onDidReceiveNotificationResponse: (_) {}`,
      // which swallowed every tap in the app — see `NotificationRouter`.
      await NotificationRouter.instance.ensureInitialized();
      // Android 13+ needs the runtime POST_NOTIFICATIONS grant before any
      // progress notification will show. Ask once, on the first download.
      final androidImpl = plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidImpl?.requestNotificationsPermission();
      _ready = true;
    } catch (_) {
      // Notifications are optional; downloads still work without them.
    }
  }

  int _notificationId(String id) => 4700 + _hash(id);

  static int _hash(String s) {
    var h = 0;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h % 300;
  }

  /// Last time a progress notification was posted for an id — used to throttle
  /// updates to ~1/sec so a fast download doesn't spam the shade.
  final Map<String, DateTime> _lastPost = {};

  /// Post/refresh an ongoing progress notification for [id]. [done]/[total]
  /// drive a determinate bar; pass [total] <= 0 for an indeterminate one.
  /// [detail] overrides the auto "NN%" line (e.g. "١٢ / ١١٤ صفحة").
  Future<void> showProgress({
    required String id,
    required String title,
    required int done,
    required int total,
    String? detail,
    bool force = false,
  }) async {
    if (!_ready || !Platform.isAndroid) return;
    final now = DateTime.now();
    final last = _lastPost[id];
    final complete = total > 0 && done >= total;
    if (!force &&
        !complete &&
        last != null &&
        now.difference(last) < const Duration(milliseconds: 900)) {
      return;
    }
    _lastPost[id] = now;
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      final hasSize = total > 0;
      final pct = hasSize ? ((done / total) * 100).round() : 0;
      final android = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Offline content download progress',
        importance: Importance.low,
        priority: Priority.low,
        onlyAlertOnce: true,
        ongoing: true,
        showProgress: hasSize,
        maxProgress: 100,
        progress: pct,
        indeterminate: !hasSize,
        // Collapses with the other prefetch notifications instead of stacking
        // as separate rows — the same grouping `background_downloader` gives
        // the file transfers.
        groupKey: _channelId,
      );
      await plugin.show(
        _notificationId(id),
        title,
        detail ?? (hasSize ? '$pct%' : '$done'),
        NotificationDetails(android: android),
      );
    } catch (_) {}
  }

  /// Replace the ongoing notification for [id] with a short auto-dismissing
  /// "downloaded" one.
  Future<void> showComplete({required String id, required String title}) async {
    if (!_ready || !Platform.isAndroid) return;
    _lastPost.remove(id);
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin.cancel(_notificationId(id));
      const android = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Offline content download progress',
        importance: Importance.low,
        priority: Priority.low,
        groupKey: _channelId,
      );
      await plugin.show(
        _notificationId(id) + 1000,
        title,
        'notif.dl_done'.tr(),
        NotificationDetails(android: android),
      );
    } catch (_) {}
  }

  /// Remove the ongoing notification for [id] (cancel / failure — no toast).
  Future<void> clear(String id) async {
    _lastPost.remove(id);
    if (!_ready || !Platform.isAndroid) return;
    try {
      await FlutterLocalNotificationsPlugin().cancel(_notificationId(id));
    } catch (_) {}
  }
}
