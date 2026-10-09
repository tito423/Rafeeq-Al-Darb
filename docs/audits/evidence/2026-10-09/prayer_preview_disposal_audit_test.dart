import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rafeeq_app/app/rafeeq_app.dart';
import 'package:rafeeq_app/core/models/adhan_option.dart';
import 'package:rafeeq_app/core/services/adhan_native.dart';
import 'package:rafeeq_app/features/adhan/data/adhan_catalog_provider.dart';
import 'package:rafeeq_app/features/home/presentation/widgets/prayer_slides.dart';

class _Translations extends AssetLoader {
  const _Translations();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => {};
}

class _Catalog extends AdhanCatalogNotifier {
  @override
  Future<List<AdhanOption>> build() async => const [AdhanOption(
    id: 'audit', name: 'Audit recording', isCustom: false,
    rawResource: 'azan1', assetPath: 'assets/audio/adhan/azan1.mp3',
  )];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  setUpAll(EasyLocalization.ensureInitialized);
  testWidgets('audit: closing a prayer card while preview starts leaves it playing', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final response = Completer<bool>();
    final calls = <String>[];
    var playing = false;
    const channel = MethodChannel('com.tito.rafeeq_aldarb/adhan_player');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'preview') {
        final started = await response.future;
        playing = started;
        return started;
      }
      if (call.method == 'stop') playing = false;
      if (call.method == 'state') return {'playing': playing, 'firing': false};
      return null;
    });
    await tester.pumpWidget(ProviderScope(overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      adhanCatalogProvider.overrideWith(_Catalog.new),
    ], child: EasyLocalization(
      supportedLocales: const [Locale('en')], startLocale: const Locale('en'),
      path: '.', assetLoader: const _Translations(),
      child: Builder(builder: (context) => MaterialApp(
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales, locale: context.locale,
        home: const Scaffold(body: SingleChildScrollView(
          child: PrayerSlideDetails(prayerKey: 'dhuhr'),
        )),
      )),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.play_circle_outline));
    await tester.pump();
    expect(calls, ['preview']);
    await tester.pumpWidget(const SizedBox.shrink());
    response.complete(true);
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(playing, isTrue);
    expect(calls, ['preview']);
    print('AUDIT_PREVIEW_DISPOSAL: nativeStarted=$playing calls=$calls after widget removal; no stop issued');
    // Clean up the real process-wide lifecycle guard after recording evidence.
    await AdhanNative.stop();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });
}
