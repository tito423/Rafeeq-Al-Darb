import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/rgb_backdrop.dart';
import '../core/theme/theme_controller.dart';
import '../features/onboarding/data/onboarding_state.dart';
import '../features/onboarding/presentation/screens/onboarding_screen.dart';
import 'navigation.dart';
import 'shell/app_shell.dart';

/// Injected from main() so sync reads are possible anywhere.
final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPrefsProvider must be overridden in main');
});

class RafeeqApp extends ConsumerWidget {
  const RafeeqApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final variant = ref.watch(themeControllerProvider);

    // Resolve the active variant into MaterialApp's theme slots. Only `rgb`
    // needs the animated backdrop; the other three are plain.
    final (ThemeData light, ThemeData dark, ThemeMode mode) = switch (variant) {
      ThemeVariant.system => (AppTheme.light(), AppTheme.dark(), ThemeMode.system),
      ThemeVariant.light => (AppTheme.light(), AppTheme.dark(), ThemeMode.light),
      ThemeVariant.dark => (AppTheme.light(), AppTheme.dark(), ThemeMode.dark),
      ThemeVariant.rgb => (AppTheme.rgb(), AppTheme.rgb(), ThemeMode.dark),
    };

    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'app.name'.tr(),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: light,
      darkTheme: dark,
      themeMode: mode,
      builder: variant == ThemeVariant.rgb
          ? (context, child) => RgbScaffoldBackground(child: child!)
          : null,
      // P3‑45: the owner asked for the branded splash screen (video +
      // hand-built lattice/badge fallback) removed outright — straight to
      // onboarding (first run) or `AppShell` (returning user), no brand
      // pause in between. `onboardingCompletedProvider` is a synchronous
      // SharedPreferences read (see its own doc), so this decision needs
      // no loading state of its own.
      home: ref.watch(onboardingCompletedProvider)
          ? AppShell(key: ValueKey(context.locale.languageCode))
          : const OnboardingScreen(),
    );
  }
}
