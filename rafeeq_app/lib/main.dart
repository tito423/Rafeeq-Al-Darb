import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

import 'adhan_entry.dart';
import 'app/rafeeq_app.dart';
import 'core/i18n/supported_locales.dart';
import 'core/services/alarm_permissions_service.dart';
import 'core/services/quran_translation_store.dart';
import 'core/services/download_engine.dart';
import 'core/services/sunan_suwar_reminder_service.dart';
import 'core/services/notification_router.dart';
import 'core/services/quote_reminder_service.dart';
import 'features/quotes/presentation/quote_navigation.dart';
import 'features/sunan_suwar/presentation/sunan_suwar_navigation.dart';

/// The Adhan alert screen's Dart entrypoint, run by `AdhanActivity` (Kotlin)
/// in its own Flutter engine instead of [main].
///
/// It has to be declared *in this library*: Flutter compiles only what is
/// reachable from the app's entrypoint, so an alternate entrypoint living in
/// a file nothing imports would be dropped from the release snapshot and the
/// Activity would come up blank. `@pragma('vm:entry-point')` then keeps it
/// from being tree-shaken even though no Dart code calls it.
///
/// The body is one line on purpose - everything it needs lives in
/// `adhan_entry.dart`, which this library imports (and thereby compiles).
@pragma('vm:entry-point')
Future<void> adhanMain() => runAdhanAlertApp();

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  // P3‑56: hold the OS-drawn native splash on screen through the whole
  // bootstrap below (fonts, prefs, localization, timezone, alarm init) instead
  // of letting Flutter tear it down at its first frame — that early teardown,
  // before the Dart `SplashScreen`/video was ready, was the "icon → flash →
  // icon → video" glitch. `SplashScreen` lifts it (`FlutterNativeSplash
  // .remove()`) only once the video's first frame is painted (or, with no
  // video, once it's about to hand off), so the transition is seamless.
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // P3‑43 #12: the app's core UI font (Cairo) is now bundled locally under
  // assets/fonts/google_fonts/ (see pubspec.yaml/AppTypography) specifically
  // so this app never depends on a network fetch just to render its own
  // chrome text — disallowing runtime fetching turns a missing/renamed
  // weight into a loud, obvious exception instead of a silent fallback to
  // the OS's default font, which is what produced the broken/disconnected
  // Arabic letterforms the owner saw (a fallback font without proper
  // Arabic shaping standing in for Cairo while it was still downloading).
  GoogleFonts.config.allowRuntimeFetching = false;

  // P3‑45: real-device feedback — "rotation and orientation not working at
  // all". This used to hard-lock the whole app to portrait; every screen
  // uses ordinary Flutter layout (Column/ListView/Scaffold) that reflows
  // fine with more horizontal space, so there's no real reason to forbid
  // landscape app-wide. Left unset (no `setPreferredOrientations` call at
  // all) so the OS's own auto-rotate setting decides, same as almost every
  // other app — a user with auto-rotate off keeps their phone in portrait
  // without the app fighting them either way.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  final sharedPreferences = await SharedPreferences.getInstance();

  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'rafeeq.audio.channel',
      androidNotificationChannelName: 'Audio playback',
      androidNotificationOngoing: true,
    );
  } catch (_) {}

  // Preload translations (required by easy_localization).
  await EasyLocalization.ensureInitialized();
  try {
    await initializeDateFormatting('ar');
    tz.initializeTimeZones();
    final name = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(name));
  } catch (_) {}

  // The Adhan itself no longer boots anything here. Its alarms are armed
  // natively (AlarmManager.setAlarmClock), it fires into its own Kotlin
  // BroadcastReceiver + foreground service, and it renders in its own
  // Activity running the `adhanMain` entrypoint (lib/adhan_entry.dart) --
  // none of which needs the main app's engine to be alive, which is the
  // whole point. All that is left for main() is the notifications plugin
  // and the permission gates.
  await AlarmPermissionsService.instance.initialize();

  // Which downloaded Quran translations are already on disk. Cheap (one
  // SELECT over a tiny table) and needed before the reader's translation
  // picker can tell a downloaded language from one that still needs fetching.
  try {
    await QuranTranslationStore.instance.refreshInstalled();
  } catch (_) {}

  // Re-attach to any download the OS kept running while the app was gone.
  // `background_downloader` hands transfers to Android's own WorkManager, so a
  // surah (or a 100 MB pack) can finish while the app is closed — without this
  // the app would never learn that it did. Deliberately not awaited: it is a
  // reconciliation, not a prerequisite for the first frame.
  unawaited(DownloadEngine.resumeFromBackground());

  await SunanSuwarReminderService.instance.initialize();
  NotificationRouter.onSurah = openSunanSuwarFromPayload;

  // The Islamic-quote notification. The window is NOT re-armed here: the
  // interval lives in SharedPreferences and the corpus is an asset, and
  // `QuoteReminderStartup` re-arms once the widget tree is up and the app's
  // language is known, so the notification's title is in the language the
  // reader is actually using.
  await QuoteReminderService.instance.initialize();
  NotificationRouter.onQuote = openQuoteFromPayload;

  runApp(
    EasyLocalization(
      supportedLocales: kSupportedLocales,
      path: 'assets/translations',
      fallbackLocale: const Locale('ar'),
      // P3‑37: `startLocale` used to be hardcoded to Arabic, so a fresh
      // install always opened in Arabic regardless of the device's own
      // language — omitting it lets easy_localization detect the device's
      // system locale on the very first launch (matched against
      // `supportedLocales`, falling back to `fallbackLocale` above for any
      // device language this app doesn't ship a translation for). Once the
      // user picks a language explicitly (or this auto-detected default is
      // used once), `saveLocale: true` persists it — this only affects the
      // *very first* launch before anything is saved.
      saveLocale: true,
      // easy_localization defaults `ignorePluralRules` to TRUE, which means
      // `.plural()` only ever picks zero/one/two/other and the `few` and
      // `many` forms in every locale file are dead. Russian showed «7277
      // хадиса» and «97 главы» on emulator-5554 — both should take the
      // genitive plural («хадисов», «глав»), which is the `many` form, and
      // Arabic's own «{} آيات» / «{} آية» split had never been reached
      // either. With the real CLDR rules on, each locale gets the form its
      // language actually calls for.
      ignorePluralRules: false,
      child: ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(sharedPreferences),
        ],
        child: const RafeeqApp(),
      ),
    ),
  );

}
