import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rafeeq_app/features/library/presentation/widgets/listen_text_button.dart';
import 'package:rafeeq_app/core/services/audio_exclusive.dart';

class _Translations extends AssetLoader {
  const _Translations();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => {
    'library': {'text_listen': 'Listen', 'text_listen_stop': 'Stop'},
  };
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({'book_voice': 'device'});
  setUpAll(EasyLocalization.ensureInitialized);
  testWidgets('audit: disposed passage starts speech after delayed availability', (tester) async {
    final available = Completer<bool>();
    final calls = <String>[];
    var availabilityRequested = false;
    final channels = [
      'flutter_tts', 'com.tito.rafeeq_aldarb/voice_player',
      'com.ryanheise.audio_session', 'com.ryanheise.android_audio_manager',
      'com.ryanheise.just_audio.methods',
      'dev.fluttercommunity.plus/connectivity',
      'dev.fluttercommunity.plus/connectivity_status',
    ];
    for (final name in channels) {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(MethodChannel(name), (call) async {
        if (name != 'flutter_tts') return null;
        calls.add(call.method);
        if (call.method == 'isLanguageAvailable') {
          availabilityRequested = true;
          return available.future;
        }
        if (call.method == 'getVoices') return <Map<String, String>>[];
        return 1;
      });
    }
    addTearDown(() async {
      await AudioExclusive.silenceSpeakers();
      for (final name in channels) {
        binding.defaultBinaryMessenger.setMockMethodCallHandler(MethodChannel(name), null);
      }
    });
    await tester.pumpWidget(EasyLocalization(
      supportedLocales: const [Locale('en')], startLocale: const Locale('en'),
      path: '.', assetLoader: const _Translations(),
      child: Builder(builder: (context) => MaterialApp(
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales, locale: context.locale,
        home: Scaffold(body: ListenTextButton(text: () => 'كَتَبَ رَجُلٌ.')),
      )),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Listen'));
    await tester.pump();
    expect(availabilityRequested, isTrue);
    expect(calls, isNot(contains('speak')));
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
    final disposedAt = calls.length;
    available.complete(true);
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(calls.skip(disposedAt), contains('speak'));
    expect(tester.takeException(), isNull);
    print('AUDIT_LISTEN_DISPOSAL: after widget disposed, platform calls=${calls.skip(disposedAt).toList()}; speech requested with no visible stop button');
  });
}
