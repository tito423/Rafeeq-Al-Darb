import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/theme_provider.dart';
import '../core/localization/app_localizations.dart';
import '../core/localization/locale_provider.dart';
import '../features/splash/presentation/screens/splash_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Root application widget.
/// Watches [themeProvider] and [localeProvider] so changes propagate instantly app-wide.
class RafeeqApp extends ConsumerWidget {
  const RafeeqApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final currentLocale = ref.watch(localeProvider);

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'رفيق الدرب',
      debugShowCheckedModeBanner: false,

      // ── Localization (16 Languages) ───────────────────────────
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar'), // Arabic
        Locale('en'), // English
        Locale('fr'), // French
        Locale('id'), // Indonesian
        Locale('ms'), // Malay
        Locale('tr'), // Turkish
        Locale('ur'), // Urdu
        Locale('hi'), // Hindi
        Locale('bn'), // Bengali
        Locale('fa'), // Persian
        Locale('es'), // Spanish
        Locale('ru'), // Russian
        Locale('zh'), // Chinese
        Locale('de'), // German
        Locale('it'), // Italian
        Locale('pt'), // Portuguese
        Locale('ha'), // Hausa
      ],
      locale: currentLocale,

      // ── Dynamic theming ─────────────────────────────────────────────────
      themeMode: themeState.themeMode,
      theme: themeState.lightTheme,
      darkTheme: themeState.darkTheme,

      // ── Root route ──────────────────────────────────────────────────────
      home: const SplashScreen(),
    );
  }
}
