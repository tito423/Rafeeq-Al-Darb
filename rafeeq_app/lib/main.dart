import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

import 'app/rafeeq_app.dart';
import 'core/services/adhan_alarm_service.dart';
import 'core/services/sunan_suwar_reminder_service.dart';
import 'features/adhan/presentation/adhan_navigation.dart';
import 'features/sunan_suwar/presentation/sunan_suwar_navigation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // P3‑43 #12: the app's core UI font (Cairo) is now bundled locally under
  // assets/fonts/google_fonts/ (see pubspec.yaml/AppTypography) specifically
  // so this app never depends on a network fetch just to render its own
  // chrome text — disallowing runtime fetching turns a missing/renamed
  // weight into a loud, obvious exception instead of a silent fallback to
  // the OS's default font, which is what produced the broken/disconnected
  // Arabic letterforms the owner saw (a fallback font without proper
  // Arabic shaping standing in for Cairo while it was still downloading).
  GoogleFonts.config.allowRuntimeFetching = false;

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
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

  await AdhanAlarmService.instance.initialize();
  AdhanAlarmService.onOpenAdhan = openAdhanFromPayload;
  final coldLaunchPayload =
      await AdhanAlarmService.instance.consumeColdLaunchPayload();

  await SunanSuwarReminderService.instance.initialize();
  SunanSuwarReminderService.onOpenSurah = openSunanSuwarFromPayload;

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
        Locale('es'),
        Locale('ru'),
        Locale('pt'),
        Locale('fr'),
      ],
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
      child: ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(sharedPreferences),
        ],
        child: const RafeeqApp(),
      ),
    ),
  );

  // The app was launched by tapping an Adhan notification while fully
  // killed — the live tap callback (`onOpenAdhan`, wired above) only fires
  // for a running/backgrounded app, so a cold launch needs this one-time
  // check instead. Deferred a frame so the navigator is actually mounted.
  if (coldLaunchPayload != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      openAdhanFromPayload(coldLaunchPayload);
    });
  }
}
