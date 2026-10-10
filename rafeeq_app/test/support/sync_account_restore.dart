import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
// Exercise the auth method-channel implementation without using a real account.
// ignore: depend_on_referenced_packages
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:rafeeq_app/core/services/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

/// Real SyncService/SQLite on host or Android; only auth/network/HTTP controlled.
Future<void> verifyAccountRestoreQueue({required bool rejectPush}) async {
  final originalPath = await databaseFactory.getDatabasesPath();
  final directory = await Directory.systemTemp.createTemp('rafeeq-sign-in-');
  await databaseFactory.setDatabasesPath(directory.path);
  final dbPath = p.join(directory.path, 'sync_queue.db');
  final seeded = await databaseFactory.openDatabase(
    dbPath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE queue (id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'type TEXT NOT NULL, payload TEXT NOT NULL)',
        );
      },
    ),
  );
  await seeded.insert('queue', {
    'type': 'counter',
    'payload': jsonEncode({
      'key': 'tasbeeh_total',
      'event_id': '48dbd813-9654-4688-8427-109469d14103',
      'increment_value': 3,
    }),
  });
  await seeded.insert('queue', {
    'type': 'state',
    'payload': jsonEncode([
      {'key': 'quran_last_page', 'value': '541', 'updated_at': 100},
    ]),
  });
  await seeded.close();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  GoogleSignInPlatform.instance = MethodChannelGoogleSignIn();
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/google_sign_in'),
    (call) async {
      if (call.method == 'signInSilently' || call.method == 'signIn') {
        return {
          'email': 'restore-test@invalid.example',
          'id': 'isolated-restore-test',
        };
      }
      if (call.method == 'getTokens') return {'idToken': 'local-test-only'};
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
  SharedPreferences.setMockInitialValues({
    'tasbeeh_total': 5,
    'quran_last_page': 541,
  });
  final prefs = await SharedPreferences.getInstance();
  final requests = <String>[];
  var serverTotal = 2;
  var serverPage = '540';
  final client = MockClient((request) async {
    requests.add(request.method);
    if (request.method == 'POST') {
      if (rejectPush) return http.Response('', 503);
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      for (final counter
          in (body['counters'] as List).cast<Map<String, dynamic>>()) {
        serverTotal += (counter['increment_value'] as num).toInt();
      }
      for (final state
          in (body['updates'] as List).cast<Map<String, dynamic>>()) {
        if (state['key'] == 'quran_last_page') {
          serverPage = state['value'] as String;
        }
      }
      return http.Response('{"success":true}', 200);
    }
    return http.Response(
      jsonEncode({
        'state': [
          {'key': 'quran_last_page', 'value': serverPage, 'updated_at': 100},
        ],
        'counters': [
          {'key': 'tasbeeh_total', 'total': serverTotal},
        ],
      }),
      200,
    );
  });
  final provider = Provider<SyncService>((ref) {
    final service = SyncService(GoogleSignIn(), prefs, ref, client: client);
    ref.onDispose(service.dispose);
    return service;
  });
  final container = ProviderContainer();
  Database? queue;
  addTearDown(() async {
    container.dispose();
    client.close();
    await queue?.close();
    await databaseFactory.setDatabasesPath(originalPath);
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
    final tempRoot = Directory.systemTemp.resolveSymbolicLinksSync();
    final resolved = directory.resolveSymbolicLinksSync();
    expect(p.isWithin(tempRoot, resolved), isTrue);
    expect(p.basename(resolved), startsWith('rafeeq-sign-in-'));
    directory.deleteSync(recursive: true);
  });

  await container.read(provider).init();
  queue = await databaseFactory.openDatabase(dbPath);
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (DateTime.now().isBefore(deadline)) {
    if (rejectPush ? requests.contains('POST') : requests.length >= 2) break;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  // Let the listener finish its SQLite acknowledgement or failed-push check.
  await Future<void>.delayed(const Duration(milliseconds: 100));
  expect(container.read(authStateProvider), isNotNull);
  expect(requests, rejectPush ? ['POST'] : ['POST', 'GET']);
  expect(await queue.query('queue'), hasLength(rejectPush ? 2 : 0));
  expect(prefs.getInt('tasbeeh_total'), 5);
  expect(prefs.getInt('quran_last_page'), 541);
  expect(serverTotal, rejectPush ? 2 : 5);
  expect(
    container.read(syncStatusProvider),
    rejectPush ? SyncStatus.error : SyncStatus.done,
  );
}
