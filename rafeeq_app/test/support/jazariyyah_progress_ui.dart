import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rafeeq_app/core/theme/app_theme.dart';
import 'package:rafeeq_app/features/tajweed/data/bundled_matn.dart';
import 'package:rafeeq_app/features/tajweed/data/jazariyyah_course.dart';
import 'package:rafeeq_app/features/tajweed/presentation/screens/jazariyyah_level_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Translations extends AssetLoader {
  const _Translations(this.document);
  final Map<String, dynamic> document;
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      document;
}

void jazariyyahProgressUiTests({
  Future<void> Function(String)? screenshotReady,
}) {
  for (final language in ['en', 'ar', 'fr', 'es', 'pt', 'ru', 'ur']) {
    testWidgets('A40 real lesson button counts only one lesson ($language)', (
      tester,
    ) async {
      final previousFonts = GoogleFonts.config.allowRuntimeFetching;
      GoogleFonts.config.allowRuntimeFetching = false;
      addTearDown(
        () => GoogleFonts.config.allowRuntimeFetching = previousFonts,
      );
      SharedPreferences.setMockInitialValues({});
      late Map<String, dynamic> translations;
      late Widget screen;
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.runAsync(() async {
        await EasyLocalization.ensureInitialized();
        translations =
            jsonDecode(
                  await rootBundle.loadString(
                    'assets/translations/$language.json',
                  ),
                )
                as Map<String, dynamic>;
        // Load the actual bundled book, without substituting its paragraphs.
        await bundledMatn(jazariyyahBook);
        await container.read(jazariyyahBookProvider.future);
        await container.read(jazariyyahSharhProvider.future);
        container.read(jazariyyahProgressProvider);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        final theme = AppTheme.light();
        await GoogleFonts.pendingFonts();
        screen = UncontrolledProviderScope(
          container: container,
          child: EasyLocalization(
            supportedLocales: [Locale(language)],
            startLocale: Locale(language),
            saveLocale: false,
            path: '.',
            assetLoader: _Translations(translations),
            child: Builder(
              builder: (context) => MaterialApp(
                theme: theme,
                locale: context.locale,
                supportedLocales: context.supportedLocales,
                localizationsDelegates: context.localizationDelegates,
                home: const JazariyyahLevelScreen(),
              ),
            ),
          ),
        );
      });
      await tester.pumpWidget(screen);
      await tester.pumpAndSettle();
      final firstWarning = find.byWidgetPredicate(
        (widget) =>
            widget is ExpansionTile &&
            widget.title is Text &&
            (widget.title as Text).data == jazariyyahLessons[7].title &&
            widget.subtitle is Text &&
            ((widget.subtitle as Text).data ?? '').contains(
              language == 'ar' ? '٧٠' : '70',
            ),
      );
      // The title repeats; the real source page range selects lesson eight.
      await tester.scrollUntilVisible(
        firstWarning,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(
        find.descendant(
          of: firstWarning,
          matching: find.text(jazariyyahLessons[7].title),
        ),
      );
      await tester.pumpAndSettle();
      final button = tester.widget<TextButton>(
        find
            .descendant(
              of: firstWarning,
              matching: find.byWidgetPredicate(
                (widget) => widget is TextButton,
              ),
            )
            .last,
      );
      // Execute the product callback, including its persistence path.
      await tester.runAsync(() async {
        button.onPressed!();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, 10000));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator).first,
            )
            .value,
        closeTo(1 / 18, 0.00001),
      );
      expect(tester.takeException(), isNull);
      await screenshotReady?.call(language);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
