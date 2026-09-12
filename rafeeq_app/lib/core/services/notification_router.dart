import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// The **one** place `FlutterLocalNotificationsPlugin.initialize` is called.
///
/// THE BUG THIS EXISTS FOR, MEASURED ON emulator-5554.
/// `FlutterLocalNotificationsPlugin()` is a singleton — its constructor is a
/// factory returning one shared instance — and `initialize` sets exactly one
/// tap handler for the whole app. Five services were each calling it:
///
///   `AlarmPermissionsService`      passes no handler at all
///   `PrayerStatusNotification`     passes `onDidReceiveNotificationResponse: (_) {}`
///   `DownloadNotifications`        passes `onDidReceiveNotificationResponse: (_) {}`
///   `SunanSuwarReminderService`    passes its own
///   `QuoteReminderService`         passes its own
///
/// and the last one to run wins. `PrayerStatusNotification.initialize` runs
/// lazily from `AppShell`'s first frame — *after* `main()` — so its empty
/// callback replaced whatever `main()` had installed. A quote notification was
/// tapped on the device, the app came to the foreground, and **nothing
/// happened**: the tap was delivered to `(_) {}`. The سنن السور reminder had
/// the same defect and nobody had noticed, because a tap that opens the app
/// on the screen it was already on looks like it worked.
///
/// So: initialize once, here, and route by payload.
///
/// PAYLOAD FORMAT.
/// `<kind>:<argument>`, e.g. `quote:2:117`. A payload with no known prefix is
/// treated as a سنن السور surah id, which is what that feature has always
/// sent (a bare integer) — changing it would break notifications already
/// sitting in AlarmManager from a previous build.
class NotificationRouter {
  NotificationRouter._();
  static final NotificationRouter instance = NotificationRouter._();

  static const quotePrefix = 'quote:';

  /// «عايز لما أضغط على إشعار حاجة من التطبيق يروح للحاجة المتعلقة بالإشعار:
  /// تحميل تلاوة يروح لتنزيل التلاوات، تحميل رقية يروح لتحميل الرقية، تحميل
  /// مصحف يروح مباشرة لتحميل المصحف، وهكذا».
  ///
  /// `dl:<what>` — `dl:recitations`, `dl:ruqyah`, `dl:mushaf`, `dl:files`.
  /// The argument after the prefix names the destination, not the item: a
  /// download notification is about a queue, and the screen that owns the
  /// queue is where the reader wants to land.
  static const downloadPrefix = 'dl:';

  /// Set by `main()`. All nullable because a notification can be tapped
  /// before the app has finished wiring itself up, and dropping the tap is
  /// better than crashing on it.
  static void Function(String payload)? onQuote;
  static void Function(String payload)? onSurah;
  static void Function(String what)? onDownload;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  @pragma('vm:entry-point')
  static void _dispatch(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    if (payload.startsWith(quotePrefix)) {
      onQuote?.call(payload.substring(quotePrefix.length));
      return;
    }
    if (payload.startsWith(downloadPrefix)) {
      onDownload?.call(payload.substring(downloadPrefix.length));
      return;
    }
    if (int.tryParse(payload) != null) {
      onSurah?.call(payload);
    }
  }

  /// Safe to call from anywhere, as often as anyone likes — the plugin is
  /// initialized once and the handler is never replaced.
  Future<void> ensureInitialized() async {
    if (_ready) return;
    _ready = true;
    await _plugin.initialize(
      const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: _dispatch,
      onDidReceiveBackgroundNotificationResponse: _dispatch,
    );
  }

  /// The payload of the notification that **launched** the app, if that is why
  /// it started — read once and then forgotten.
  ///
  /// `onDidReceiveNotificationResponse` only fires while the process is alive.
  /// Tap a quote reminder with the app closed and Android starts the app cold;
  /// the callback never runs and the payload is only retrievable from
  /// `getNotificationAppLaunchDetails()`. That is why the owner reported
  /// «مش بتفتح المقولة في التطبيق كأنه لسه بيفتح من أول وجديد» — the app really was
  /// just starting, and the tap was going nowhere.
  ///
  /// Returns null when the app was started any other way.
  Future<String?> takeLaunchPayload() async {
    if (_launchPayloadTaken) return null;
    _launchPayloadTaken = true;
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp != true) return null;
      final payload = details?.notificationResponse?.payload;
      return (payload == null || payload.isEmpty) ? null : payload;
    } catch (_) {
      return null;
    }
  }

  bool _launchPayloadTaken = false;

  /// Routes a payload the same way a live tap is routed. Public so the launch
  /// path and the tap path cannot drift apart.
  static void route(String payload) =>
      _dispatch(NotificationResponse(
        notificationResponseType:
            NotificationResponseType.selectedNotification,
        payload: payload,
      ));
}
