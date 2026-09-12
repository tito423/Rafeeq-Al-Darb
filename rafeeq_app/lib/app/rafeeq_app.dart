import '../core/widgets/arrow_scrollbar.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/native_strings.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/rgb_backdrop.dart';
import '../core/theme/theme_controller.dart';
import '../features/home/data/prayer_controller.dart';
import '../core/services/quote_reminder_service.dart';
import '../features/quotes/data/quote_reminder_provider.dart';
import '../features/quotes/data/quote_repository.dart';
import '../features/quran/data/translation_lang_provider.dart';
import '../features/splash/presentation/screens/splash_screen.dart';
import 'app_locale_provider.dart';
import 'navigation.dart';

/// Injected from main() so sync reads are possible anywhere.
final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPrefsProvider must be overridden in main');
});

/// The locale the last frame was built in, so a *change* can be told from a
/// rebuild. `RafeeqApp` is a `ConsumerWidget` and holds no state of its own;
/// this is a single string for the whole app and the only thing that reads it
/// is the callback below.
String? _lastLocale;

class RafeeqApp extends ConsumerWidget {
  const RafeeqApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final variant = ref.watch(themeControllerProvider);

    // P3‑57: the reader's translation follows the app's language. Done here
    // because this is the one widget that rebuilds on every locale change and
    // has `context.locale`; scheduled off the frame because it writes provider
    // state and touches SharedPreferences.
    final localeCode = context.locale.languageCode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(selectedTranslationLangProvider.notifier)
          .followAppLocale(localeCode);
      // The strings Android renders itself — the three adhan notification
      // channels, the adhan alert's title/body/buttons, and the download
      // service's notification — were hardcoded Arabic in Kotlin, invisible
      // to `i18n_audit.py` because it only reads Dart. They are pushed from
      // here for the same reason the line above lives here: this is the one
      // widget that rebuilds on every locale change, so startup and a
      // language switch are the same code path.
      NativeStrings.sync();
      ref.read(appLocaleProvider.notifier).state = localeCode;
      // Anything already on screen was built in the previous language and
      // will never be rebuilt — a snackbar least of all. An undo offer for
      // something done before the switch is stale anyway.
      if (localeCode != _lastLocale) {
        final first = _lastLocale == null;
        _lastLocale = localeCode;
        rootScaffoldMessengerKey.currentState?.clearSnackBars();
        // The fifteen prayer reminders carry their title and body as literal
        // text inside AlarmManager — `.tr()` runs when they are *armed*, not
        // when they fire. Nothing re-armed them on a language change, so
        // switching to English left tomorrow's Fajr reminder saying
        // «اقترب موعد صلاة الفجر» until the next times fetch. Re-arm from the
        // cached times, which costs no network call. Not on the first frame:
        // there are no cached times yet and `PrayerController` is about to
        // arm them itself.
        if (!first) {
          ref.read(prayerControllerProvider.notifier).rescheduleFromCache();
          // And the CITY inside those reminders, which is reverse-geocoded
          // once per times fetch and otherwise never asked again. Without
          // this the notification keeps the place name in whatever language
          // the app happened to be in when the times were last fetched.
          ref.read(prayerControllerProvider.notifier).refreshPlaceName();
        }
      }
      // The quote window carries its title as literal text too, for the same
      // reason, and it is armed from here rather than from `main()` so it is
      // armed in the language the reader is actually using — and re-armed on
      // every launch, which is what keeps the rolling window topped up (see
      // `QuoteReminderService`'s doc on how long it lasts without the app).
      final every = ref.read(quoteReminderProvider);
      if (every > 0) {
        ref.read(quoteLibraryProvider.future).then((library) {
          QuoteReminderService.instance
              .reschedule(library: library, everyMinutes: every);
        });
      }
    });

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
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      title: 'app.name'.tr(),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: light,
      darkTheme: dark,
      themeMode: mode,
      scrollBehavior: const ArrowScrollBehavior(),
      builder: variant == ThemeVariant.rgb
          ? (context, child) => RgbScaffoldBackground(child: child!)
          : null,
      // P3‑49: the owner asked for his AI-generated splash video (Gemini
      // watermark now removed) put back. `SplashScreen` plays it, then
      // itself decides whether to hand off to onboarding (first run) or
      // straight to `AppShell` (returning user).
      home: const SplashScreen(),
    );
  }
}
