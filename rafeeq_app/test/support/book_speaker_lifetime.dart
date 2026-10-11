import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/services/audio_exclusive.dart';
import 'package:rafeeq_app/features/library/data/book_speaker.dart';
import 'package:rafeeq_app/features/library/presentation/widgets/listen_text_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Translations extends AssetLoader {
  const _Translations();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => {
    'library': {'text_listen': 'Listen', 'text_listen_stop': 'Stop'},
  };
}

/// Actual widget and FlutterTts method-channel calls, with controlled engine
/// replies. This proves cancellation ordering, not audible native speech.
void bookSpeakerLifetimeTests({Future<void> Function()? screenshotReady}) {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channels = [
    'flutter_tts',
    'com.tito.rafeeq_aldarb/voice_player',
    'com.ryanheise.audio_session',
    'com.ryanheise.android_audio_manager',
    'com.ryanheise.just_audio.methods',
  ];
  late List<MethodCall> calls;
  Completer<bool>? availability;
  Completer<int>? setup;
  Completer<int>? stopping;
  Completer<int>? speaking;
  String? delayedMethod;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({'book_voice': 'device'});
    await EasyLocalization.ensureInitialized();
    // Initialise the shared idle player outside a test's FakeAsync lifetime.
    // Its first load future must survive between independently disposed tests.
    await AudioExclusive.silenceAll();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({'book_voice': 'device'});
    calls = [];
    availability = null;
    setup = null;
    stopping = null;
    speaking = null;
    delayedMethod = null;
    for (final name in channels) {
      messenger.setMockMethodCallHandler(MethodChannel(name), (call) async {
        if (name != 'flutter_tts') return null;
        calls.add(call);
        if (call.method == 'isLanguageAvailable') {
          return availability?.future ?? true;
        }
        if (call.method == delayedMethod) return setup!.future;
        if (call.method == 'stop' && stopping != null) return stopping!.future;
        if (call.method == 'speak' && speaking != null) return speaking!.future;
        if (call.method == 'getVoices') return <Map<String, String>>[];
        return 1;
      });
    }
  });
  tearDown(() async {
    if (availability != null && !availability!.isCompleted) {
      availability!.complete(true);
    }
    if (setup != null && !setup!.isCompleted) setup!.complete(1);
    if (stopping != null && !stopping!.isCompleted) stopping!.complete(1);
    if (speaking != null && !speaking!.isCompleted) speaking!.complete(1);
    await AudioExclusive.silenceSpeakers();
    for (final name in channels) {
      messenger.setMockMethodCallHandler(MethodChannel(name), null);
    }
  });

  Future<void> ticks(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1)),
      );
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  Future<void> show(WidgetTester tester, {Key? buttonKey}) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en')],
        startLocale: const Locale('en'),
        saveLocale: false,
        path: '.',
        assetLoader: const _Translations(),
        child: Builder(
          builder: (context) => MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            home: Scaffold(
              body: ListenTextButton(
                key: buttonKey,
                text: () => 'كَتَبَ رَجُلٌ.',
              ),
            ),
          ),
        ),
      ),
    );
    await ticks(tester);
  }

  Future<void> closed(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await ticks(tester);
  }

  testWidgets('A30 close during Arabic availability never starts speech', (
    tester,
  ) async {
    availability = Completer<bool>();
    await show(tester);
    await tester.tap(find.text('Listen'));
    await ticks(tester);
    expect(calls.any((c) => c.method == 'isLanguageAvailable'), isTrue);
    await closed(tester);
    availability!.complete(true);
    await ticks(tester);
    expect(calls.where((c) => c.method == 'speak'), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('A30 pending start can be cancelled without a second start', (
    tester,
  ) async {
    availability = Completer<bool>();
    await show(tester);
    await tester.tap(find.text('Listen'));
    await ticks(tester);
    expect(find.text('Stop'), findsOneWidget);
    if (screenshotReady != null) await tester.runAsync(screenshotReady);
    await tester.tap(find.text('Stop'));
    await ticks(tester);
    availability!.complete(true);
    await ticks(tester);
    expect(calls.where((c) => c.method == 'isLanguageAvailable'), hasLength(1));
    expect(calls.where((c) => c.method == 'speak'), isEmpty);
    expect(find.text('Listen'), findsOneWidget);
    await closed(tester);
  });

  testWidgets(
    'A30 late availability on removed button cannot replace newer speech',
    (tester) async {
      availability = Completer<bool>();
      await show(tester, buttonKey: const ValueKey('old'));
      await tester.tap(find.text('Listen'));
      await ticks(tester);
      final old = availability!;
      await closed(tester);
      availability = null;
      await show(tester, buttonKey: const ValueKey('new'));
      await tester.tap(find.text('Listen'));
      await ticks(tester);
      expect(calls.where((c) => c.method == 'speak'), hasLength(1));
      final before = calls.length;
      old.complete(true);
      await ticks(tester);
      expect(
        calls
            .skip(before)
            .where((c) => c.method == 'speak' || c.method == 'stop'),
        isEmpty,
      );
      await closed(tester);
    },
  );

  for (final method in [
    'setLanguage',
    'getVoices',
    'setSpeechRate',
    'awaitSpeakCompletion',
  ]) {
    testWidgets('A30 stop during $method prevents remaining setup and speech', (
      tester,
    ) async {
      delayedMethod = method;
      setup = Completer<int>();
      final speaker = BookSpeaker();
      final reading = speaker.speak('كَتَبَ رَجُلٌ.');
      await ticks(tester);
      expect(calls.any((c) => c.method == method), isTrue);
      await speaker.stop();
      final before = calls.length;
      setup!.complete(1);
      await ticks(tester);
      await reading;
      expect(calls.skip(before).where((c) => c.method != 'stop'), isEmpty);
      expect(speaker.isSpeaking, isFalse);
      speaker.dispose();
    });
  }

  testWidgets('A30 disposed speaker cannot restart or stop newer speaker', (
    tester,
  ) async {
    final old = BookSpeaker();
    old.dispose();
    final newer = BookSpeaker();
    await tester.runAsync(() => newer.speak('كَتَبَ رَجُلٌ.'));
    final before = calls.length;
    await tester.runAsync(() => old.speak('كَتَبَ رَجُلٌ.'));
    await old.stop();
    await ticks(tester);
    expect(calls.skip(before), isEmpty);
    newer.dispose();
  });

  testWidgets('A30 old setup completion cannot change a newer run', (
    tester,
  ) async {
    delayedMethod = 'setLanguage';
    setup = Completer<int>();
    final speaker = BookSpeaker();
    final oldReading = speaker.speak('كَتَبَ رَجُلٌ.');
    await ticks(tester);
    await speaker.stop();
    delayedMethod = null;
    await tester.runAsync(() => speaker.speak('كَتَبَ رَجُلٌ.'));
    final before = calls.length;
    setup!.complete(1);
    await ticks(tester);
    await oldReading;
    expect(calls.skip(before), isEmpty);
    expect(calls.where((c) => c.method == 'speak'), hasLength(1));
    speaker.dispose();
  });

  testWidgets('A30 inactive speaker cannot stop currently speaking owner', (
    tester,
  ) async {
    final old = BookSpeaker();
    speaking = Completer<int>();
    final newer = BookSpeaker();
    final reading = newer.speak('كَتَبَ رَجُلٌ.');
    await ticks(tester);
    expect(calls.where((c) => c.method == 'speak'), hasLength(1));
    expect(newer.isSpeaking, isTrue);
    final before = calls.length;
    await old.stop();
    old.dispose();
    await ticks(tester);
    expect(calls.skip(before), isEmpty);
    expect(newer.isSpeaking, isTrue);
    speaking!.complete(1);
    await ticks(tester);
    await reading;
    newer.dispose();
  });

  testWidgets('A30 new speech waits for pending native stop replies', (
    tester,
  ) async {
    delayedMethod = 'setLanguage';
    setup = Completer<int>();
    final old = BookSpeaker();
    final oldReading = old.speak('كَتَبَ رَجُلٌ.');
    await ticks(tester);
    expect(calls.any((c) => c.method == 'setLanguage'), isTrue);
    stopping = Completer<int>();
    final cancelled = old.stop();
    delayedMethod = null;
    final newer = BookSpeaker();
    final newReading = newer.speak('كَتَبَ رَجُلٌ.');
    await ticks(tester);
    expect(calls.where((c) => c.method == 'speak'), isEmpty);
    stopping!.complete(1);
    await ticks(tester);
    await cancelled;
    await newReading;
    expect(calls.where((c) => c.method == 'speak'), hasLength(1));
    final before = calls.length;
    setup!.complete(1);
    await ticks(tester);
    await oldReading;
    expect(calls.skip(before), isEmpty);
    old.dispose();
    newer.dispose();
  });
}
