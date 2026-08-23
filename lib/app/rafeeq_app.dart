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

      // ── Localization (Arabic, English, French) ───────────────────────────
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
        Locale('fr'),
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
