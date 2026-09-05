import 'dart:async';
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/adhan_mode.dart';

/// Native alarm/notification pipeline for the Adhan.
///
/// - Exact alarms (USE_EXACT_ALARM / SCHEDULE_EXACT_ALARM in the manifest)
///   scheduled with zonedSchedule + matchDateTimeComponents daily.
/// - The Adhan **audio itself** is played by Android's own notification
///   sound API (`RawResourceAndroidNotificationSound` for the 10 bundled
///   muezzins, `UriAndroidNotificationSound` for a custom import) — not by
///   just_audio. That is deliberate: `zonedSchedule`'s alarm fires through a
///   plain Java BroadcastReceiver (flutter_local_notifications'
///   `ScheduledNotificationReceiver`), which does **not** start the Dart
///   VM. If the app is killed, no Dart code runs, so only a native-side
///   sound can possibly play. This is also why the notification channel's
///   sound is fixed by *mode + chosen adhan*, not by prayer — Android
///   notification channels are immutable after creation, so each
///   (mode, sound) combination gets its own small, reusable channel instead
///   of trying to mutate one.
/// - `fullScreenIntent: true` (mode [AdhanMode.full]) makes Android launch
///   `MainActivity` automatically over the lock screen — `MainActivity`
///   already declares `showWhenLocked` / `turnScreenOn`.
/// - Real notification actions: "Stop" cancels the notification (which also
///   stops its sound); "Mute" swaps it for a silent, still-ongoing copy.
class AdhanAlarmService {
  AdhanAlarmService._();
  static final AdhanAlarmService instance = AdhanAlarmService._();

  static const actionStop = 'rafeeq.action.STOP_ADHAN';
  static const actionMute = 'rafeeq.action.MUTE_ADHAN';

  static const _channelSilent = 'radh_silent';
  static const _channelVibrate = 'radh_vibrate';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;
  final Set<String> _createdChannels = {};

  /// Fired when the user taps the notification body (not Stop/Mute) — the
  /// payload is the JSON this service scheduled the alarm with. Wired by
  /// `main.dart` to push the full-screen Adhan route.
  static void Function(String payload)? onOpenAdhan;

  static void Function()? onMuteRequested;
  static void Function()? onStopRequested;

  @pragma('vm:entry-point')
  static void _onNotificationResponse(NotificationResponse response) {
    switch (response.actionId) {
      case actionStop:
        instance.stopById(response.id ?? 0);
        onStopRequested?.call();
        break;
      case actionMute:
        instance.muteById(response.id ?? 0, response.payload);
        onMuteRequested?.call();
        break;
      default:
        if (response.payload != null) onOpenAdhan?.call(response.payload!);
    }
  }

  Future<void> initialize() async {
    if (_ready) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: androidInit),
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _onNotificationResponse,
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();
    await _requestPermissions();
    _ready = true;
  }

  Future<void> _requestPermissions() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
    if (await Permission.scheduleExactAlarm.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }
  }

  /// Prompts the system's battery-optimization exemption dialog for this
  /// app. Returns whether the exemption is granted afterwards.
  Future<bool> requestBatteryOptimizationExemption() async {
    if (await Permission.ignoreBatteryOptimizations.isGranted) return true;
    final status = await Permission.ignoreBatteryOptimizations.request();
    return status.isGranted;
  }

  Future<bool> isBatteryOptimizationExempt() =>
      Permission.ignoreBatteryOptimizations.isGranted;

  /// Was the app launched by the user tapping an Adhan notification while
  /// fully killed? Checked once at cold start (`main.dart`) since the live
  /// tap callback only fires for a running/backgrounded app.
  Future<String?> consumeColdLaunchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp == true) {
      return details!.notificationResponse?.payload;
    }
    return null;
  }

  Future<void> _ensureChannel(
    AndroidFlutterLocalNotificationsPlugin? plugin,
    AndroidNotificationChannel channel,
  ) async {
    if (_createdChannels.contains(channel.id)) return;
    await plugin?.createNotificationChannel(channel);
    _createdChannels.add(channel.id);
  }

  String _soundChannelId(String prefix, {String? raw, String? uri}) {
    final key = raw ?? (uri != null ? 'u${uri.hashCode & 0x7fffffff}' : 'none');
    return '${prefix}_$key';
  }

  Future<AndroidNotificationDetails> _detailsFor({
    required AdhanMode mode,
    String? rawResource,
    String? customUri,
  }) async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    const actions = <AndroidNotificationAction>[
      AndroidNotificationAction(actionStop, 'إيقاف', cancelNotification: true),
      AndroidNotificationAction(actionMute, 'كتم', cancelNotification: false),
    ];

    switch (mode) {
      case AdhanMode.silent:
        await _ensureChannel(
          androidPlugin,
          const AndroidNotificationChannel(
            _channelSilent,
            'أذان — صامت',
            description: 'تنبيه صامت لوقت الصلاة، بلا صوت أو اهتزاز',
            importance: Importance.defaultImportance,
            playSound: false,
            enableVibration: false,
          ),
        );
        return const AndroidNotificationDetails(
          _channelSilent,
          'أذان — صامت',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          category: AndroidNotificationCategory.alarm,
          ongoing: true,
          autoCancel: false,
          playSound: false,
          enableVibration: false,
          actions: actions,
        );

      case AdhanMode.vibrate:
        await _ensureChannel(
          androidPlugin,
          const AndroidNotificationChannel(
            _channelVibrate,
            'أذان — اهتزاز فقط',
            description: 'تنبيه بالاهتزاز فقط لوقت الصلاة',
            importance: Importance.high,
            playSound: false,
            enableVibration: true,
          ),
        );
        return const AndroidNotificationDetails(
          _channelVibrate,
          'أذان — اهتزاز فقط',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.alarm,
          ongoing: true,
          autoCancel: false,
          playSound: false,
          enableVibration: true,
          actions: actions,
        );

      case AdhanMode.audio:
      case AdhanMode.full:
        final sound = rawResource != null
            ? RawResourceAndroidNotificationSound(rawResource)
            : (customUri != null
                  ? UriAndroidNotificationSound(customUri)
                  : null);
        final prefix = mode == AdhanMode.full ? 'radh_full' : 'radh_audio';
        final channelId = _soundChannelId(
          prefix,
          raw: rawResource,
          uri: customUri,
        );
        await _ensureChannel(
          androidPlugin,
          AndroidNotificationChannel(
            channelId,
            mode == AdhanMode.full ? 'أذان — شاشة كاملة' : 'أذان — صوت',
            description: 'صوت الأذان الحقيقي لوقت الصلاة',
            importance: Importance.max,
            sound: sound,
            audioAttributesUsage: AudioAttributesUsage.alarm,
            playSound: sound != null,
            enableVibration: true,
          ),
        );
        return AndroidNotificationDetails(
          channelId,
          mode == AdhanMode.full ? 'أذان — شاشة كاملة' : 'أذان — صوت',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          fullScreenIntent: mode == AdhanMode.full,
          ongoing: true,
          autoCancel: false,
          playSound: sound != null,
          sound: sound,
          enableVibration: true,
          actions: actions,
        );
    }
  }

  /// Schedules (or re-schedules) the daily exact alarm for one prayer.
  /// [payload] is a JSON string carrying what the full-screen screen needs
  /// (prayer key/label, the asset path for its karaoke text timing).
  Future<void> scheduleDaily({
    required String prayerKey,
    required int hour,
    required int minute,
    required AdhanMode mode,
    String? rawResource,
    String? customUri,
    required String payload,
    required String title,
  }) async {
    final id = idFor(prayerKey);
    final details = await _detailsFor(
      mode: mode,
      rawResource: rawResource,
      customUri: customUri,
    );
    await _plugin.zonedSchedule(
      id,
      title,
      'الله أكبر، حان وقت الصلاة',
      _nextInstanceOf(hour, minute),
      NotificationDetails(android: details),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
  }

  /// One-shot alarm a few seconds/minutes out — a real QA tool for verifying
  /// the whole pipeline without waiting for an actual prayer time. Uses its
  /// own notification id ([testIdFor]) so it never clobbers that prayer's
  /// real recurring daily alarm.
  Future<void> scheduleTest({
    required String prayerKey,
    required Duration from,
    required AdhanMode mode,
    String? rawResource,
    String? customUri,
    required String payload,
    required String title,
  }) async {
    final details = await _detailsFor(
      mode: mode,
      rawResource: rawResource,
      customUri: customUri,
    );
    await _plugin.zonedSchedule(
      testIdFor(prayerKey),
      title,
      'الله أكبر، حان وقت الصلاة',
      tz.TZDateTime.now(tz.local).add(from),
      NotificationDetails(android: details),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  /// Cancels the notification with [id] — stops its native sound too. [id]
  /// comes from the payload the full-screen screen (or a notification
  /// action) was opened with, so it always targets the alarm actually firing
  /// (a real daily one or a [scheduleTest] one), never a guess.
  // P3‑45: real-device testing found `flutter_local_notifications` throwing
  // ("Missing type parameter") from its own persisted scheduled-notification
  // storage on some devices/emulators carrying notification history from
  // earlier plugin versions. `stopById` in particular is the full-screen
  // alert's own Stop button — the one moment this absolutely cannot throw
  // and leave the user stuck with a blaring alarm and an unresponsive
  // button, so every one of these plugin calls is now best-effort.
  Future<void> stopById(int id) async {
    try {
      await _plugin.cancel(id);
    } catch (_) {
      // Best-effort: the caller (the full-screen alert's Stop button)
      // still navigates away regardless of whether the native
      // notification/sound itself could be cancelled.
    }
  }

  /// Re-posts notification [id] silenced, still ongoing — a real state
  /// change (the loud channel's sound stops because that notification id is
  /// replaced on the silent channel), not a cosmetic one.
  Future<void> muteById(int id, String? payload) async {
    try {
      final details = await _detailsFor(mode: AdhanMode.silent);
      await _plugin.show(
        id,
        'أذان — مكتوم',
        'الله أكبر، حان وقت الصلاة',
        NotificationDetails(android: details),
        payload: payload,
      );
    } catch (_) {
      // Best-effort — see `stopById`.
    }
  }

  Future<void> cancelPrayer(String prayerKey) async {
    try {
      await _plugin.cancel(idFor(prayerKey));
    } catch (_) {
      // Best-effort — see `stopById`.
    }
  }

  Future<void> cancelAll() async {
    for (final k in const ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']) {
      try {
        await _plugin.cancel(idFor(k));
        await _plugin.cancel(testIdFor(k));
      } catch (_) {
        // Best-effort — see `stopById`.
      }
    }
  }

  /// The notification id a prayer's real, recurring daily alarm is posted
  /// under.
  int idFor(String prayerKey) {
    const ids = {
      'fajr': 5001,
      'dhuhr': 5003,
      'asr': 5004,
      'maghrib': 5005,
      'isha': 5006,
    };
    return ids[prayerKey] ?? 5099;
  }

  /// The notification id [scheduleTest] uses for [prayerKey] — offset from
  /// the real daily id so a test firing never overwrites the real schedule.
  int testIdFor(String prayerKey) => idFor(prayerKey) + 900;

  /// Every id a real or test Adhan notification can ever be posted under —
  /// used only to recognise "this active notification is really an Adhan
  /// one", not to schedule anything.
  static const _knownAdhanIds = {
    5001, 5003, 5004, 5005, 5006, 5099, // real
    5901, 5903, 5904, 5905, 5906, 5999, // test (+900)
  };

  /// P3‑43 #2: a redundant, device/OEM-agnostic safety net. A full-screen
  /// Adhan alert is supposed to auto-navigate via the notification's own
  /// Intent (`getNotificationAppLaunchDetails`/`onNewIntent`) — confirmed
  /// structurally correct by reading the plugin's own Android source, and
  /// the OS-level permission gate (P3‑19/P3‑43 #2) confirmed the real
  /// blocker there. But a real Honor/Magic OS device live-tested this
  /// session still just resumed the app's last screen instead of the
  /// Adhan alert once that permission was granted — some device skins are
  /// known to intercept/rewrap a locked-screen full-screen-intent launch
  /// as a generic "bring this app forward" wake rather than faithfully
  /// re-delivering the original Intent's action/extras through Android's
  /// normal component lifecycle, which no app-level code can control.
  /// Rather than trust that journey on every device, this asks Android
  /// directly — "is there a real Adhan notification actually posted right
  /// now" — via the OS's own active-notifications list, true regardless
  /// of *how* the app came to the foreground. Call this on every app
  /// resume (see `AppShell`) as a fallback when the Intent-based path
  /// didn't already navigate.
  Future<String?> findActiveAdhanPayload() async {
    final active = await _plugin.getActiveNotifications();
    for (final n in active) {
      if (_knownAdhanIds.contains(n.id) &&
          n.payload != null &&
          n.payload!.isNotEmpty) {
        return n.payload;
      }
    }
    return null;
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}

/// Builds the JSON payload the full-screen Adhan screen reads. [notificationId]
/// is embedded so Stop/Mute in that screen target the exact notification
/// that is actually firing (a real daily alarm or a [AdhanAlarmService.scheduleTest] one)
/// instead of recomputing an id that might not match.
String buildAdhanPayload({
  required String prayerKey,
  required String prayerLabel,
  required int notificationId,
  String? previewAssetPath,
  String? videoPath,
}) => jsonEncode({
  'prayer': prayerKey,
  'label': prayerLabel,
  'id': notificationId,
  'asset': ?previewAssetPath,
  'video': ?videoPath,
});

/// Parses a payload built by [buildAdhanPayload].
class AdhanPayload {
  final String prayerKey;
  final String prayerLabel;
  final int notificationId;
  final String? previewAssetPath;

  /// P2‑7 — local path of a downloaded background clip for video-mode adhan.
  final String? videoPath;

  const AdhanPayload({
    required this.prayerKey,
    required this.prayerLabel,
    required this.notificationId,
    this.previewAssetPath,
    this.videoPath,
  });

  static AdhanPayload? tryParse(String? raw) {
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return AdhanPayload(
        prayerKey: m['prayer'] as String,
        prayerLabel: m['label'] as String,
        notificationId: m['id'] as int,
        previewAssetPath: m['asset'] as String?,
        videoPath: m['video'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}
