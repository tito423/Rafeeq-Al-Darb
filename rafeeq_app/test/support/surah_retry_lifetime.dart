import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:rafeeq_app/features/quran_audio/data/mp3quran_api.dart';
import 'package:rafeeq_app/features/quran_audio/data/quran_audio_library.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Dirs extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _Dirs(this.path);
  final String path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
  @override
  Future<String?> getTemporaryPath() async => path;
}

class _Storage extends Fake implements PersistentStorage {
  @override
  Future<void> initialize() async {}
  @override
  Future<List<TaskRecord>> retrieveAllTaskRecords() async => [];
  @override
  Future<List<Task>> retrieveAllPausedTasks() async => [];
  @override
  Future<List<ResumeData>> retrieveAllResumeData() async => [];
  @override
  Future<Task?> retrievePausedTask(String id) async => null;
  @override
  Future<ResumeData?> retrieveResumeData(String id) async => null;
  @override
  Future<void> removePausedTask(String? id) async {}
  @override
  Future<void> removeResumeData(String? id) async {}
}

const retryCases = [
  'cancelSurah',
  'cancelAll',
  'deleteRecitation',
  'deleteSurah',
  'pauseResume',
  'newRequest',
  'normalRetry',
  'notFound',
];

/// The production library/DownloadEngine/plugin update stream and real minute
/// timer. Only platform transport/storage are controlled; no remote transfer.
void surahRetryLifetimeTests({bool native = false}) {
  void register(
    String name,
    FutureOr<void> Function() body, {
    Timeout? timeout,
  }) {
    if (native) {
      testWidgets(name, (tester) async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() async {
          await body();
        });
      }, timeout: timeout);
    } else {
      test(name, body, timeout: timeout);
    }
  }

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('com.bbflight.background_downloader');
  final library = QuranAudioLibrary.instance;
  final queued = <String, List<DownloadTask>>{};
  final ids = <String, int>{};
  late Directory dir;
  late PathProviderPlatform originalDirs;
  late TargetPlatform? originalPlatform;

  int count(String scenario) => queued[scenario]?.length ?? 0;
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 80));

  register(
    'A31 production minute elapses before retry checks',
    () async {
      originalPlatform = debugDefaultTargetPlatformOverride;
      if (!native) debugDefaultTargetPlatformOverride = TargetPlatform.android;
      SharedPreferences.setMockInitialValues({});
      dir = await Directory.systemTemp.createTemp('audit_A31_');
      originalDirs = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _Dirs(dir.path);
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'enqueue') {
          final data =
              jsonDecode((call.arguments as List).first as String)
                  as Map<String, dynamic>;
          final task = DownloadTask.fromJson(data);
          final id = int.parse(task.taskId.split('_')[1]);
          final scenario = ids.entries.firstWhere((e) => e.value == id).key;
          (queued[scenario] ??= []).add(task);
          return true;
        }
        if (call.method == 'allTasks') return <dynamic>[];
        if (call.method == 'permissionStatus') return 0;
        if (call.method == 'requestPermission') return false;
        if (call.method == 'cancelTasksWithIds') return true;
        return null;
      });
      FileDownloader(persistentStorage: _Storage());
      await FileDownloader().ready;
      await library.ensureReady();
      await settle(); // startup repair must finish before the fixture requests
      for (var i = 0; i < retryCases.length; i++) {
        final scenario = retryCases[i];
        final id = 987600 + i;
        ids[scenario] = id;
        final moshaf = Mp3Moshaf(
          id: id,
          name: scenario,
          server: 'https://example.invalid/audit/',
          surahs: const [1],
        );
        final reciter = Mp3Reciter(id: id, name: scenario, moshafs: [moshaf]);
        await library.download(reciter, moshaf, only: [1]);
        await settle();
        expect(count(scenario), 1);
        final task = queued[scenario]!.single;
        FileDownloader().downloaderForTesting.updates.add(
          TaskStatusUpdate(
            task,
            scenario == 'notFound' ? TaskStatus.notFound : TaskStatus.failed,
          ),
        );
        await settle();
        expect(library.statusOf(id, 1).state, SurahAudioState.failed);
        switch (scenario) {
          case 'cancelSurah':
            await library.cancelSurah(id, 1);
          case 'cancelAll':
            await library.cancel(id);
          case 'deleteRecitation':
            await library.deleteRecitation(id);
          case 'deleteSurah':
            await library.deleteSurah(id, 1);
          case 'pauseResume':
            await library.pause(id);
            await library.resume(id);
          case 'newRequest':
            await library.cancelSurah(id, 1);
            await library.download(reciter, moshaf, only: [1]);
          default:
            break;
        }
        if (scenario == 'pauseResume' || scenario == 'newRequest') {
          await settle();
          expect(count(scenario), 2);
          FileDownloader().downloaderForTesting.updates.add(
            TaskStatusUpdate(queued[scenario]!.last, TaskStatus.running),
          );
          await settle();
        }
      }
      // All eight independent timers share this real elapsed-time wait. No
      // production duration is shortened, and no retry is executed manually.
      await Future<void>.delayed(const Duration(seconds: 61));
      await settle();
    },
    timeout: const Timeout(Duration(seconds: 100)),
  );

  for (final scenario in retryCases) {
    register('A31 minute retry respects $scenario', () {
      final id = ids[scenario]!;
      switch (scenario) {
        case 'normalRetry':
          expect(count(scenario), 2);
          expect(library.entry(id)!.pending, contains(1));
          expect(library.statusOf(id, 1).state, SurahAudioState.queued);
        case 'notFound':
          expect(count(scenario), 1);
          expect(library.statusOf(id, 1).state, SurahAudioState.failed);
        case 'pauseResume':
        case 'newRequest':
          expect(count(scenario), 2);
          expect(library.entry(id)!.pending, contains(1));
          expect(library.statusOf(id, 1).state, SurahAudioState.running);
        case 'deleteRecitation':
          expect(count(scenario), 1);
          expect(library.entry(id), isNull);
        default:
          expect(count(scenario), 1);
          expect(library.entry(id)!.pending, isEmpty);
          expect(library.statusOf(id, 1).state, SurahAudioState.none);
      }
    });
  }
  tearDownAll(() async {
    for (final id in ids.values) {
      await library.cancel(id);
    }
    messenger.setMockMethodCallHandler(channel, null);
    PathProviderPlatform.instance = originalDirs;
    debugDefaultTargetPlatformOverride = originalPlatform;
    await dir.delete(recursive: true);
  });
}
