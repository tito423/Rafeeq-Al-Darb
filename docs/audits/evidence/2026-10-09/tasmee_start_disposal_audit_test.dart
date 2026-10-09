import 'dart:async';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rafeeq_app/features/assistant/data/rafeeq_voice_pack.dart';
import 'package:rafeeq_app/features/hifz/presentation/widgets/tasmee_panel.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
}

class _Translations extends AssetLoader {
  const _Translations();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => {
    'tasmee': {'start': 'Start', 'title': 'Tasmee', 'not_tajweed': 'Words only'},
  };
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  setUpAll(EasyLocalization.ensureInitialized);
  testWidgets('recording flag stays true after pending permission and disposal',
      (tester) async {
    final dir = Directory.systemTemp.createTempSync('rafeeq_tasmee_audit_');
    final oldPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(dir.path);
    final container = ProviderContainer();
    final permission = Completer<bool>();
    var permissionRequested = false;
    final calls = <String>[];
    final channels = [
      'com.llfbandit.record/messages',
      'com.tito.rafeeq_aldarb/assistant',
      'com.ryanheise.audio_session',
      'com.ryanheise.android_audio_manager',
      'com.ryanheise.just_audio.methods',
      'dev.fluttercommunity.plus/connectivity',
      'dev.fluttercommunity.plus/connectivity_status',
    ];
    for (final name in channels) {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(MethodChannel(name), (call) async {
        if (name == 'com.llfbandit.record/messages') {
          calls.add(call.method);
          if (call.method == 'hasPermission') {
            permissionRequested = true;
            return permission.future;
          }
          if (call.method == 'listInputDevices') return [];
        }
        return null;
      });
    }
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: EasyLocalization(
        supportedLocales: const [Locale('en')], startLocale: const Locale('en'),
        path: '.', assetLoader: const _Translations(),
        child: Builder(builder: (context) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales, locale: context.locale,
          home: const Scaffold(body: TasmeePanel(
            ayahText: '', surahId: 1, ayahNumber: 1,
          )),
        )),
      ),
    ));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    RafeeqVoicePack.accurate.installed.value = true;
    await tester.pump();
    expect(find.text('Start'), findsOneWidget);
    await tester.tap(find.text('Start'));
    for (var i = 0; i < 12 && !permissionRequested; i++) {
      await tester.pump();
    }
    expect(permissionRequested, isTrue);
    expect(container.read(tasmeeRecordingProvider), isTrue);
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
    permission.complete(false);
    await tester.pump();
    await tester.pump();
    expect(container.read(tasmeeRecordingProvider), isTrue);
    expect(calls, isNot(contains('start')));
    expect(tester.takeException(), isNull);
    print('AUDIT_TASMEE_DISPOSAL: permission denied after screen closed; '
        'shared recording flag remains true; native recorder never started. calls=$calls');
    container.dispose();
    for (final name in channels) {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(MethodChannel(name), null);
    }
    PathProviderPlatform.instance = oldPaths;
    RafeeqVoicePack.accurate.installed.value = false;
    dir.deleteSync(recursive: true);
  });
}
