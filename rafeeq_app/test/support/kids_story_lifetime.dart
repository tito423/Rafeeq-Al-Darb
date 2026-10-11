import 'dart:async';
import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/kids/data/kids_stories.dart';
import 'package:rafeeq_app/features/kids/presentation/kids_story_player_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

class _Video extends VideoPlayerPlatform {
  final events = <int, StreamController<VideoEvent>>{};
  final plays = <int>[];
  final disposals = <int>[];
  final seeks = <int>[];
  final positions = <int, Duration>{};
  Completer<void>? pendingPlay;
  Completer<void>? pendingSeek;
  int? holdPlayer;
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
  Future<void> dispose(int playerId) async => disposals.add(playerId);
  @override
  Future<void> play(int playerId) async {
    plays.add(playerId);
    if (playerId == holdPlayer) await pendingPlay?.future;
  }

  @override
  Future<void> pause(int playerId) async {}
  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<void> seekTo(int playerId, Duration position) async {
    seeks.add(playerId);
    if (playerId == holdPlayer) await pendingSeek?.future;
    positions[playerId] = position;
  }

  @override
  Future<Duration> getPosition(int playerId) async =>
      positions[playerId] ?? Duration.zero;
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
  @override
  Widget buildViewWithOptions(VideoViewOptions options) => const SizedBox();
  void initialize(int id) => events[id]!.add(
    VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(seconds: 120),
      size: const Size(1920, 1080),
    ),
  );
  void fail(int id) => events[id]!.addError(
    PlatformException(code: 'source_failed', message: 'Controlled video error'),
  );
}

class _Wake extends WakelockPlusPlatformInterface {
  final calls = <bool>[];
  @override
  Future<void> toggle({required bool enable}) async => calls.add(enable);
}

class _Translations extends AssetLoader {
  const _Translations(this.document);
  final Map<String, dynamic> document;
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      document;
}

/// Actual story screen, bundled story/translations and video SDK. Platform
/// timing is controlled; these cases do not claim decoded video or sound.
void kidsStoryLifetimeTests({Future<void> Function()? screenshotReady}) {
  late Map<String, dynamic> translations;
  late _Video video;
  late _Wake wake;
  late VideoPlayerPlatform oldVideo;
  late WakelockPlusPlatformInterface oldWake;
  late WakelockPlusPlatformInterface oldCachedWake;
  late List<Object> errors;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    await kidsCaptionTranslations();
    translations =
        jsonDecode(await rootBundle.loadString('assets/translations/en.json'))
            as Map<String, dynamic>;
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    oldVideo = VideoPlayerPlatform.instance;
    oldWake = WakelockPlusPlatformInterface.instance;
    oldCachedWake = wakelockPlusPlatformInstance;
    video = _Video();
    wake = _Wake();
    errors = [];
    VideoPlayerPlatform.instance = video;
    WakelockPlusPlatformInterface.instance = wake;
    wakelockPlusPlatformInstance = wake;
  });
  Future<void> ticks(WidgetTester tester) async {
    for (var i = 0; i < 15; i++) {
      await tester.pump();
    }
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }

  tearDown(() async {
    for (final stream in video.events.values) {
      await stream.close();
    }
    VideoPlayerPlatform.instance = oldVideo;
    WakelockPlusPlatformInterface.instance = oldWake;
    wakelockPlusPlatformInstance = oldCachedWake;
  });
  Future<void> show(WidgetTester tester, {int storyIndex = 0}) async {
    await runZonedGuarded(
      () async {
        await tester.pumpWidget(
          ProviderScope(
            child: EasyLocalization(
              key: UniqueKey(),
              supportedLocales: const [Locale('en')],
              startLocale: const Locale('en'),
              path: '.',
              assetLoader: _Translations(translations),
              saveLocale: false,
              child: Builder(
                builder: (context) => MaterialApp(
                  localizationsDelegates: context.localizationDelegates,
                  supportedLocales: context.supportedLocales,
                  locale: context.locale,
                  home: KidsStoryPlayerScreen(story: kidsStories[storyIndex]),
                ),
              ),
            ),
          ),
        );
      },
      (error, stack) {
        errors.add(error);
        debugPrint('A35 captured: $error');
      },
    );
    await ticks(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await ticks(tester);
  }

  Future<void> cleanLeakedControllers(WidgetTester tester) async {
    // Baseline failure cleanup must not hide the production assertions.
    for (final element in tester.allElements.toList()) {
      if (element.widget is VideoPlayer) {
        await (element.widget as VideoPlayer).controller.dispose();
      }
    }
    for (final id in video.events.keys) {
      video.events[id]!.add(VideoEvent(eventType: VideoEventType.completed));
    }
    await ticks(tester);
  }

  void check(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        if (video.pendingPlay != null && !video.pendingPlay!.isCompleted) {
          video.pendingPlay!.complete();
        }
        if (video.pendingSeek != null && !video.pendingSeek!.isCompleted) {
          video.pendingSeek!.complete();
        }
        await close(tester);
        for (final stream in video.events.values) {
          stream.add(VideoEvent(eventType: VideoEventType.completed));
        }
        await ticks(tester);
      }
    });
  }

  check('A35 close during play disposes without late wake or error', (
    tester,
  ) async {
    video.holdPlayer = 1;
    video.pendingPlay = Completer<void>();
    await show(tester);
    video.initialize(1);
    await ticks(tester);
    expect(video.plays, [1]);
    await close(tester);
    video.pendingPlay!.complete();
    await ticks(tester);
    await cleanLeakedControllers(tester);
    expect(video.disposals, [1]);
    expect(wake.calls, isNot(contains(true)));
    expect(errors, isEmpty);
    expect(tester.takeException(), isNull);
  });
  check('A35 previous pending play cannot reactivate replacement wake', (
    tester,
  ) async {
    video.holdPlayer = 1;
    video.pendingPlay = Completer<void>();
    await show(tester);
    video.initialize(1);
    await ticks(tester);
    await close(tester);
    await show(tester, storyIndex: 1);
    video.initialize(2);
    await ticks(tester);
    expect(video.plays, [1, 2]);
    await close(tester);
    video.pendingPlay!.complete();
    await ticks(tester);
    await cleanLeakedControllers(tester);
    expect(video.disposals.toSet(), {1, 2});
    expect(wake.calls.last, false);
    expect(errors, isEmpty);
  });
  check('A35 close during initialization releases player immediately', (
    tester,
  ) async {
    await show(tester);
    expect(video.events, hasLength(1));
    await close(tester);
    final releasedAtClose = List<int>.of(video.disposals);
    video.initialize(1);
    await ticks(tester);
    expect(releasedAtClose, [1]);
    expect(video.plays, isEmpty);
    expect(wake.calls, isNot(contains(true)));
    expect(errors, isEmpty);
  });
  check('A35 close during fallback seek never plays next source', (
    tester,
  ) async {
    await show(tester);
    video.initialize(1);
    await ticks(tester);
    await tester
        .widget<VideoPlayer>(find.byType(VideoPlayer))
        .controller
        .seekTo(const Duration(seconds: 12));
    await ticks(tester);
    final controller = tester
        .widget<VideoPlayer>(find.byType(VideoPlayer))
        .controller;
    controller.value = controller.value.copyWith(
      errorDescription: 'Controlled source error',
    );
    await ticks(tester);
    expect(video.events, hasLength(2));
    video.holdPlayer = 2;
    video.pendingSeek = Completer<void>();
    video.initialize(2);
    await ticks(tester);
    expect(video.seeks, contains(2));
    await close(tester);
    video.pendingSeek!.complete();
    await ticks(tester);
    await cleanLeakedControllers(tester);
    expect(video.plays, [1]);
    expect(video.disposals.toSet(), {1, 2});
    expect(wake.calls.last, false);
    expect(errors, isEmpty);
  });
  check('A35 ordinary playback controls and close remain functional', (
    tester,
  ) async {
    await show(tester);
    video.initialize(1);
    await ticks(tester);
    expect(find.byType(VideoPlayer), findsOneWidget);
    expect(wake.calls.last, true);
    if (screenshotReady != null) await screenshotReady();
    await tester.tap(find.byTooltip('kids.story_pause'.tr()));
    await ticks(tester);
    expect(wake.calls.last, false);
    await tester.tap(find.byTooltip('kids.story_play'.tr()));
    await ticks(tester);
    expect(wake.calls.last, true);
    await close(tester);
    expect(video.disposals, [1]);
    expect(wake.calls.last, false);
    expect(errors, isEmpty);
    expect(tester.takeException(), isNull);
  });
  check('A35 failed initialization still advances to next mirror', (
    tester,
  ) async {
    await show(tester);
    video.fail(1);
    await ticks(tester);
    expect(video.disposals, [1]);
    expect(video.events, hasLength(2));
    video.initialize(2);
    await ticks(tester);
    expect(video.plays, [2]);
    await close(tester);
    expect(video.disposals, [1, 2]);
    expect(errors, isEmpty);
  });
}
