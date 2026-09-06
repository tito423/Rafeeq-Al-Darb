import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/models/adhan_mode.dart';
import 'core/services/adhan_native.dart';
import 'core/theme/app_colors.dart';
import 'features/adhan/presentation/screens/azan_player_screen.dart';

/// Boots the Adhan alert screen as its own miniature Flutter app.
///
/// Called by `adhanMain` in `main.dart` — the `@pragma('vm:entry-point')`
/// function `AdhanActivity` (Kotlin) runs instead of `main()`. The entrypoint
/// itself has to live in `main.dart`'s own library, because Dart only
/// compiles libraries reachable from the app's entrypoint and an alternate
/// entrypoint sitting in an otherwise-unreferenced file would be silently
/// dropped from the release snapshot; `main.dart` imports this file, which
/// makes everything here reachable.
///
/// Running a separate, tiny app is deliberate: the alert has to be on screen
/// over the lock screen a moment after the alarm fires, and it must not
/// depend on — or disturb — the main app's navigation state, providers,
/// background-audio session or download engine. So it boots only the
/// localization bundle (the screen has a handful of visible strings) and the
/// player itself.
///
/// The adhan's *sound* is already playing before this ever runs —
/// `AdhanService` starts it natively the instant the alarm fires — so a slow
/// first frame can delay the picture but never the adhan.
///
/// The Activity passes the firing's details as the initial route,
/// `/azan?d=<url-encoded JSON>`; Flutter surfaces that as
/// `PlatformDispatcher.defaultRouteName`.
Future<void> runAdhanAlertApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  await EasyLocalization.ensureInitialized();

  final spec = _specFromRoute(PlatformDispatcher.instance.defaultRouteName);

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
      saveLocale: true,
      child: _AdhanAlertApp(spec: spec),
    ),
  );
}

/// Decodes the route `AdhanActivity.routeFor` built. A malformed or missing
/// route still yields a usable screen (the karaoke text on the gradient) —
/// the alert must never be a blank rectangle over someone's lock screen.
AdhanSpec _specFromRoute(String route) {
  try {
    final uri = Uri.parse(route);
    final raw = uri.queryParameters['d'];
    if (raw != null && raw.isNotEmpty) {
      return AdhanSpec.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }
  } catch (_) {
    // fall through to the safe default below
  }
  return const AdhanSpec(
    prayerKey: 'dhuhr',
    prayerLabel: 'الصلاة',
    mode: AdhanMode.full,
    soundType: AdhanSoundType.none,
    soundValue: null,
  );
}

class _AdhanAlertApp extends StatelessWidget {
  final AdhanSpec spec;

  const _AdhanAlertApp({required this.spec});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.night,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.gold,
          brightness: Brightness.dark,
        ),
      ),
      home: AzanPlayerScreen(spec: spec, playerMode: AzanPlayerMode.live),
    );
  }
}
