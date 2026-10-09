import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';
import 'package:rafeeq_app/features/kids/data/kids_stories.dart';
import 'package:rafeeq_app/features/kids/presentation/kids_story_player_screen.dart';

class _Video extends VideoPlayerPlatform {
  final release = Completer<void>();
  final events = StreamController<VideoEvent>.broadcast();
  bool playRequested = false;
  bool disposed = false;
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async => 1;
  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => events.stream;
  @override
  Future<void> dispose(int playerId) async { disposed = true; }
  @override
  Future<void> play(int playerId) async { playRequested = true; await release.future; }
  @override
  Future<void> pause(int playerId) async {}
  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<void> seekTo(int playerId, Duration position) async {}
  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
  @override
  Widget buildViewWithOptions(VideoViewOptions options) => const SizedBox();
}

class _Wake extends WakelockPlusPlatformInterface {
  final calls = <bool>[];
  @override
  Future<void> toggle({required bool enable}) async { calls.add(enable); }
}

class _Translations extends AssetLoader {
  const _Translations();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('assets/translations/en.json').readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  setUpAll(EasyLocalization.ensureInitialized);
  testWidgets('audit: delayed story play completes after screen disposal', (tester) async {
    final errors = <Object>[];
    await runZonedGuarded(() async {
    final oldVideo = VideoPlayerPlatform.instance;
    final oldWake = WakelockPlusPlatformInterface.instance;
    final video = _Video();
    final wake = _Wake();
    VideoPlayerPlatform.instance = video;
    WakelockPlusPlatformInterface.instance = wake;
    await tester.pumpWidget(ProviderScope(child: EasyLocalization(
      supportedLocales: const [Locale('en')], startLocale: const Locale('en'),
      path: '.', assetLoader: const _Translations(),
      child: Builder(builder: (context) => MaterialApp(
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales, locale: context.locale,
        home: KidsStoryPlayerScreen(story: kidsStories.first),
      )),
    )));
    for (var i = 0; i < 10; i++) { await tester.pump(); }
    video.events.add(VideoEvent(eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 120), size: const Size(1920, 1080)));
    for (var i = 0; i < 10 && !video.playRequested; i++) { await tester.pump(); }
    expect(video.playRequested, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(wake.calls, contains(false));
    expect(video.disposed, isFalse);
    video.release.complete();
    await tester.pump();
    await tester.pump();
    expect(errors, hasLength(1));
    final error = errors.single;
    expect(error.toString(), contains('setState() called after dispose'));
    expect(wake.calls.last, isTrue);
    expect(wake.calls, [false, true]);
    expect(video.disposed, isFalse);
    print('AUDIT_KIDS_VIDEO_DISPOSAL: pending play completed after close; '
        'wakelock=${wake.calls}; player disposed=${video.disposed}; error=$error');
    // Complete the leaked controller to stop its periodic position timer.
    video.events.add(VideoEvent(eventType: VideoEventType.completed));
    await tester.pump();
    await tester.pump();
    await video.events.close();
    VideoPlayerPlatform.instance = oldVideo;
    WakelockPlusPlatformInterface.instance = oldWake;
    }, (error, stack) { errors.add(error); });
  });
}
