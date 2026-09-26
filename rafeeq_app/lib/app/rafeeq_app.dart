import 'package:rafeeq_app/core/theme/app_font.dart';
import 'package:rafeeq_app/core/theme/app_typography.dart';
import '../core/widgets/arrow_scrollbar.dart';
import '../core/utils/digits.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/native_strings.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/rgb_backdrop.dart';
import '../core/theme/theme_controller.dart';
import '../features/adhan/data/prayer_adjustments_provider.dart';
import '../features/fasting/data/fasting_reminder_provider.dart';
import '../features/tasbih_reminder/data/tasbih_reminder_provider.dart';
import '../features/home/data/prayer_controller.dart';
import '../core/services/quote_reminder_service.dart';
import '../features/quotes/data/quote_reminder_provider.dart';
import '../features/quotes/data/quote_repository.dart';
import '../features/quran/data/translation_lang_provider.dart';
import '../features/splash/presentation/screens/splash_screen.dart';
import 'app_locale_provider.dart';
import 'navigation.dart';
import '../core/services/sync_service.dart';
import '../core/utils/screen_class.dart';

/// Injected from main() so sync reads are possible anywhere.
final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPrefsProvider must be overridden in main');
});

/// The locale the last frame was built in, so a *change* can be told from a
/// rebuild. `RafeeqApp` is a `ConsumerWidget` and holds no state of its own;
/// this is a single string for the whole app and the only thing that reads it
/// is the callback below.
String? _lastLocale;

/// The locale the quote window was last armed in; see the callback below.
String? _lastQuoteLocale;

class RafeeqApp extends ConsumerWidget {
  const RafeeqApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final variant = ref.watch(themeControllerProvider);
    // The reader's interface font; the themes below are built with it.
    AppTypography.uiFamily = ref.watch(appFontProvider);

    // A new Hijri correction moves every planned fast by a day, so the
    // armed reminders are re-planned at once, not at the next launch.
    ref.listen<int>(
      prayerAdjustmentsProvider.select((a) => a.hijriOffsetDays),
      (prev, next) {
        if (prev == null || prev == next) return;
        final s = ref.read(fastingReminderProvider);
        if (s.anyOn) rearmFastingReminders(s, next);
      },
    );

    // P3‑57: the reader's translation follows the app's language. Done here
    // because this is the one widget that rebuilds on every locale change and
    // has `context.locale`; scheduled off the frame because it writes provider
    // state and touches SharedPreferences.
    final localeCode = context.locale.languageCode;
    // The numerals `trn()`/`pluralN()` shape. Set HERE, synchronously in
    // build and not in the post-frame callback below, because descendants
    // format strings during this very frame - a value one frame stale would
    // render the first screen after a language change in the old numerals.
    uiLanguageCode = localeCode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncServiceProvider).init();
      ref
          .read(selectedTranslationLangProvider.notifier)
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
      //
      // Only on launch and on a language change — this callback runs on
      // EVERY rebuild of the app (a theme switch is one), and each re-arm
      // used to race the settings chips. And the interval is read from the
      // setting once it has actually loaded: on the first frame the provider
      // still holds its default of 0.
      if (localeCode != _lastQuoteLocale) {
        // The fasting reminders' two-month window is topped up on the same
        // occasions, for the same two reasons: their text is frozen when
        // armed, and nothing else re-arms them while the app is closed.
        ref.read(fastingReminderProvider.notifier).loaded.then((s) {
          if (!s.anyOn) return;
          rearmFastingReminders(
            ref.read(fastingReminderProvider),
            ref.read(prayerAdjustmentsProvider).hijriOffsetDays,
          );
        });
        // Tasbih slots repeat daily on their own; re-arming here shifts the
        // rotation for the new day and re-words them in the new language.
        ref.read(tasbihReminderProvider.notifier).loaded.then((every) {
          if (every > 0) rearmTasbihReminders(every);
        });
        _lastQuoteLocale = localeCode;
        ref.read(quoteReminderProvider.notifier).loaded.then((every) async {
          if (every <= 0) return;
          final library = await ref.read(quoteLibraryProvider.future);
          // The owner may have changed it while the corpus loaded.
          final now = ref.read(quoteReminderProvider);
          if (now <= 0) return;
          await QuoteReminderService.instance.reschedule(
            library: library,
            everyMinutes: now,
            locale: localeCode,
          );
        });
      }
    });

    // Resolve the active variant into MaterialApp's theme slots. Only `rgb`
    // needs the animated backdrop; the other three are plain.
    final (ThemeData light, ThemeData dark, ThemeMode mode) = switch (variant) {
      ThemeVariant.system => (
        AppTheme.light(),
        AppTheme.dark(),
        ThemeMode.system,
      ),
      ThemeVariant.light => (
        AppTheme.light(),
        AppTheme.dark(),
        ThemeMode.light,
      ),
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
      builder: (context, child) {
        // Height is the scarce direction on a phone held sideways (< 480 dp):
        // every title bar there was 56 dp of a ~400 dp screen, pushing the
        // content down under «الأذكار» / «الصلاة» (owner's photos,
        // 2026-09-26: «ارفع الحاجز ... عشان يبقى فيه رووم أكتر للمحتوى»).
        // One override here shortens all of them - 44 dp, title a size down.
        Widget page = child!;
        if (ScreenClass.shortHeight(context)) {
          final theme = Theme.of(context);
          page = Theme(
            data: theme.copyWith(
              appBarTheme: theme.appBarTheme.copyWith(
                toolbarHeight: 44,
                titleTextStyle: (theme.appBarTheme.titleTextStyle ??
                        theme.textTheme.titleLarge)
                    ?.copyWith(fontSize: 17),
              ),
            ),
            child: page,
          );
        }
        return variant == ThemeVariant.rgb
            ? RgbScaffoldBackground(child: page)
            : page;
      },
      // P3‑49: the owner asked for his AI-generated splash video (Gemini
      // watermark now removed) put back. `SplashScreen` plays it, then
      // itself decides whether to hand off to onboarding (first run) or
      // straight to `AppShell` (returning user).
      home: const SplashScreen(),
    );
  }
}
