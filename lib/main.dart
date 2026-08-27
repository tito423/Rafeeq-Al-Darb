import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'app/rafeeq_app.dart';
import 'core/services/notification_service.dart';
import 'features/prayer/presentation/providers/prayer_settings_provider.dart';

import 'package:flutter_native_splash/flutter_native_splash.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Essential initializations needed before first frame
  await Firebase.initializeApp();
  final sharedPreferences = await SharedPreferences.getInstance();
  
  // Start the app
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const RafeeqApp(),
    ),
  );

  // Defer heavy non-essential initializations until after the first frame is rendered
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await _deferredInitializations();
  });
}

Future<void> _deferredInitializations() async {
  try {
    await initializeDateFormatting('ar');
    tz.initializeTimeZones();
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));
  } catch (e) {
    debugPrint('Could not initialize date formatting or timezone: $e');
  }

  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
      androidNotificationChannelName: 'Audio playback',
      androidNotificationOngoing: true,
    );
  } catch (e) {
    debugPrint('Could not init background audio: $e');
  }

  try {
    await NotificationService().initialize();
  } catch (e) {
    debugPrint('Could not init notification service: $e');
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
}
