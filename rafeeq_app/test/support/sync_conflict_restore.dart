import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
// Exercise the real method-channel auth transport without a live account.
// ignore: depend_on_referenced_packages
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:rafeeq_app/core/config/prefs_provider.dart';
import 'package:rafeeq_app/core/db/quran_repository.dart';
import 'package:rafeeq_app/core/services/sync_service.dart';
import 'package:rafeeq_app/core/services/sync_state_journal.dart';
import 'package:rafeeq_app/core/services/syncable_shared_preferences.dart';
import 'package:rafeeq_app/features/khatma/data/khatma_store.dart';
import 'package:rafeeq_app/features/quran/data/ayah_notes_store.dart';
import 'package:rafeeq_app/features/quran/data/quran_last_read.dart';
import 'package:rafeeq_app/features/quran/presentation/widgets/continue_reading_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

/// Actual SyncService and SQLite; Google/connectivity/HTTP are controlled.
Future<void> verifySyncConflict({
  required int? localPage,
  required Object? remotePage,
  required Object? remoteTimestamp,
  required int? expectedPage,
  bool editDuringPull = false,
  bool observeLastPage = false,
  bool observeNotes = false,
  bool observeKhatma = false,
  bool incrementDuringPull = false,
  bool incrementBeforePull = false,
  bool counterReplyAfterPull = false,
  bool editDuringPreferenceReply = false,
  bool signOutDuringPreferenceReply = false,
  int? localTimestamp,
  bool offlineRestart = false,
  bool switchAccounts = false,
  bool signOutDuringPull = false,
  bool writeCustomTargetDuringPull = false,
  WidgetTester? visualTester,
  Future<void> Function()? screenshotReady,
}) async {
  final originalPath = await databaseFactory.getDatabasesPath();
  final directory = await Directory.systemTemp.createTemp('rafeeq-conflict-');
  await databaseFactory.setDatabasesPath(directory.path);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  GoogleSignInPlatform.instance = MethodChannelGoogleSignIn();
  var currentAccount = 'conflict-one';
  final auth = GoogleSignIn();
  var tokenCalls = 0;
  Future<void> Function()? beforePullAuthentication;
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/google_sign_in'),
    (call) async {
      if (call.method == 'signInSilently' || call.method == 'signIn') {
        return {
          'email': '$currentAccount@invalid.example',
          'id': currentAccount,
        };
      }
      if (call.method == 'getTokens') {
        tokenCalls++;
        if (tokenCalls == 2 && beforePullAuthentication != null) {
          await beforePullAuthentication();
        }
        return {'idToken': 'local-${(call.arguments as Map)['email']}'};
      }
      return null;
    },
  );
  var online = !offlineRestart;
  messenger.setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/connectivity'),
    (_) async => [online ? 'wifi' : 'none'],
  );
  messenger.setMockMessageHandler(
    'dev.fluttercommunity.plus/connectivity_status',
    (_) async => const StandardMethodCodec().encodeSuccessEnvelope(null),
  );
  SharedPreferences.setMockInitialValues({
    'quran_last_page': ?localPage,
    'language': 'ar',
    'local_reader_font': 24,
    if (incrementDuringPull || incrementBeforePull || counterReplyAfterPull)
      'tasbeeh_total': 5,
  });
  final prefs = await SharedPreferences.getInstance();
  Database? quranDatabase;
  QuranRepository? quranRepository;
  if (visualTester != null) {
    final original = await rootBundle.load('assets/data/quran_local.db');
    final copy = File(p.join(directory.path, 'quran-readonly.db'));
    await copy.writeAsBytes(
      original.buffer.asUint8List(
        original.offsetInBytes,
        original.lengthInBytes,
      ),
    );
    quranDatabase = await databaseFactory.openDatabase(
      copy.path,
      options: OpenDatabaseOptions(readOnly: true),
    );
    quranRepository = QuranRepository(quranDatabase);
  }
  if (localTimestamp != null) {
    await SyncStateJournal(
      prefs,
      'conflict-one',
    ).received('quran_last_page', jsonEncode(localPage), localTimestamp);
  }
  final responseSent = Completer<void>();
  final posts = <Map<String, dynamic>>[];
  final postOwners = <String>[];
  var firstAccountPushAccepted = !switchAccounts;
  final counterReply = Completer<void>();
  Database? queue;
  late ProviderContainer container;
  final servicePrefs = _ReplyPreferences(prefs, () async {
    if (signOutDuringPreferenceReply) {
      await container.read(syncServiceProvider).signOut();
    }
    if (editDuringPreferenceReply) {
      await container.read(quranLastPageProvider.notifier).set(543);
    }
  });
  final client = MockClient((request) async {
    if (request.method == 'POST') {
      posts.add(jsonDecode(request.body) as Map<String, dynamic>);
      final owner =
          request.headers['authorization'] ?? request.headers['Authorization']!;
      postOwners.add(owner);
      if ((incrementBeforePull || counterReplyAfterPull) &&
          (jsonDecode(request.body) as Map)['counters'] is List &&
          ((jsonDecode(request.body) as Map)['counters'] as List).isNotEmpty) {
        await counterReply.future;
      }
      if (switchAccounts &&
          owner.contains('conflict-one') &&
          !firstAccountPushAccepted) {
        return http.Response('', 503);
      }
      return http.Response('{"success":true}', 200);
    }
    if (editDuringPull) {
      await container.read(sharedPrefsProvider).setInt('quran_last_page', 543);
    }
    if (writeCustomTargetDuringPull) {
      await container
          .read(sharedPrefsProvider)
          .setInt('tasbeeh_custom_target', 75);
    }
    if (signOutDuringPull) await container.read(syncServiceProvider).signOut();
    if (incrementDuringPull || incrementBeforePull || counterReplyAfterPull) {
      // Mirror the real counter producer while the earlier GET is pending.
      if (!incrementBeforePull) {
        await prefs.setInt('tasbeeh_total', 6);
        await container
            .read(syncServiceProvider)
            .incrementCounter('tasbeeh_total', 1);
      } else {
        counterReply.complete();
      }
      final deliveryQueue = await databaseFactory.openDatabase(
        p.join(directory.path, 'sync_queue.db'),
      );
      queue = deliveryQueue;
      final deadline = DateTime.now().add(const Duration(seconds: 3));
      while (!counterReplyAfterPull &&
          (await deliveryQueue.query('queue')).isNotEmpty &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      // Prove the new event was acknowledged before returning the stale GET.
      if (!counterReplyAfterPull) {
        expect(posts.expand((body) => body['counters'] as List), hasLength(1));
        expect(await deliveryQueue.query('queue'), isEmpty);
      }
    }
    if (!responseSent.isCompleted) responseSent.complete();
    return http.Response(
      jsonEncode({
        'state': [
          {
            'key': 'quran_last_page',
            'value': jsonEncode(
              switchAccounts && currentAccount == 'conflict-two'
                  ? 23
                  : remotePage,
            ),
            'updated_at': remoteTimestamp,
          },
          {'key': 'language', 'value': '"en"', 'updated_at': 9999999999999},
          if (writeCustomTargetDuringPull)
            {'key': 'tasbeeh_custom_target', 'value': '33', 'updated_at': 100},
          if (observeNotes)
            {
              'key': 'ayah_notes_v1',
              'value': jsonEncode(
                jsonEncode({'2:255': 'Local sync regression'}),
              ),
              'updated_at': 100,
            },
          if (observeKhatma)
            {
              'key': 'khatma_list_v1',
              'value': jsonEncode(
                jsonEncode([
                  Khatma(
                    id: 'local-sync-regression',
                    startDate: DateTime(2026, 10, 12),
                    mode: KhatmaMode.dailyPages,
                    dailyAmount: 5,
                    pagesRead: 20,
                  ).toJson(),
                ]),
              ),
              'updated_at': 100,
            },
        ],
        'counters': [
          if (incrementDuringPull ||
              incrementBeforePull ||
              counterReplyAfterPull)
            {'key': 'tasbeeh_total', 'total': counterReplyAfterPull ? 6 : 5},
        ],
      }),
      200,
    );
  });
  ProviderContainer newContainer() => ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      if (quranRepository != null)
        quranRepositoryProvider.overrideWith((_) async => quranRepository!),
      sharedPrefsProvider.overrideWith(
        (ref) => SyncableSharedPreferences(prefs, ref),
      ),
      syncServiceProvider.overrideWith((ref) {
        final service = SyncService(auth, servicePrefs, ref, client: client);
        ref.onDispose(service.dispose);
        return service;
      }),
    ],
  );
  container = newContainer();
  if (incrementBeforePull) {
    beforePullAuthentication = () async {
      await prefs.setInt('tasbeeh_total', 6);
      await container
          .read(syncServiceProvider)
          .incrementCounter('tasbeeh_total', 1);
    };
  }
  if (observeLastPage) {
    expect(container.read(quranLastPageProvider), localPage);
  }
  if (observeNotes) expect(container.read(ayahNotesProvider), isEmpty);
  if (observeKhatma) expect(container.read(khatmaStoreProvider), isEmpty);
  addTearDown(() async {
    if (visualTester != null) {
      await visualTester.pumpWidget(const SizedBox.shrink());
      await visualTester.pumpAndSettle();
    }
    container.dispose();
    if (!counterReply.isCompleted) counterReply.complete();
    client.close();
    await queue?.close();
    await quranDatabase?.close();
    // Reopen with the old APK's exact version-one contract after closing the
    // new service. Extra columns/tables must not cause a downgrade failure.
    final legacy = await databaseFactory.openDatabase(
      p.join(directory.path, 'sync_queue.db'),
      options: OpenDatabaseOptions(version: 1),
    );
    expect(
      (await legacy.rawQuery('PRAGMA user_version')).single.values.single,
      1,
    );
    await legacy.query('queue', columns: ['id', 'type', 'payload']);
    await legacy.close();
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
    expect(p.basename(resolved), startsWith('rafeeq-conflict-'));
    directory.deleteSync(recursive: true);
  });
  await container.read(syncServiceProvider).init();
  if (switchAccounts) {
    Future<void> until(Future<bool> Function() condition) async {
      final deadline = DateTime.now().add(const Duration(seconds: 4));
      while (!await condition() && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(await condition(), isTrue);
    }

    await until(
      () async =>
          posts.isNotEmpty &&
          container.read(syncStatusProvider) == SyncStatus.error,
    );
    queue = await databaseFactory.openDatabase(
      p.join(directory.path, 'sync_queue.db'),
    );
    expect(await queue!.query('queue'), hasLength(1));
    currentAccount = 'conflict-two';
    await auth.signInSilently(reAuthenticate: true);
    await until(
      () async =>
          prefs.getInt('quran_last_page') == 23 &&
          (!observeLastPage || container.read(quranLastPageProvider) == 23),
    );
    expect(container.read(authStateProvider)!.id, 'conflict-two');
    if (observeLastPage) expect(container.read(quranLastPageProvider), 23);
    expect(await queue!.query('queue'), isEmpty);
    final archived = await queue!.query('sync_account_queue');
    expect(archived, hasLength(1));
    expect(archived.single['account_id'], 'conflict-one');
    expect(
      postOwners.where((owner) => owner.contains('conflict-two')),
      isEmpty,
    );
    await container.read(sharedPrefsProvider).setInt('quran_last_page', 24);
    firstAccountPushAccepted = true;
    currentAccount = 'conflict-one';
    await auth.signInSilently(reAuthenticate: true);
    await until(
      () async =>
          prefs.getInt('quran_last_page') == 541 &&
          postOwners.where((owner) => owner.contains('conflict-one')).length ==
              2 &&
          (await queue!.query('queue')).isEmpty,
    );
    expect(
      SyncStateJournal(prefs, 'conflict-two').entries['quran_last_page']!['v'],
      '24',
    );
    expect(container.read(authStateProvider)!.id, 'conflict-one');
    expect(await queue!.query('sync_account_queue'), isEmpty);
  }
  int? savedMutationTime;
  if (offlineRestart) {
    final deadline = DateTime.now().add(const Duration(seconds: 4));
    while (prefs.getString(SyncStateJournal.ownerKey) != 'conflict-one' &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(prefs.getString(SyncStateJournal.ownerKey), 'conflict-one');
    queue = await databaseFactory.openDatabase(
      p.join(directory.path, 'sync_queue.db'),
    );
    Future<bool> initialStateQueued() async =>
        (await queue!.query('queue')).any(
          (row) => (jsonDecode(row['payload'] as String) as List)
              .cast<Map<String, dynamic>>()
              .any(
                (item) =>
                    item['key'] == 'quran_last_page' && item['value'] == '541',
              ),
        );
    while (!await initialStateQueued() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(await initialStateQueued(), isTrue);
    await container.read(sharedPrefsProvider).setInt('quran_last_page', 543);
    savedMutationTime =
        SyncStateJournal(prefs, 'conflict-one').entries['quran_last_page']!['t']
            as int;
    expect(posts, isEmpty);
    container.dispose();
    final closing = await databaseFactory.openDatabase(
      p.join(directory.path, 'sync_queue.db'),
    );
    await closing.close();
    online = true;
    container = newContainer();
    await container.read(syncServiceProvider).init();
  }
  await responseSent.future.timeout(const Duration(seconds: 4));
  queue = await databaseFactory.openDatabase(
    p.join(directory.path, 'sync_queue.db'),
  );
  // Wait for the asynchronous pull to finish writing, not just its HTTP reply.
  await Future<void>.delayed(const Duration(milliseconds: 150));
  expect(prefs.getString('language'), 'ar');
  expect(prefs.getInt('local_reader_font'), 24);
  expect(prefs.getInt('quran_last_page'), expectedPage);
  if (editDuringPreferenceReply) {
    final saved = SyncStateJournal(prefs, 'conflict-one');
    expect(saved.entries['quran_last_page']!['v'], '543');
    expect(saved.entries['quran_last_page']!['d'], isTrue);
  }
  if (writeCustomTargetDuringPull) {
    expect(prefs.getInt('tasbeeh_custom_target'), 75);
    final saved = SyncStateJournal(prefs, 'conflict-one');
    expect(saved.entries['tasbeeh_custom_target']!['d'], isTrue);
    expect(saved.entries['quran_last_page']!['t'], remoteTimestamp);
  }
  if (signOutDuringPull || signOutDuringPreferenceReply) {
    expect(container.read(authStateProvider), isNull);
    expect(prefs.getString(SyncStateJournal.ownerKey), isNull);
    expect(SyncStateJournal(prefs, 'conflict-one').entries, isEmpty);
    expect(SyncStateJournal(prefs, null).entries, isEmpty);
    expect(await queue!.query('queue'), isEmpty);
  }
  if (offlineRestart) {
    final latest = posts
        .expand(
          (body) => (body['updates'] as List).cast<Map<String, dynamic>>(),
        )
        .where(
          (row) => row['key'] == 'quran_last_page' && row['value'] == '543',
        )
        .toList();
    expect(latest, isNotEmpty);
    expect(latest.last['updated_at'], savedMutationTime);
    expect(await queue!.query('queue'), isEmpty);
  }
  if (incrementDuringPull || incrementBeforePull || counterReplyAfterPull) {
    expect(prefs.getInt('tasbeeh_total'), 6);
    if (counterReplyAfterPull) {
      expect(
        await queue!.query('queue', where: 'type = ?', whereArgs: ['counter']),
        hasLength(1),
      );
      expect(posts.expand((body) => body['counters'] as List), hasLength(1));
      counterReply.complete();
      final deadline = DateTime.now().add(const Duration(seconds: 3));
      while ((await queue!.query('queue')).isNotEmpty &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(await queue!.query('queue'), isEmpty);
      expect(prefs.getInt('tasbeeh_total'), 6);
    }
  }
  if (observeLastPage) {
    expect(container.read(quranLastPageProvider), expectedPage);
  }
  if (observeNotes) {
    expect(jsonDecode(prefs.getString('ayah_notes_v1')!), {
      '2:255': 'Local sync regression',
    });
    expect(container.read(ayahNotesProvider), {
      '2:255': 'Local sync regression',
    });
  }
  if (observeKhatma) {
    final saved = (jsonDecode(prefs.getString('khatma_list_v1')!) as List)
        .cast<Map<String, dynamic>>();
    expect(saved.single['pagesRead'], 20);
    final plans = container.read(khatmaStoreProvider);
    expect(plans, hasLength(1));
    expect(plans.single.id, 'local-sync-regression');
    expect(plans.single.pagesRead, 20);
  }
  if (localPage != null && !editDuringPull && localTimestamp == null) {
    // An existing local value with no trustworthy old timestamp must be
    // migrated and sent before an old remote snapshot can replace it.
    expect(
      posts
          .expand(
            (body) => (body['updates'] as List).cast<Map<String, dynamic>>(),
          )
          .any(
            (row) =>
                row['key'] == 'quran_last_page' &&
                row['value'] == jsonEncode(localPage),
          ),
      isTrue,
    );
  }
  if (visualTester != null) {
    await EasyLocalization.ensureInitialized();
    await visualTester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: EasyLocalization(
          supportedLocales: const [Locale('en')],
          startLocale: const Locale('en'),
          fallbackLocale: const Locale('en'),
          path: 'assets/translations',
          saveLocale: false,
          child: const _SyncCardVerification(),
        ),
      ),
    );
    await visualTester.pumpAndSettle();
    final visibleDeadline = DateTime.now().add(const Duration(seconds: 4));
    while (find.textContaining('540').evaluate().isEmpty &&
        DateTime.now().isBefore(visibleDeadline)) {
      await visualTester.pump(const Duration(milliseconds: 100));
    }
    expect(visualTester.takeException(), isNull);
    expect(find.byType(ContinueReadingCard), findsOneWidget);
    expect(find.textContaining('540'), findsOneWidget);
    // Submit a settled frame to the actual Android surface before capture.
    // The widget tree can be current before API24 has rasterized the card.
    await visualTester.pump(const Duration(milliseconds: 450));
    if (screenshotReady != null) await screenshotReady();
  }
}

/// All reads and persistence use the actual prefs instance. Only the first
/// remote integer-write reply is held to exercise a real local edit in flight.
class _ReplyPreferences implements SharedPreferences {
  _ReplyPreferences(this.delegate, this.onReply);
  final SharedPreferences delegate;
  final Future<void> Function() onReply;
  bool held = false;
  @override
  Future<bool> setInt(String key, int value) async {
    final result = await delegate.setInt(key, value);
    if (key == 'quran_last_page' && !held) {
      held = true;
      await onReply();
    }
    return result;
  }

  @override
  Object? get(String key) => delegate.get(key);
  @override
  Set<String> getKeys() => delegate.getKeys();
  @override
  bool containsKey(String key) => delegate.containsKey(key);
  @override
  int? getInt(String key) => delegate.getInt(key);
  @override
  String? getString(String key) => delegate.getString(key);
  @override
  bool? getBool(String key) => delegate.getBool(key);
  @override
  double? getDouble(String key) => delegate.getDouble(key);
  @override
  List<String>? getStringList(String key) => delegate.getStringList(key);
  @override
  Future<bool> setString(String key, String value) =>
      delegate.setString(key, value);
  @override
  Future<bool> setBool(String key, bool value) => delegate.setBool(key, value);
  @override
  Future<bool> setDouble(String key, double value) =>
      delegate.setDouble(key, value);
  @override
  Future<bool> setStringList(String key, List<String> value) =>
      delegate.setStringList(key, value);
  @override
  Future<bool> remove(String key) => delegate.remove(key);
  @override
  Future<bool> clear() => delegate.clear();
  @override
  Future<void> reload() => delegate.reload();
  @override
  // ignore: deprecated_member_use
  Future<bool> commit() => delegate.commit();
}

/// The actual Home card with its real bundled Quran data, inside a clearly
/// identified local regression view. Auth and HTTP remain controlled.
class _SyncCardVerification extends StatelessWidget {
  const _SyncCardVerification();
  @override
  Widget build(BuildContext context) => MaterialApp(
    locale: context.locale,
    supportedLocales: context.supportedLocales,
    localizationsDelegates: context.localizationDelegates,
    theme: ThemeData.dark(),
    home: const Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Column(
            children: [
              Text('Local sync regression: controlled auth and HTTP'),
              SizedBox(height: 18),
              ContinueReadingCard(),
            ],
          ),
        ),
      ),
    ),
  );
}
