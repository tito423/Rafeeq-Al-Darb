import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

import 'app/rafeeq_app.dart';
import 'core/services/adhan_alarm_service.dart';
import 'features/adhan/presentation/adhan_navigation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('ar'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('ar'),
      startLocale: const Locale('ar'),
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
