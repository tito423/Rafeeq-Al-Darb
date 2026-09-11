import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'notification_router.dart';
import 'package:permission_handler/permission_handler.dart';

import 'adhan_native.dart';

/// The permission gates the Adhan actually depends on, and nothing else.
///
/// This is what is left of the old `AdhanAlarmService` after the Adhan was
/// rebuilt on a native alarm pipeline. Scheduling, playback, the alert
/// notification and its Stop/Mute actions now all live in Kotlin
/// (`android/app/src/main/kotlin/.../adhan/`) and are reached through
/// [AdhanNative] — the previous design tried to do all of that from Dart
/// through `flutter_local_notifications`, which could not work when the app
/// was killed, because a scheduled notification fires through a plain Java
/// broadcast receiver that never starts the Dart VM.
///
/// What genuinely still belongs in Dart is asking the user for the four
/// grants the adhan needs, since that is a UI concern:
///
///  * POST_NOTIFICATIONS (Android 13+) — the alert has to be postable;
///  * SCHEDULE_EXACT_ALARM (Android 12+) — without it the alarm is
///    approximate *and* loses the OS exemption that lets the alert draw over
///    the lock screen;
///  * the full-screen-intent grant (Android 14+, see `AdhanUriBridge`);
///  * a battery-optimization exemption, so the process is not frozen before
///    the alarm lands.
class AlarmPermissionsService {
  AlarmPermissionsService._();
  static final AlarmPermissionsService instance = AlarmPermissionsService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Initialises the notifications plugin once, at startup, so the other
  /// notification surfaces the app has (the persistent next-prayer card, the
  /// azkar and sunan reminders) and the permission requests below have a
  /// live plugin to talk to. It deliberately registers no tap handlers of
  /// its own — the Adhan no longer posts anything through this plugin.
  Future<void> initialize() async {
    if (_ready) return;
    // Through the router: this used to call `initialize` with no tap
    // handler, which CLEARS whatever handler was installed before it. See
    // `NotificationRouter`.
    await NotificationRouter.instance.ensureInitialized();
    _ready = true;
  }

  /// Every startup grant, asked **once per launch and only once the user is
  /// actually inside the app** — location first, then notifications and the
  /// exact-alarm gate.
  ///
  /// WHERE THIS IS CALLED FROM, AND WHY IT MOVED.
  /// It used to fire from `SplashScreen._proceed`, 900 ms after the hand-off,
  /// so that no dialog could cover the splash video. Timed on a **fresh
  /// install** (`dumpsys window` polled every 200 ms plus screenshots): the
  /// splash ended at ~12 s, the onboarding screen «اختر مصحفك» came up at
  /// ~13 s, and the location dialog landed at ~15 s — **on top of the
  /// onboarding**, while the user was choosing a mushaf. The splash was never
  /// the screen being covered.
  ///
  /// So it is asked from `AppShell`'s first frame instead, which is the one
  /// point both paths pass through: splash → shell for a returning user, and
  /// splash → onboarding → shell on a first run. Nothing the app does in its
  /// first seconds depends on these grants.
  bool _askedThisLaunch = false;

  Future<void> requestStartupGrants() async {
    if (_askedThisLaunch) return;
    _askedThisLaunch = true;
    try {
      // Location first — the owner asked for it to be the first prompt.
      if (await Geolocator.checkPermission() == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
    } catch (_) {
      // Best-effort: prayer times fall back to the cached fix without it.
    }
    await requestStartupPermissions();
    // «أول ما ينزل التطبيق اطلب الإذن ده» — the phone's audio, for the
    // Qur'an player's device files, asked right after the others.
    try {
      await [Permission.audio, Permission.storage].request();
    } catch (_) {}
  }

  /// Notification + exact-alarm prompts. Safe to call more than once — each
  /// request no-ops if already granted.
  Future<void> requestStartupPermissions() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();
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

  /// Whether the OS will honour an *exact* alarm for this app right now.
  /// Answered by the native scheduler, which is the layer that actually
  /// arms them.
  Future<bool> canScheduleExactAlarms() => AdhanNative.canScheduleExact();
}
