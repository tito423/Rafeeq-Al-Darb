import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
// Exercise the plugin's actual method-channel implementation on the host.
// ignore: depend_on_referenced_packages
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:rafeeq_app/core/services/sync_queue_batch.dart';
import 'package:rafeeq_app/core/services/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Real service and SQLite; only native auth/network and HTTP are controlled.
// The receiver applies the deployed Worker's verified 100/1000 array caps.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  GoogleSignInPlatform.instance = MethodChannelGoogleSignIn();

  for (final scenario in ['counters', 'states', 'large-state']) {
    for (final failSecond in [false, true]) {
      test(
        '$scenario survive ${failSecond ? 'a failed second batch' : 'the Worker caps'}',
        () async {
          final originalPath = await databaseFactory.getDatabasesPath();
          final directory = Directory.systemTemp.createTempSync('rafeeq-sync-');
          await databaseFactory.setDatabasesPath(directory.path);
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          var online = false;
          messenger.setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/google_sign_in'),
            (call) async {
              if (call.method == 'signInSilently') {
                return {
                  'email': 'sync-test@invalid.example',
                  'id': 'isolated-sync-test',
                };
              }
              if (call.method == 'getTokens') {
                return {'idToken': 'local-transport-test-only'};
              }
              return null;
            },
          );
          messenger.setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/connectivity'),
            (call) async => [online ? 'wifi' : 'none'],
          );
          messenger.setMockMessageHandler(
            'dev.fluttercommunity.plus/connectivity_status',
            (_) async =>
                const StandardMethodCodec().encodeSuccessEnvelope(null),
          );
          SharedPreferences.setMockInitialValues({});
          final prefs = await SharedPreferences.getInstance();
          final received = <String>{};
          final receivedStates = <String>{};
          final sizes = <int>[];
          final stateSizes = <int>[];
          var requests = 0;
          final client = MockClient((request) async {
            if (request.method == 'GET') {
              return http.Response('{"state":[],"counters":[]}', 200);
            }
            expect(
              request.bodyBytes.length,
              lessThanOrEqualTo(SyncQueueBatch.maxBodyBytes),
            );
            requests++;
            if (failSecond && requests == 2) return http.Response('', 503);
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final counters = body['counters'] as List<dynamic>;
            final states = body['updates'] as List<dynamic>;
            sizes.add(counters.length);
            stateSizes.add(states.length);
            expect(counters.length, lessThanOrEqualTo(1000));
            expect(states.length, lessThanOrEqualTo(100));
            for (final value in states.take(100)) {
              final state = value as Map<String, dynamic>;
              expect(
                (state['value'] as String).length,
                lessThanOrEqualTo(524288),
              );
              receivedStates.add('${state['key']}:${state['updated_at']}');
            }
            for (final value in counters.take(1000)) {
              received.add(
                (value as Map<String, dynamic>)['event_id'] as String,
              );
            }
            return http.Response('{"success":true}', 200);
          });
          final serviceProvider = Provider<SyncService>(
            (ref) => SyncService(GoogleSignIn(), prefs, ref, client: client),
          );
          final container = ProviderContainer();
          final service = container.read(serviceProvider);
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
            directory.deleteSync(recursive: true);
          });
          await service.init();
          queue = await databaseFactory.openDatabase(
            p.join(directory.path, 'sync_queue.db'),
          );
          expect(container.read(authStateProvider), isNotNull);
          if (scenario == 'counters') {
            for (var i = 0; i < 1000; i++) {
              await service.incrementCounter('tasbeeh_total', 1);
            }
          } else {
            final large = scenario == 'large-state';
            final keys = SyncService.syncedStateKeys.toList();
            await queue.transaction((txn) async {
              final inserts = txn.batch();
              for (var row = 0; row < (large ? 1 : 26); row++) {
                inserts.insert('queue', {
                  'type': 'state',
                  'payload': jsonEncode([
                    for (var k = 0; k < (large ? 2 : keys.length); k++)
                      {
                        'key': keys[k],
                        'value': large
                            ? jsonEncode('م' * 500000)
                            : jsonEncode(row),
                        'updated_at': row,
                      },
                  ]),
                });
              }
              await inserts.commit(noResult: true);
            });
          }
          expect(
            await queue.query('queue'),
            hasLength(
              scenario == 'counters'
                  ? 1000
                  : scenario == 'states'
                  ? 26
                  : 1,
            ),
          );
          online = true;
          await service.incrementCounter('tasbeeh_total', 1);
          final deadline = DateTime.now().add(const Duration(seconds: 10));
          while (![
                SyncStatus.done,
                SyncStatus.error,
                SyncStatus.failed,
              ].contains(container.read(syncStatusProvider)) &&
              DateTime.now().isBefore(deadline)) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
          expect(
            received,
            hasLength(
              scenario == 'counters'
                  ? (failSecond ? 1000 : 1001)
                  : (failSecond ? 0 : 1),
            ),
          );
          expect(
            receivedStates,
            hasLength(
              scenario == 'counters'
                  ? 0
                  : scenario == 'states'
                  ? (failSecond ? 100 : 104)
                  : (failSecond ? 1 : 2),
            ),
          );
          final remaining = await queue.query('queue');
          expect(
            remaining,
            hasLength(failSecond ? (scenario == 'counters' ? 1 : 2) : 0),
          );
          if (failSecond && scenario == 'large-state') {
            expect(
              (jsonDecode(remaining.first['payload'] as String) as List),
              hasLength(2),
            );
          }
          expect(
            container.read(syncStatusProvider),
            failSecond ? SyncStatus.error : SyncStatus.done,
          );
          expect(
            sizes,
            scenario == 'counters'
                ? (failSecond ? [1000] : [1000, 1])
                : (failSecond ? [0] : [0, 1]),
          );
          expect(
            stateSizes,
            scenario == 'counters'
                ? (failSecond ? [0] : [0, 0])
                : scenario == 'states'
                ? (failSecond ? [100] : [100, 4])
                : (failSecond ? [1] : [1, 1]),
          );
          if (failSecond) {
            // A later change triggers a retry; the same event IDs and full
            // split state row survive, without counting an event twice.
            await service.incrementCounter('tasbeeh_total', 1);
            final retryDeadline = DateTime.now().add(
              const Duration(seconds: 10),
            );
            while (container.read(syncStatusProvider) != SyncStatus.done &&
                DateTime.now().isBefore(retryDeadline)) {
              await Future<void>.delayed(const Duration(milliseconds: 10));
            }
            expect(container.read(syncStatusProvider), SyncStatus.done);
            expect(await queue.query('queue'), isEmpty);
            expect(received, hasLength(scenario == 'counters' ? 1002 : 2));
            expect(
              receivedStates,
              hasLength(
                scenario == 'counters'
                    ? 0
                    : scenario == 'states'
                    ? 104
                    : 2,
              ),
            );
          }
        },
      );
    }
  }

  test('a split state row is acknowledged only in its final batch', () {
    final batches = syncQueueBatches([
      {
        'id': 7,
        'type': 'state',
        'payload': jsonEncode([
          for (var i = 0; i < 101; i++)
            {'key': 'quran_last_page', 'value': '$i', 'updated_at': i},
        ]),
      },
    ]).toList();
    expect(batches, hasLength(2));
    expect(batches.first.completedIds, isEmpty);
    expect(batches.last.completedIds, [7]);
  });

  test('a state the Worker would silently ignore is never acknowledged', () {
    final batches = syncQueueBatches([
      {
        'id': 9,
        'type': 'state',
        'payload': jsonEncode([
          {'key': 'ayah_notes_v1', 'value': 'x' * 524289, 'updated_at': 1},
        ]),
      },
    ]);
    expect(batches.toList, throwsFormatException);
  });
}
