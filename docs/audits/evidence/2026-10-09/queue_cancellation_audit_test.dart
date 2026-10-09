import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/db/models.dart';
import 'package:rafeeq_app/core/db/quran_repository.dart';
import 'package:rafeeq_app/core/services/ayah_audio_service.dart';

class DelayedRepo implements QuranRepository {
  final oldLoad = Completer<int>();
  final newLoad = Completer<int>();
  final oldEntered = Completer<void>();
  final newEntered = Completer<void>();
  @override
  Future<int> globalAyahNumber(int surah, int ayah) {
    if (ayah == 1) {
      if (!oldEntered.isCompleted) oldEntered.complete();
      return oldLoad.future;
    }
    newEntered.complete();
    return newLoad.future;
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const oldAyah = Ayah(id: 1, surahId: 1, ayahNumber: 1, textUthmani: '', pageNumber: 1, juzNumber: 1);
const newAyah = Ayah(id: 2, surahId: 1, ayahNumber: 2, textUthmani: '', pageNumber: 1, juzNumber: 1);

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  test('audit: cancelled old queue is accepted by replacement queue token', () async {
    for (final name in [
      'com.ryanheise.audio_session',
      'com.ryanheise.android_audio_manager',
      'com.ryanheise.just_audio.methods',
      'dev.fluttercommunity.plus/connectivity',
      'dev.fluttercommunity.plus/connectivity_status',
    ]) {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(MethodChannel(name), (call) async => null);
    }
    final service = AyahAudioService.instance;
    final repo = DelayedRepo();
    final staleNotice = Completer<String>();
    var oldAttempts = 0;
    final staleRetry = Completer<void>();
    ayahWaitingNotice = (s) {
      if (!staleNotice.isCompleted) staleNotice.complete(s);
    };
    final old = service.playQueue([oldAyah], repo,
        edition: AyahAudioService.defaultEdition, onIndex: (index) {
      oldAttempts++;
      if (oldAttempts == 2) staleRetry.complete();
    });
    await repo.oldEntered.future;
    await service.stopQueue();
    final replacement = service.playQueue([newAyah], repo, edition: AyahAudioService.defaultEdition);
    await repo.newEntered.future;
    repo.oldLoad.completeError(StateError('audit controlled old load failure'));
    final notice = await staleNotice.future.timeout(const Duration(seconds: 3));
    expect(notice, '1:1');
    print('AUDIT_PROOF: cancelled queue emitted waiting notice $notice after replacement 1:2 started');
    await staleRetry.future.timeout(const Duration(seconds: 23));
    expect(oldAttempts, 2);
    print('AUDIT_PROOF: cancelled queue retried its old ayah after the real 20-second recovery timer');
    await service.stopQueue();
    repo.newLoad.completeError(StateError('audit controlled new load cleanup'));
    await Future.wait([old, replacement]).timeout(const Duration(seconds: 3));
    ayahWaitingNotice = null;
    await service.dispose();
  });
}
