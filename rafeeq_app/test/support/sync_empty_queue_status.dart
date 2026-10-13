import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
// Exercise the actual native-auth channel implementation on the host.
// ignore: depend_on_referenced_packages
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:rafeeq_app/core/services/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

void syncEmptyQueueStatusTests() {
  GoogleSignInPlatform.instance = MethodChannelGoogleSignIn();

  test(
    'empty queue retains idle while real queued delivery reports syncing',
    () async {
      final previousPath = await databaseFactory.getDatabasesPath();
      final directory = Directory.systemTemp.createTempSync(
        'rafeeq-empty-sync-',
      );
      await databaseFactory.setDatabasesPath(directory.path);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final tokenStarted = Completer<void>();
      final tokenReply = Completer<void>();
      final pullSeen = Completer<void>();
      final postSeen = Completer<void>();
      final postReply = Completer<void>();
      messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/google_sign_in'),
        (call) async {
          if (call.method == 'signInSilently') {
            return {
              'email': 'sync-test@invalid.example',
              'id': 'empty-queue-owner',
            };
          }
          if (call.method == 'getTokens') {
            if (!tokenStarted.isCompleted) tokenStarted.complete();
            await tokenReply.future;
            return {'idToken': 'local-transport-test-only'};
          }
          return null;
        },
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/connectivity'),
        (_) async => ['wifi'],
      );
      messenger.setMockMessageHandler(
        'dev.fluttercommunity.plus/connectivity_status',
        (_) async => const StandardMethodCodec().encodeSuccessEnvelope(null),
      );
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final client = MockClient((request) async {
        if (request.method == 'GET') {
          if (!pullSeen.isCompleted) pullSeen.complete();
          return http.Response('{"state":[],"counters":[]}', 200);
        }
        if (!postSeen.isCompleted) postSeen.complete();
        await postReply.future;
        return http.Response('{"success":true}', 200);
      });
      final provider = Provider<SyncService>((ref) {
        final service = SyncService(GoogleSignIn(), prefs, ref, client: client);
        ref.onDispose(service.dispose);
        return service;
      });
      final container = ProviderContainer();
      final service = container.read(provider);
      Database? queue;
      Future<void> waitDone() async {
        final deadline = DateTime.now().add(const Duration(seconds: 3));
        while (container.read(syncStatusProvider) != SyncStatus.done &&
            DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(container.read(syncStatusProvider), SyncStatus.done);
      }

      try {
        await service.init();
        await tokenStarted.future.timeout(const Duration(seconds: 3));
        queue = await databaseFactory.openDatabase(
          p.join(directory.path, 'sync_queue.db'),
        );
        expect(await queue.query('queue'), isEmpty);
        expect(container.read(syncStatusProvider), SyncStatus.idle);
        expect(postSeen.isCompleted, isFalse);
        tokenReply.complete();
        await pullSeen.future.timeout(const Duration(seconds: 3));
        await waitDone();
        await service.incrementCounter('tasbeeh_total', 1);
        await postSeen.future.timeout(const Duration(seconds: 3));
        expect(container.read(syncStatusProvider), SyncStatus.syncing);
        expect(await queue.query('queue'), hasLength(1));
        postReply.complete();
        await waitDone();
        expect(await queue.query('queue'), isEmpty);
      } finally {
        if (!tokenReply.isCompleted) tokenReply.complete();
        if (!postReply.isCompleted) postReply.complete();
        service.dispose();
        container.dispose();
        client.close();
        await queue?.close();
        await databaseFactory.setDatabasesPath(previousPath);
        messenger.setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/google_sign_in'),
          null,
        );
        messenger.setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/connectivity'),
          null,
        );
        messenger.setMockMessageHandler(
          'dev.fluttercommunity.plus/connectivity_status',
          null,
        );
        expect(
          p.isWithin(
            Directory.systemTemp.resolveSymbolicLinksSync(),
            directory.resolveSymbolicLinksSync(),
          ),
          isTrue,
        );
        directory.deleteSync(recursive: true);
      }
    },
  );
}
