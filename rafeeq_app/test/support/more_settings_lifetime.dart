import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rafeeq_app/core/config/prefs_provider.dart';
import 'package:rafeeq_app/core/theme/app_theme.dart';
import 'package:rafeeq_app/core/theme/theme_controller.dart';
import 'package:rafeeq_app/features/more/presentation/widgets/more_group.dart';
import 'package:rafeeq_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:rafeeq_app/features/splash/data/splash_video_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Translations extends AssetLoader {
  const _Translations(this.documents);
  final Map<String, Map<String, dynamic>> documents;
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      documents[locale.languageCode]!;
}

/// Actual SettingsBody, MoreGroup, pushed section and persistent notifiers.
/// Preference writes use the in-memory store so owner settings stay intact.
void moreSettingsLifetimeTests({
  Future<void> Function()? screenshotReady,
  Future<void> Function()? themeScreenshotReady,
}) {
  const languages = ['ar', 'en', 'fr', 'es', 'pt', 'ru', 'ur'];
  final documents = <String, Map<String, dynamic>>{};
  late ProviderContainer container;
  late SharedPreferences prefs;
  final navigation = GlobalKey<NavigatorState>();
  final runtimeFonts = GoogleFonts.config.allowRuntimeFetching;
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    AppTheme.light();
    AppTheme.dark();
    await GoogleFonts.pendingFonts();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    for (final language in languages) {
      documents[language] =
          jsonDecode(
                await rootBundle.loadString(
                  'assets/translations/$language.json',
                ),
              )
              as Map<String, dynamic>;
    }
  });
  tearDownAll(() => GoogleFonts.config.allowRuntimeFetching = runtimeFonts);
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'splash_video_enabled_v1': false,
      'splash_video_sound_v1': false,
      'theme_variant_v2': 'light',
    });
    prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
  });
  tearDown(() => container.dispose());

  Future<void> show(WidgetTester tester, String language) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: EasyLocalization(
          key: UniqueKey(),
          supportedLocales: [
            for (final language in languages) Locale(language),
          ],
          startLocale: Locale(language),
          path: '.',
          assetLoader: _Translations(documents),
          saveLocale: false,
          child: Consumer(
            builder: (context, ref, child) => MaterialApp(
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: ref.watch(themeControllerProvider) == ThemeVariant.dark
                  ? ThemeMode.dark
                  : ThemeMode.light,
              navigatorKey: navigation,
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              home: Scaffold(
                body: ListView(
                  children: [
                    MoreGroup(
                      title: 'settings.title'.tr(),
                      subtitle: '',
                      icon: Icons.settings,
                      children: const [SettingsBody()],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('settings.title'.tr()));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsBody), findsOneWidget);
  }

  Future<Element> openSection(WidgetTester tester, String key) async {
    final origin = tester.element(find.byType(SettingsBody));
    final heading = find.text(key.tr());
    await tester.ensureVisible(heading);
    await tester.pumpAndSettle();
    await tester.tap(heading);
    // MoreGroup folds at 450ms; exercise the page well after that boundary.
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
    expect(navigation.currentState!.canPop(), true);
    return origin;
  }

  Future<void> backAndCheckFolded(WidgetTester tester, Element origin) async {
    navigation.currentState!.pop();
    await tester.pumpAndSettle();
    expect(navigation.currentState!.canPop(), false);
    expect(find.byType(SettingsBody), findsNothing);
    expect(origin.mounted, false);
    expect(tester.takeException(), isNull);
  }

  for (final language in languages) {
    testWidgets(
      'A36 $language splash page saves and rebuilds after group folds',
      (tester) async {
        await show(tester, language);
        final origin = await openSection(tester, 'settings.splash_section');
        final toggle = find.byType(SwitchListTile).hitTestable().first;
        expect(tester.widget<SwitchListTile>(toggle).value, false);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(container.read(splashVideoEnabledProvider), true);
        expect(prefs.getBool('splash_video_enabled_v1'), true);
        expect(tester.widget<SwitchListTile>(toggle).value, true);
        expect(find.text('settings.splash_video_sound'.tr()), findsOneWidget);
        expect(origin.mounted, true);
        if (language == 'en' && screenshotReady != null) {
          await screenshotReady();
        }
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(container.read(splashVideoEnabledProvider), false);
        expect(prefs.getBool('splash_video_enabled_v1'), false);
        expect(find.text('settings.splash_video_sound'.tr()), findsNothing);
        await backAndCheckFolded(tester, origin);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
    testWidgets(
      'A36 $language theme page updates both selections after group folds',
      (tester) async {
        await show(tester, language);
        final origin = await openSection(tester, 'settings.theme');
        if (language == 'en' && themeScreenshotReady != null) {
          await themeScreenshotReady();
        }
        // RawChip can hit its outer InkWell without hitting the label's
        // RenderParagraph on Android. Tap the actual interactive control.
        final darkChip = find.widgetWithText(ChoiceChip, 'settings.dark'.tr());
        await tester.ensureVisible(darkChip);
        await tester.pumpAndSettle();
        await tester.tap(darkChip.hitTestable());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(container.read(themeControllerProvider), ThemeVariant.dark);
        expect(prefs.getString('theme_variant_v2'), 'dark');
        final dark = find
            .widgetWithText(ChoiceChip, 'settings.dark'.tr())
            .hitTestable();
        expect(tester.widget<ChoiceChip>(dark).selected, true);
        expect(origin.mounted, true);
        final lightChip = find.widgetWithText(
          ChoiceChip,
          'settings.light'.tr(),
        );
        await tester.ensureVisible(lightChip);
        await tester.pumpAndSettle();
        await tester.tap(lightChip.hitTestable());
        await tester.pumpAndSettle();
        expect(container.read(themeControllerProvider), ThemeVariant.light);
        expect(prefs.getString('theme_variant_v2'), 'light');
        await backAndCheckFolded(tester, origin);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
  testWidgets(
    'A36 ordinary group collapse still releases settings immediately',
    (tester) async {
      await show(tester, 'en');
      final origin = tester.element(find.byType(SettingsBody));
      await tester.ensureVisible(find.text('settings.title'.tr()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('settings.title'.tr()));
      await tester.pumpAndSettle();
      expect(origin.mounted, false);
      expect(find.byType(SettingsBody), findsNothing);
      expect(navigation.currentState!.canPop(), false);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
