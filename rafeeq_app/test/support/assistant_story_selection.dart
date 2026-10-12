import 'dart:async';
import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rafeeq_app/app/navigation.dart';
import 'package:rafeeq_app/core/db/quran_repository.dart';
import 'package:rafeeq_app/core/theme/app_theme.dart';
import 'package:rafeeq_app/features/assistant/data/assistant_intent.dart';
import 'package:rafeeq_app/features/assistant/data/assistant_lexicon.dart';
import 'package:rafeeq_app/features/assistant/presentation/assistant_sheet.dart';
import 'package:rafeeq_app/features/kids/data/kids_stories.dart';
import 'package:rafeeq_app/features/kids/presentation/kids_story_player_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

/// Hold only the video platform's initialization, so routing can be observed
/// without fetching, decoding or claiming to hear a story's video.
class _PendingVideo extends VideoPlayerPlatform {
  final events = <int, StreamController<VideoEvent>>{};
  final disposed = <int>[];
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = events.length + 1;
    events[id] = StreamController<VideoEvent>.broadcast();
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => events[playerId]!.stream;
  @override
  Future<void> dispose(int playerId) async => disposed.add(playerId);
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
}

class _Wake extends WakelockPlusPlatformInterface {
  @override
  Future<void> toggle({required bool enable}) async {}
}

class _Translations extends AssetLoader {
  const _Translations(this.documents);
  final Map<String, Map<String, dynamic>> documents;
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      documents[locale.languageCode]!;
}

void assistantStorySelectionTests({
  required Future<QuranRepository> Function() openRepository,
  required Future<void> Function() closeRepository,
  Future<void> Function()? screenshotReady,
}) {
  const languages = ['ar', 'en', 'fr', 'es', 'pt', 'ru', 'ur'];
  const stories = {
    'ibrahim': AssistantScreen.kidsStoryIbrahim,
    'sulayman': AssistantScreen.kidsStorySulayman,
    'ihya': AssistantScreen.kidsStoryIhya,
    'hudhud': AssistantScreen.kidsStoryHudhud,
  };
  final documents = <String, Map<String, dynamic>>{};
  late AssistantParser parser;
  final previousFonts = GoogleFonts.config.allowRuntimeFetching;
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    AppTheme.light();
    await GoogleFonts.pendingFonts();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    await kidsCaptionTranslations();
    for (final language in languages) {
      documents[language] =
          jsonDecode(
                await rootBundle.loadString(
                  'assets/translations/$language.json',
                ),
              )
              as Map<String, dynamic>;
    }
    final repository = await openRepository();
    final surahs = await repository.surahs();
    expect(surahs, hasLength(114));
    final labels = labelsFrom(documents.values);
    parser = AssistantParser(
      AssistantCatalog(
        surahs: [for (final surah in surahs) surah.nameAr],
        surahsLatin: [for (final surah in surahs) surah.nameEn],
        screenLabels: labels.screens,
        settingLabels: labels.settings,
        optionLabels: labels.options,
        settingSections: labels.sections,
      ),
    );
  });
  tearDownAll(() async {
    await closeRepository();
    GoogleFonts.config.allowRuntimeFetching = previousFonts;
  });

  for (final entry in {
    'افتح قصة إبراهيم والطيور': AssistantScreen.kidsStoryIhya,
    'افتح قصة سليمان والهدهد': AssistantScreen.kidsStoryHudhud,
    'شغل قصة إبراهيم والطيور': AssistantScreen.kidsStoryIhya,
    'شغل قصة سليمان والهدهد': AssistantScreen.kidsStoryHudhud,
    'افتح قصة إبراهيم': AssistantScreen.kidsStoryIbrahim,
    'افتح قصة سليمان': AssistantScreen.kidsStorySulayman,
    'قصة موسى الرضيع': AssistantScreen.kidsStoryMusaBaby,
    'قصة ضيوف إبراهيم': AssistantScreen.kidsStoryDayf,
    'قصص الأنبياء': AssistantScreen.kidsStories,
  }.entries) {
    test('A32 original alias ${entry.key}', () {
      expect(
        parser.parse(entry.key),
        isA<OpenScreenIntent>().having(
          (intent) => intent.screen,
          'selected story',
          entry.value,
        ),
      );
    });
  }
  for (final language in languages) {
    for (final entry in stories.entries) {
      test('A32 $language original localized ${entry.key} title', () {
        final title = lookup(documents[language]!, 'kids.story_${entry.key}')!;
        expect(
          parser.parse(title),
          isA<OpenScreenIntent>().having(
            (intent) => intent.screen,
            'selected localized story',
            entry.value,
          ),
        );
      });
    }
  }

  Future<void> ticks(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 200));
  }

  for (final language in languages) {
    for (final id in ['ihya', 'hudhud']) {
      testWidgets('A32 $language selected $id opens actual story route', (
        tester,
      ) async {
        if (tester.binding is! LiveTestWidgetsFlutterBinding) {
          tester.view.physicalSize = const Size(360, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
        }
        final previousWake = WakelockPlusPlatformInterface.instance;
        final previousCachedWake = wakelockPlusPlatformInstance;
        final wake = _Wake();
        WakelockPlusPlatformInterface.instance = wake;
        wakelockPlusPlatformInstance = wake;
        final previousVideo = VideoPlayerPlatform.instance;
        final video = _PendingVideo();
        VideoPlayerPlatform.instance = video;
        final container = ProviderContainer();
        try {
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: EasyLocalization(
                key: UniqueKey(),
                supportedLocales: [for (final l in languages) Locale(l)],
                startLocale: Locale(language),
                saveLocale: false,
                path: '.',
                assetLoader: _Translations(documents),
                child: Builder(
                  builder: (context) => MaterialApp(
                    navigatorKey: rootNavigatorKey,
                    theme: AppTheme.light(),
                    locale: context.locale,
                    supportedLocales: context.supportedLocales,
                    localizationsDelegates: context.localizationDelegates,
                    home: const Scaffold(),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final title = lookup(documents[language]!, 'kids.story_$id')!;
          final heard = language == 'ar'
              ? id == 'ihya'
                    ? 'افتح قصة إبراهيم والطيور'
                    : 'افتح قصة سليمان والهدهد'
              : title;
          final intent = parser.parse(heard);
          expect(
            intent,
            isA<OpenScreenIntent>().having(
              (intent) => intent.screen,
              'selected specific story',
              stories[id],
            ),
          );
          expect(rootNavigatorKey.currentState, isNotNull);
          await runIntent(container, intent);
          await tester.pump();
          await ticks(tester);
          await ticks(tester);
          final player = tester.widget<KidsStoryPlayerScreen>(
            find.byType(KidsStoryPlayerScreen),
          );
          expect(player.story, same(kidsStories.firstWhere((s) => s.id == id)));
          expect(find.text(title), findsOneWidget);
          expect(tester.takeException(), isNull);
          if (language == 'en' && id == 'hudhud' && screenshotReady != null) {
            await screenshotReady();
          }
          rootNavigatorKey.currentState!.pop();
          await tester.pump();
          // Wait for the actual reverse transition and deferred route removal.
          for (
            var frame = 0;
            frame < 12 &&
                find.byType(KidsStoryPlayerScreen).evaluate().isNotEmpty;
            frame++
          ) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          await ticks(tester);
          expect(find.byType(KidsStoryPlayerScreen), findsNothing);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await ticks(tester);
          for (final stream in video.events.values) {
            await stream.close();
          }
          expect(video.disposed.toSet(), video.events.keys.toSet());
          VideoPlayerPlatform.instance = previousVideo;
          WakelockPlusPlatformInterface.instance = previousWake;
          wakelockPlusPlatformInstance = previousCachedWake;
          container.dispose();
        }
      });
    }
  }
}
