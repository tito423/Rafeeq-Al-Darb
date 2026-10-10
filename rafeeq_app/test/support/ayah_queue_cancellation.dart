import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/db/models.dart';
import 'package:rafeeq_app/core/db/quran_repository.dart';
import 'package:rafeeq_app/core/services/ayah_audio_service.dart';

class _DelayedQueueRepository implements QuranRepository {
  final oldLoad = Completer<int>();
  final newLoad = Completer<int>();
  final oldEntered = Completer<void>();
  final newEntered = Completer<void>();

  @override
  Future<int> globalAyahNumber(int surah, int ayah) {
    final entered = ayah == 1 ? oldEntered : newEntered;
    if (!entered.isCompleted) entered.complete();
    return ayah == 1 ? oldLoad.future : newLoad.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _oldAyah = Ayah(
  id: 1,
  surahId: 1,
  ayahNumber: 1,
  textUthmani: '',
  pageNumber: 1,
  juzNumber: 1,
);
const _newAyah = Ayah(
  id: 2,
  surahId: 1,
  ayahNumber: 2,
  textUthmani: '',
  pageNumber: 1,
  juzNumber: 1,
);

Future<void> disposeQueueService() => AyahAudioService.instance.dispose();

/// Real service, delayed repository lookup, and controlled audio channels.
Future<void> verifyCancelledQueue({required bool lookupFails}) async {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final dynamicChannels = <String>[];
  var sourceLoads = 0;
  for (final name in [
    'com.ryanheise.audio_session',
    'com.ryanheise.android_audio_manager',
    'dev.fluttercommunity.plus/connectivity',
  ]) {
    messenger.setMockMethodCallHandler(MethodChannel(name), (_) async => null);
  }
  messenger.setMockMessageHandler(
    'dev.fluttercommunity.plus/connectivity_status',
    (_) async => const StandardMethodCodec().encodeSuccessEnvelope(null),
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('com.ryanheise.just_audio.methods'),
    (call) async {
      if (call.method == 'init') {
        final arguments = call.arguments as Map<Object?, Object?>;
        final id = arguments['id'] as String;
        final methods = 'com.ryanheise.just_audio.methods.$id';
        dynamicChannels.add(methods);
        messenger.setMockMethodCallHandler(MethodChannel(methods), (
          call,
        ) async {
          if (call.method == 'load') sourceLoads++;
          // A controlled failed host cannot make real HTTP/media requests.
          if (call.method == 'load') throw PlatformException(code: 'test-load');
          return <String, Object?>{};
        });
        for (final kind in ['events', 'data']) {
          final name = 'com.ryanheise.just_audio.$kind.$id';
          dynamicChannels.add(name);
          messenger.setMockMessageHandler(
            name,
            (_) async =>
                const StandardMethodCodec().encodeSuccessEnvelope(null),
          );
        }
      }
      return <String, Object?>{};
    },
  );

  final service = AyahAudioService.instance;
  final repo = _DelayedQueueRepository();
  final notices = <String>[];
  var attempts = 0;
  ayahWaitingNotice = notices.add;
  final old = service.playQueue(
    [_oldAyah],
    repo,
    edition: AyahAudioService.defaultEdition,
    onIndex: (_) => attempts++,
  );
  await repo.oldEntered.future.timeout(const Duration(seconds: 3));
  await service.stopQueue();
  expect(service.isQueuePlaying, isFalse);
  final replacement = service.playQueue(
    [_newAyah],
    repo,
    edition: AyahAudioService.defaultEdition,
  );
  await repo.newEntered.future.timeout(const Duration(seconds: 3));
  expect(service.isQueuePlaying, isTrue);
  addTearDown(() async {
    await service.stopQueue();
    if (!repo.oldLoad.isCompleted) {
      repo.oldLoad.completeError(StateError('cleanup'));
    }
    if (!repo.newLoad.isCompleted) {
      repo.newLoad.completeError(StateError('cleanup'));
    }
    await Future.wait([old, replacement]).timeout(const Duration(seconds: 3));
    ayahWaitingNotice = null;
    for (final name in dynamicChannels) {
      messenger.setMockMethodCallHandler(MethodChannel(name), null);
      messenger.setMockMessageHandler(name, null);
    }
    for (final name in [
      'com.ryanheise.audio_session',
      'com.ryanheise.android_audio_manager',
      'com.ryanheise.just_audio.methods',
      'dev.fluttercommunity.plus/connectivity',
    ]) {
      messenger.setMockMethodCallHandler(MethodChannel(name), null);
    }
    messenger.setMockMessageHandler(
      'dev.fluttercommunity.plus/connectivity_status',
      null,
    );
  });
  if (lookupFails) {
    repo.oldLoad.completeError(StateError('controlled delayed lookup failure'));
  } else {
    repo.oldLoad.complete(1);
  }
  await Future<void>.delayed(const Duration(milliseconds: 100));
  expect(notices, isEmpty, reason: 'Cancelled verse must not announce waiting');
  expect(
    sourceLoads,
    0,
    reason: 'Cancelled lookup must not load any audio host',
  );
  await old.timeout(const Duration(seconds: 1));
  expect(attempts, 1);
  expect(
    service.isQueuePlaying,
    isTrue,
    reason: 'Old completion must not clear replacement',
  );
  await service.stopQueue();
  repo.newLoad.completeError(StateError('controlled replacement cleanup'));
  await replacement.timeout(const Duration(seconds: 1));
  expect(service.isQueuePlaying, isFalse);
}
