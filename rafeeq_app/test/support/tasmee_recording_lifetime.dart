import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:rafeeq_app/core/services/audio_exclusive.dart';
import 'package:rafeeq_app/features/assistant/data/rafeeq_voice_pack.dart';
import 'package:rafeeq_app/features/hifz/presentation/widgets/tasmee_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  Completer<String?>? temporary;
  @override
  Future<String?> getApplicationSupportPath() async => path;
  @override
  Future<String?> getTemporaryPath() async => temporary?.future ?? path;
  @override
  Future<String?> getExternalStoragePath() async => null;
}

class _Translations extends AssetLoader {
  const _Translations();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => {
    'tasmee': {
      'start': 'Start',
      'stop': 'Done',
      'title': 'Tasmee',
      'not_tajweed': 'Words only',
      'needs_mic': 'Microphone permission is needed',
      'level': 'Level',
    },
    'common': {'cancel': 'Cancel'},
  };
}

/// Real panel/provider/record SDK, with controlled native replies. This tests
/// microphone ownership and cancellation, not recognition or audible sound.
void tasmeeRecordingLifetimeTests({Future<void> Function()? screenshotReady}) {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const recorderChannel = 'com.llfbandit.record/messages';
  const channels = [
    recorderChannel,
    'com.tito.rafeeq_aldarb/assistant',
    'com.ryanheise.audio_session',
    'com.ryanheise.android_audio_manager',
    'com.ryanheise.just_audio.methods',
  ];
  late Directory dir;
  late PathProviderPlatform oldPaths;
  late _Paths paths;
  late ProviderContainer container;
  late List<MethodCall> calls;
  late List<String> eventChannels;
  late List<bool> recording;
  Completer<bool>? permission;
  Completer<void>? starting;
  Completer<void>? silencing;
  Completer<String?>? stopping;
  Completer<List<Map<String, String>>>? devices;
  late List<String> timeline;
  var bluetooth = false;
  var permissionAnswer = false;
  var containerDisposed = false;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    await AudioExclusive.silenceAll();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('audit_A33_');
    oldPaths = PathProviderPlatform.instance;
    paths = _Paths(dir.path);
    PathProviderPlatform.instance = paths;
    container = ProviderContainer();
    containerDisposed = false;
    calls = [];
    eventChannels = [];
    recording = [];
    permission = null;
    starting = null;
    silencing = null;
    stopping = null;
    devices = null;
    timeline = [];
    bluetooth = false;
    permissionAnswer = false;
    for (final name in channels) {
      messenger.setMockMethodCallHandler(MethodChannel(name), (call) async {
        if (name == 'com.ryanheise.android_audio_manager') {
          timeline.add('route:${call.method}:${call.arguments}');
          if (call.method == 'setCommunicationDevice') return true;
          if (call.method == 'getAvailableCommunicationDevices') {
            return [
              {
                'id': 1,
                'productName': 'Controlled headset',
                'address': '',
                'isSource': true,
                'isSink': true,
                'sampleRates': <int>[],
                'channelMasks': <int>[],
                'channelIndexMasks': <int>[],
                'channelCounts': <int>[],
                'encodings': <int>[],
                'type': AndroidAudioDeviceType.bluetoothSco.index,
              },
            ];
          }
          return null;
        }
        if (name != recorderChannel) return null;
        calls.add(call);
        timeline.add('record:${call.method}');
        if (call.method == 'create') {
          final id = (call.arguments as Map)['recorderId'];
          final events = 'com.llfbandit.record/events/$id';
          eventChannels.add(events);
          messenger.setMockMethodCallHandler(
            MethodChannel(events),
            (_) async => null,
          );
        }
        if (call.method == 'hasPermission') {
          return permission?.future ?? permissionAnswer;
        }
        if (call.method == 'listInputDevices') {
          if (devices != null &&
              calls.where((c) => c.method == 'listInputDevices').length > 1) {
            return devices!.future;
          }
          return bluetooth
              ? [
                  {'id': 'bt', 'label': 'Bluetooth telephony SCO'},
                ]
              : <Map<String, String>>[];
        }
        if (call.method == 'isRecording') return false;
        if (call.method == 'stop') return stopping?.future;
        if (call.method == 'start' && starting != null) await starting!.future;
        return null;
      });
    }
  });

  Future<void> ticks(WidgetTester tester) async {
    for (var i = 0; i < 15; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1)),
      );
      await tester.pump();
    }
  }

  Future<void> show(
    WidgetTester tester, {
    String key = 'panel',
    int ayah = 1,
    String text = '',
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: EasyLocalization(
          supportedLocales: const [Locale('en')],
          startLocale: const Locale('en'),
          path: '.',
          assetLoader: const _Translations(),
          saveLocale: false,
          child: Builder(
            builder: (context) => MaterialApp(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              home: Scaffold(
                body: TasmeePanel(
                  key: ValueKey(key),
                  ayahText: text,
                  surahId: 1,
                  ayahNumber: ayah,
                  onRecording: recording.add,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await ticks(tester);
    RafeeqVoicePack.accurate.installed.value = true;
    await tester.pump();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
  }

  Future<void> cleanup(WidgetTester tester) async {
    if (permission != null && !permission!.isCompleted) {
      permission!.complete(false);
    }
    if (starting != null && !starting!.isCompleted) starting!.complete();
    if (silencing != null && !silencing!.isCompleted) silencing!.complete();
    if (stopping != null && !stopping!.isCompleted) stopping!.complete(null);
    if (devices != null && !devices!.isCompleted) devices!.complete([]);
    if (paths.temporary != null && !paths.temporary!.isCompleted) {
      paths.temporary!.complete(dir.path);
    }
    await close(tester);
    await ticks(tester);
    if (!containerDisposed) container.dispose();
    for (final name in [...channels, ...eventChannels]) {
      messenger.setMockMethodCallHandler(MethodChannel(name), null);
    }
    PathProviderPlatform.instance = oldPaths;
    RafeeqVoicePack.accurate.installed.value = false;
    dir.deleteSync(recursive: true);
  }

  int count(String method) => calls.where((c) => c.method == method).length;
  Future<void> begin(WidgetTester tester) async {
    await tester.tap(find.text('Start'));
    await ticks(tester);
  }

  for (final granted in [false, true]) {
    testWidgets('A33 closed panel cancels late permission $granted', (
      tester,
    ) async {
      addTearDown(() => cleanup(tester));
      permission = Completer<bool>();
      await show(tester);
      await begin(tester);
      expect(count('hasPermission'), 1);
      expect(container.read(tasmeeRecordingProvider), isTrue);
      await close(tester);
      permission!.complete(granted);
      await ticks(tester);
      expect(container.read(tasmeeRecordingProvider), isFalse);
      expect(count('start'), 0);
      expect(recording, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('A33 duplicate taps cannot request two starts', (tester) async {
    addTearDown(() => cleanup(tester));
    permission = Completer<bool>();
    await show(tester);
    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Start'),
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      ),
    );
    button.onPressed!();
    button.onPressed!();
    await ticks(tester);
    permission!.complete(false);
    await ticks(tester);
    expect(count('hasPermission'), 1);
    expect(count('start'), 0);
    expect(container.read(tasmeeRecordingProvider), isFalse);
  });

  testWidgets('A33 ayah change invalidates a pending start', (tester) async {
    addTearDown(() => cleanup(tester));
    permission = Completer<bool>();
    await show(tester);
    await begin(tester);
    await show(tester, ayah: 2, text: ' ');
    permission!.complete(true);
    await ticks(tester);
    expect(count('start'), 0);
    expect(container.read(tasmeeRecordingProvider), isFalse);
    expect(recording, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('A33 closed provider scope cannot receive a late grant', (
    tester,
  ) async {
    addTearDown(() => cleanup(tester));
    permission = Completer<bool>();
    await show(tester);
    await begin(tester);
    await close(tester);
    container.dispose();
    containerDisposed = true;
    permission!.complete(true);
    await ticks(tester);
    expect(count('start'), 0);
    expect(recording, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('A33 permission failure releases ownership and offers retry', (
    tester,
  ) async {
    addTearDown(() => cleanup(tester));
    permission = Completer<bool>();
    await show(tester);
    await begin(tester);
    permission!.completeError(PlatformException(code: 'permission_failure'));
    await ticks(tester);
    expect(container.read(tasmeeRecordingProvider), isFalse);
    expect(find.text('Start'), findsOneWidget);
    expect(count('start'), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('A33 closing during silence never claims the microphone', (
    tester,
  ) async {
    addTearDown(() => cleanup(tester));
    silencing = Completer<void>();
    Future<void> stopSpeaker() => silencing!.future;
    AudioExclusive.speakerStarted(stopSpeaker);
    addTearDown(() => AudioExclusive.speakerStopped(stopSpeaker));
    await show(tester);
    await begin(tester);
    await close(tester);
    silencing!.complete();
    await ticks(tester);
    expect(count('hasPermission'), 0);
    expect(count('start'), 0);
    expect(container.read(tasmeeRecordingProvider), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('A33 closed panel ignores a delayed temporary directory', (
    tester,
  ) async {
    addTearDown(() => cleanup(tester));
    permissionAnswer = true;
    paths.temporary = Completer<String?>();
    await show(tester);
    await begin(tester);
    expect(count('hasPermission'), 1);
    await close(tester);
    paths.temporary!.complete(dir.path);
    await ticks(tester);
    expect(count('start'), 0);
    expect(container.read(tasmeeRecordingProvider), isFalse);
    expect(recording, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'A33 closed panel stops a delayed native start without notifying',
    (tester) async {
      addTearDown(() => cleanup(tester));
      permissionAnswer = true;
      starting = Completer<void>();
      await show(tester);
      await begin(tester);
      expect(count('start'), 1);
      await close(tester);
      starting!.complete();
      await ticks(tester);
      expect(count('stop'), greaterThanOrEqualTo(1));
      expect(container.read(tasmeeRecordingProvider), isFalse);
      expect(recording, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('A33 replacement panel keeps its own pending recording flag', (
    tester,
  ) async {
    addTearDown(() => cleanup(tester));
    permission = Completer<bool>();
    await show(tester);
    await begin(tester);
    await show(tester, key: 'replacement');
    final replacementPermission = Completer<bool>();
    final oldPermission = permission!;
    permission = replacementPermission;
    await begin(tester);
    oldPermission.complete(false);
    await ticks(tester);
    expect(container.read(tasmeeRecordingProvider), isTrue);
    expect(count('start'), 0);
    replacementPermission.complete(false);
    await ticks(tester);
    expect(container.read(tasmeeRecordingProvider), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('A33 preparing microphone has an effective Cancel button', (
    tester,
  ) async {
    addTearDown(() => cleanup(tester));
    permission = Completer<bool>();
    await show(tester);
    await begin(tester);
    expect(find.text('Cancel'), findsOneWidget);
    if (screenshotReady != null) await tester.runAsync(screenshotReady);
    await tester.tap(find.text('Cancel'));
    permission!.complete(true);
    await ticks(tester);
    expect(count('start'), 0);
    expect(container.read(tasmeeRecordingProvider), isFalse);
    expect(recording, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('A33 ordinary permission denial still offers retry', (
    tester,
  ) async {
    addTearDown(() => cleanup(tester));
    await show(tester);
    await begin(tester);
    expect(count('hasPermission'), 1);
    expect(count('start'), 0);
    expect(container.read(tasmeeRecordingProvider), isFalse);
    expect(find.text('Microphone permission is needed'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('A33 cancelled device discovery cannot open the recorder', (
    tester,
  ) async {
    addTearDown(() => cleanup(tester));
    permissionAnswer = true;
    await show(tester);
    devices = Completer<List<Map<String, String>>>();
    await begin(tester);
    expect(count('listInputDevices'), 2);
    await close(tester);
    devices!.complete([]);
    await ticks(tester);
    expect(count('start'), 0);
    expect(container.read(tasmeeRecordingProvider), isFalse);
    expect(recording, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('A33 new owner waits for old stop and keeps its pending flag', (
    tester,
  ) async {
    addTearDown(() => cleanup(tester));
    permissionAnswer = true;
    await show(tester);
    await begin(tester);
    expect(count('start'), 1);
    expect(recording, [true]);
    stopping = Completer<String?>();
    await close(tester);
    expect(count('stop'), 1);
    await show(tester, key: 'new-owner');
    permission = Completer<bool>();
    await begin(tester);
    expect(count('start'), 1);
    stopping!.complete(null);
    await ticks(tester);
    expect(container.read(tasmeeRecordingProvider), isTrue);
    expect(count('start'), 1);
    permission!.complete(false);
    await ticks(tester);
    expect(container.read(tasmeeRecordingProvider), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('A33 recording paths are isolated and owned files are removed', (
    tester,
  ) async {
    addTearDown(() => cleanup(tester));
    permissionAnswer = true;
    await show(tester);
    await begin(tester);
    expect(recording, [true]);
    final first =
        (calls.firstWhere((c) => c.method == 'start').arguments as Map)['path']
            as String;
    await close(tester);
    await ticks(tester);
    await show(tester, key: 'next-recording');
    await begin(tester);
    expect(recording, [true, true]);
    final second =
        (calls.lastWhere((c) => c.method == 'start').arguments as Map)['path']
            as String;
    expect(second, isNot(first));
    if (File(first).parent.path != dir.path) {
      expect(File(first).parent.existsSync(), isFalse);
    }
    await close(tester);
    await ticks(tester);
    expect(
      dir.listSync().whereType<Directory>().where(
        (d) => d.path.contains('tasmee_'),
      ),
      isEmpty,
    );
    expect(container.read(tasmeeRecordingProvider), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('A33 old Bluetooth cleanup precedes the new microphone', (
    tester,
  ) async {
    addTearDown(() => cleanup(tester));
    bluetooth = true;
    permissionAnswer = true;
    await show(tester);
    await begin(tester);
    expect(count('start'), 1);
    await close(tester);
    await show(tester, key: 'next-headset');
    await begin(tester);
    expect(count('start'), 2);
    final oldStop = timeline.indexOf('record:stop');
    final newStart = timeline.lastIndexOf('record:start');
    expect(oldStop, greaterThanOrEqualTo(0));
    expect(oldStop, lessThan(newStart));
    if (Platform.isAndroid) {
      final normal = timeline.indexOf(
        'route:setMode:[${AndroidAudioHardwareMode.normal.index}]',
      );
      final communication = timeline.lastIndexOf(
        'route:setMode:[${AndroidAudioHardwareMode.inCommunication.index}]',
      );
      expect(normal, greaterThan(oldStop));
      expect(communication, greaterThan(normal));
      expect(newStart, greaterThan(communication));
    } else {
      expect(timeline.where((v) => v.startsWith('route:')), isEmpty);
    }
    await close(tester);
    await ticks(tester);
    expect(container.read(tasmeeRecordingProvider), isFalse);
    expect(tester.takeException(), isNull);
  });
}
