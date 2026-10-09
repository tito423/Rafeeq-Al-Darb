import 'dart:convert';
import 'dart:io';
import 'package:background_downloader/background_downloader.dart';
import 'package:background_downloader/src/persistent_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rafeeq_app/core/services/download_engine.dart';
import 'package:rafeeq_app/features/quran_audio/data/mp3quran_api.dart';
import 'package:rafeeq_app/features/quran_audio/data/quran_audio_library.dart';

class AuditDirs extends Fake with MockPlatformInterfaceMixin implements PathProviderPlatform {
  AuditDirs(this.path);
  final String path;
  @override Future<String?> getApplicationDocumentsPath() async => path;
  @override Future<String?> getApplicationSupportPath() async => path;
  @override Future<String?> getTemporaryPath() async => path;
}

class AuditStorage extends Fake implements PersistentStorage {
  @override Future<void> initialize() async {}
  @override Future<List<TaskRecord>> retrieveAllTaskRecords() async => [];
  @override Future<List<Task>> retrieveAllPausedTasks() async => [];
  @override Future<List<ResumeData>> retrieveAllResumeData() async => [];
  @override Future<Task?> retrievePausedTask(String id) async => null;
  @override Future<ResumeData?> retrieveResumeData(String id) async => null;
  @override Future<void> removePausedTask(String? id) async {}
  @override Future<void> removeResumeData(String? id) async {}
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  test('audit: minute retry restarts an explicitly canceled surah', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('rafeeq_surah_retry_audit_');
    PathProviderPlatform.instance = AuditDirs(dir.path);
    FileDownloader(persistentStorage: AuditStorage());
    await FileDownloader().ready;
    final enqueued = <Map<String, dynamic>>[];
    const channel = MethodChannel('com.bbflight.background_downloader');
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      print('AUDIT_NATIVE_CALL: ${call.method}');
      if (call.method == 'enqueue') {
        enqueued.add(jsonDecode((call.arguments as List).first as String) as Map<String, dynamic>);
        return true;
      }
      if (call.method == 'allTasks') return <dynamic>[];
      if (call.method == 'permissionStatus') return 0;
      if (call.method == 'requestPermission') return false;
      if (call.method == 'cancelTasksWithIds') return true;
      return null;
    });
    const moshaf = Mp3Moshaf(id: 987654, name: 'Audit fixture', server: 'https://example.invalid/audit/', surahs: [1]);
    const reciter = Mp3Reciter(id: 987654, name: 'Audit fixture', moshafs: [moshaf]);
    final library = QuranAudioLibrary.instance;
    await (() async {
      print('AUDIT_STAGE: ensureReady');
      await library.ensureReady().timeout(const Duration(seconds: 15));
      print('AUDIT_STAGE: ready');
      // Let automatic startup repair settle before the fixture download.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await library.download(reciter, moshaf, only: [1]).timeout(const Duration(seconds: 15));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    })();
    expect(enqueued, hasLength(1));
    final task = DownloadTask(taskId: QuranAudioLibrary.taskIdFor(moshaf.id, 1),
      url: moshaf.originUrlFor(1), filename: '001.mp3', group: DownloadEngine.groupQuranAudio);
    // Actual plugin update stream -> actual DownloadEngine -> actual library.
    FileDownloader().downloaderForTesting.updates.add(TaskStatusUpdate(task, TaskStatus.failed));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(library.statusOf(moshaf.id, 1).state, SurahAudioState.failed);
    await library.cancelSurah(moshaf.id, 1);
    expect(library.entry(moshaf.id)!.pending, isEmpty);
    expect(library.statusOf(moshaf.id, 1).state, SurahAudioState.none);
    await Future<void>.delayed(const Duration(seconds: 61));
    expect(enqueued, hasLength(2));
    expect(library.entry(moshaf.id)!.pending, isEmpty);
    expect(library.statusOf(moshaf.id, 1).state, SurahAudioState.queued);
    print('AUDIT_PROOF: cancelSurah cleared pending and status; actual 60-second retry enqueued qa_987654_1 again with pending still empty. Native transfer itself mocked, no network download.');
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
    await dir.delete(recursive: true);
  });
}
