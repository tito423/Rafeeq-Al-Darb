import 'package:geolocator/geolocator.dart';
import 'notification_router.dart';
import 'package:permission_handler/permission_handler.dart';

import 'adhan_native.dart';
import 'adhan_uri_bridge.dart';

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
/// The five the first-run page lists, in the order it lists them.
enum AppPermission {
  location,
  notifications,
  exactAlarms,
  audio,
  battery,
  /// «اعرض اذن شاشة الاذان الكاملة مع شاشة الاذونات». Android 14
  /// took `USE_FULL_SCREEN_INTENT` away from apps that are not
  /// alarms or calls, and without it the adhan cannot take the
  /// lock screen - it becomes a notification like any other. It
  /// has no `permission_handler` entry; `AdhanUriBridge` asks the
  /// platform and opens its settings page.
  fullScreen,
}

class AlarmPermissionsService {
  AlarmPermissionsService._();
  static final AlarmPermissionsService instance = AlarmPermissionsService._();

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
    // ONE ask. It used to ask through the notifications plugin and then, if
    // the answer was still «denied» - which is what «Don't allow» leaves -
    // ask again through permission_handler: two dialogs back to back on
    // emulator-5554 (2026-09-24), and Android marks a second refusal as
    // final (USER_FIXED), so the reader could never be asked again.
    await Permission.notification.request();
    if (await Permission.scheduleExactAlarm.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }
  }

  /// ── ONE PERMISSION AT A TIME ───────────────────────────────────────
  ///
  /// «المفروض ان لما اضغط على اسم اذن يطلب الاذن ويعطيني علامة صح مش ابقى
  /// صفحة شكليه بس خاصة اذن البطاريية». `requestStartupGrants` fires the
  /// whole sequence, which is right for one button and wrong for a list:
  /// a row the reader taps has to ask for ITS permission and then show
  /// whether it was granted. Battery in particular was never in that
  /// sequence at all - it has its own dialog - so the row for it was
  /// decoration.
  Future<bool> isGranted(AppPermission which) async {
    try {
      return switch (which) {
        AppPermission.location => await Geolocator.checkPermission() !=
                LocationPermission.denied &&
            await Geolocator.checkPermission() !=
                LocationPermission.deniedForever,
        AppPermission.notifications => await Permission.notification.isGranted,
        AppPermission.exactAlarms =>
          await Permission.scheduleExactAlarm.isGranted,
        AppPermission.audio => await Permission.audio.isGranted,
        AppPermission.battery =>
          await Permission.ignoreBatteryOptimizations.isGranted,
        AppPermission.fullScreen =>
          await AdhanUriBridge.canUseFullScreenIntent() ?? true,
      };
    } catch (_) {
      return false;
    }
  }

  /// Asks for one, and answers whether it is granted afterwards. Every call
  /// is wrapped: a platform that has no such permission must not take the
  /// page down with it.
  Future<bool> request(AppPermission which) async {
    try {
      switch (which) {
        case AppPermission.location:
          await Geolocator.requestPermission();
        case AppPermission.notifications:
          // One ask - see [requestStartupPermissions].
          await Permission.notification.request();
        case AppPermission.exactAlarms:
          await Permission.scheduleExactAlarm.request();
        case AppPermission.audio:
          await [Permission.audio, Permission.storage].request();
        case AppPermission.battery:
          await Permission.ignoreBatteryOptimizations.request();
        case AppPermission.fullScreen:
          // A settings screen, not a dialog: the page re-reads
          // every status on resume, which is when the answer
          // exists.
          await AdhanUriBridge.openFullScreenIntentSettings();
      }
    } catch (_) {
      // Best effort: the row simply stays unticked.
    }
    return isGranted(which);
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
