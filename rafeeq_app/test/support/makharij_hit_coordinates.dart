import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rafeeq_app/core/theme/app_theme.dart';
import 'package:rafeeq_app/features/tajweed/data/makharij.dart';
import 'package:rafeeq_app/features/tajweed/presentation/widgets/makharij_diagram.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Translations extends AssetLoader {
  const _Translations(this.documents);
  final Map<String, Map<String, dynamic>> documents;
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      documents[locale.languageCode]!;
}

void makharijHitCoordinateTests({Future<void> Function()? screenshotReady}) {
  const languages = ['ar', 'en', 'fr', 'es', 'pt', 'ru', 'ur'];
  final documents = <String, Map<String, dynamic>>{};
  final originalRuntimeFonts = GoogleFonts.config.allowRuntimeFetching;
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    AppTheme.light();
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
  tearDownAll(
    () => GoogleFonts.config.allowRuntimeFetching = originalRuntimeFonts,
  );

  Future<void> verify(
    WidgetTester tester, {
    required String language,
    required String target,
    double progress = 1,
    bool selected = true,
    bool capture = false,
  }) async {
    Makhraj? current = selected
        ? makharij.firstWhere((m) => m.id == 'shafa_bmw')
        : null;
    Makhraj? picked;
    try {
      await tester.pumpWidget(
        EasyLocalization(
          key: UniqueKey(),
          supportedLocales: [
            for (final language in languages) Locale(language),
          ],
          startLocale: Locale(language),
          saveLocale: false,
          path: '.',
          assetLoader: _Translations(documents),
          child: Builder(
            builder: (context) => MaterialApp(
              theme: AppTheme.light(),
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 300,
                    child: StatefulBuilder(
                      builder: (context, setState) => MakharijDiagram(
                        selected: current,
                        onPick: (m) => setState(() {
                          picked = m;
                          current = m;
                        }),
                        articulation: AlwaysStoppedAnimation(progress),
                        flow: const AlwaysStoppedAnimation(0),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final stack = find
          .descendant(
            of: find.byType(MakharijDiagram),
            matching: find.byType(Stack),
          )
          .first;
      final box = tester.renderObject<RenderBox>(stack);
      final marker = MakharijDiagram.points[target]!;
      // Use the real painted stack's transform, not a duplicate zoom formula.
      final visible = box.localToGlobal(
        Offset(marker.dx * box.size.width, marker.dy * box.size.height),
      );
      await tester.tapAt(visible);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(picked?.id, target);
      expect(
        tester
            .widget<MakharijDiagram>(find.byType(MakharijDiagram))
            .selected
            ?.id,
        target,
      );
      if (capture && screenshotReady != null) {
        await screenshotReady();
      }
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  }

  for (final language in languages) {
    testWidgets(
      'A41 $language zoomed kaf marker picks kaf',
      (tester) => verify(
        tester,
        language: language,
        target: 'lisan_aqsa_kaf',
        capture: language == 'en',
      ),
    );
  }
  for (final target in MakharijDiagram.points.keys) {
    testWidgets(
      'A41 zoomed marker $target selects its own entry',
      (tester) => verify(tester, language: 'en', target: target),
    );
  }
  for (final progress in [0.0, 0.5]) {
    testWidgets(
      'A41 ordinary kaf control at progress $progress',
      (tester) => verify(
        tester,
        language: 'en',
        target: 'lisan_aqsa_kaf',
        progress: progress,
      ),
    );
  }
  testWidgets(
    'A41 unselected diagram keeps ordinary hit coordinates',
    (tester) => verify(
      tester,
      language: 'en',
      target: 'lisan_aqsa_kaf',
      selected: false,
    ),
  );
}
