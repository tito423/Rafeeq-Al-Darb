import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import 'sync_queue_batch.dart';
import 'sync_state_journal.dart';

final googleSignInProvider = Provider(
  (ref) => GoogleSignIn(
    serverClientId: AppConfig.googleServerClientId,
    scopes: ['email', 'profile'],
  ),
);

final authStateProvider = StateProvider<GoogleSignInAccount?>((ref) => null);

/// What the sync card says, as a STATE rather than as a sentence.
///
/// It used to be a `String` holding Arabic — «لم تتم المزامنة», «جاري
/// المزامنة...» — set from this service and rendered raw, so the one line on
/// the More tab that reports on the reader's own account was in Arabic in all
/// seven languages. It is also the shape trap #29 warns about: a sentence
/// frozen when it is set does not follow a language the reader changes
/// afterwards. The card translates the state at build time now.
enum SyncStatus { idle, syncing, done, error, failed }

final syncStatusProvider = StateProvider<SyncStatus>((ref) => SyncStatus.idle);
final lastSyncTimeProvider = StateProvider<DateTime?>((ref) => null);

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(
    ref.read(googleSignInProvider),
    ref.read(sharedPreferencesProvider),
    ref,
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Overridden in `main()` with the real instance.
///
/// It used to be declared as a provider that THREW on every read. Anything
/// that touched it - and `SyncableSharedPreferences` touches it on every
/// single settings write, through `syncServiceProvider` - got an exception
/// instead of a value, during app start-up, before the first frame. An
/// uncaught error there means `runApp` never paints, and the OS-drawn splash
/// is never lifted: the app looks frozen on a blank screen, which is exactly
/// what the owner saw on first launch. A throwing default is a trap; this one
/// simply refuses to be read before it is overridden, and `main` overrides it.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw StateError(
    'sharedPreferencesProvider was read before main() overrode it',
  ),
);

class SyncService {
  final GoogleSignIn _googleSignIn;
  final SharedPreferences _prefs;
  final Ref _ref;
  final http.Client? _client;

  static String get _syncApiUrl => '${AppConfig.syncBackendUrl}/sync';

  Timer? _debounceTimer;
  late Database _localQueueDb;
  bool _isSyncing = false;
  Future<void>? _initialization;
  Future<void>? _queueProcessing;
  bool _queueRequested = false;
  Future<void>? _accountRestoration;
  String? _restoringAccountId;
  StreamSubscription<GoogleSignInAccount?>? _accountSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _disposed = false;
  bool _databaseOpened = false;
  final Map<String?, SyncStateJournal> _journals = {};
  late SyncStateJournal _journal = _journalFor(
    _prefs.getString(SyncStateJournal.ownerKey),
  );
  SyncStateJournal _journalFor(String? account) =>
      _journals.putIfAbsent(account, () => SyncStateJournal(_prefs, account));
  int _logoutGeneration = 0;
  bool _signingOut = false;
  final Map<String, int> _counterRevisions = {};
  final Map<String, int> _counterAcknowledgements = {};
  final Map<String, int> _counterWrites = {};
  Future<void> _accountPreparation = Future<void>.value();

  SyncService(this._googleSignIn, this._prefs, this._ref, {http.Client? client})
    : _client = client;

  /// Every call to the sync backend is bounded.
  ///
  /// `http` has no default timeout: a request to a Worker that is not
  /// deployed, or a network that accepts the connection and then says
  /// nothing, hangs for as long as the OS allows. Sync runs on the app's own
  /// start-up path, so an unbounded wait there is an app that never opens.
  static Future<http.Response> _withTimeout(Future<http.Response> call) =>
      call.timeout(const Duration(seconds: 20));

  Future<void> init() {
    if (_disposed) return Future<void>.value();
    return _initialization ??= _initialize();
  }

  Future<void> _initialize() async {
    final dbPath = p.join(await getDatabasesPath(), 'sync_queue.db');
    _localQueueDb = await openDatabase(
      dbPath,
      // Keep version one readable by the protected 3.87 rollback APK.
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            payload TEXT NOT NULL,
            account_id TEXT
          )
        ''');
      },
      onOpen: (db) async {
        final columns = await db.rawQuery('PRAGMA table_info(queue)');
        if (!columns.any((row) => row['name'] == 'account_id')) {
          await db.execute('ALTER TABLE queue ADD COLUMN account_id TEXT');
        }
        await db.execute(
          'CREATE TABLE IF NOT EXISTS sync_account_queue ('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, account_id TEXT NOT NULL, '
          'type TEXT NOT NULL, payload TEXT NOT NULL)',
        );
      },
    );
    _databaseOpened = true;
    if (_disposed) {
      await _localQueueDb.close();
      return;
    }

    _accountSubscription = _googleSignIn.onCurrentUserChanged.listen((account) {
      if (_disposed) return;
      _ref.read(authStateProvider.notifier).state = account;
      if (account != null) {
        unawaited(_restoreAccount(account));
      }
    });

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      if (_disposed) return;
      if (results.contains(ConnectivityResult.none) == false) {
        _processQueue();
      }
    });

    try {
      final account = await _googleSignIn.signInSilently();
      if (!_disposed && account != null) {
        _ref.read(authStateProvider.notifier).state = account;
        unawaited(_restoreAccount(account));
      }
    } catch (_) {}
  }

  Future<void> _restoreAccount(GoogleSignInAccount account) {
    if (_disposed) return Future<void>.value();
    final current = _accountRestoration;
    if (current != null) {
      if (_restoringAccountId == account.id) return current;
      return current.then((_) => _restoreAccount(account));
    }
    _restoringAccountId = account.id;
    return _accountRestoration = _pushBeforePull(account).whenComplete(() {
      _accountRestoration = null;
      _restoringAccountId = null;
    });
  }

  Future<void> _pushBeforePull(GoogleSignInAccount account) async {
    try {
      if (_disposed || _ref.read(authStateProvider)?.id != account.id) return;
      await _prepareAccount(account.id);
      if (!_sameAccount(account.id)) return;
      await _processQueue();
      if (_disposed || _ref.read(authStateProvider)?.id != account.id) return;
      // A rejected upload stays local; pulling now could restore an older state.
      final pending = await _localQueueDb.query(
        'queue',
        where: 'account_id = ?',
        whereArgs: [account.id],
        limit: 1,
      );
      if (pending.isNotEmpty || _disposed) return;
      if (_ref.read(authStateProvider)?.id != account.id) return;
      await _fullSync();
    } catch (_) {
      if (!_disposed) {
        _ref.read(syncStatusProvider.notifier).state = SyncStatus.failed;
      }
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _debounceTimer?.cancel();
    unawaited(_accountSubscription?.cancel());
    unawaited(_connectivitySubscription?.cancel());
    if (_databaseOpened) unawaited(_localQueueDb.close());
  }

  /// Signs in, and - the part that was missing - **publishes the result**.
  ///
  /// The first cut returned the account and never wrote it to
  /// `authStateProvider`, so the card that watches that provider stayed on
  /// its signed-out face however well the sign-in went. And every failure
  /// was swallowed into `return null`, so a misconfigured client looked
  /// exactly like a successful sign-in that did nothing. That is what the
  /// owner saw: «عمل كارت تسجيل الدخول بس بضغط عليه مش بيعمل حاجة».
  ///
  /// Cancelling the Google sheet is not an error - it returns null with
  /// nothing thrown. A real failure is rethrown so the caller can say so.
  Future<GoogleSignInAccount?> signIn() async {
    final account = await _googleSignIn.signIn();
    if (_disposed) return account;
    _ref.read(authStateProvider.notifier).state = account;
    if (account != null) unawaited(_restoreAccount(account));
    return account;
  }

  /// «زر خروج يمسح الحساب والبيانات» — the ACCOUNT's data: what travels
  /// with it ([syncedStateKeys], the synced counters) and anything still
  /// queued for it. It used to be `_prefs.clear()`, which wiped every
  /// setting on the phone as well — language, the finished onboarding, the
  /// download registries, the adhan choices — so signing out put the app
  /// back to a first install (audit 2026-09-24, finding D1).
  static const syncedCounterKeys = <String>{'tasbeeh_total', 'azkar_total'};

  Future<void> signOut() async {
    _signingOut = true;
    _logoutGeneration++;
    try {
      final accountId =
          _ref.read(authStateProvider)?.id ??
          _prefs.getString(SyncStateJournal.ownerKey);
      _debounceTimer?.cancel();
      await _googleSignIn.signOut();
      if (_disposed) return;
      _ref.read(authStateProvider.notifier).state = null;
      await _accountPreparation;
      await _journal.save();
      for (final key in {...syncedStateKeys, ...syncedCounterKeys}) {
        await _prefs.remove(key);
      }
      await _prefs.remove(_journal.storageKey);
      await _prefs.remove('${SyncStateJournal.prefix}device');
      await _prefs.remove('${SyncStateJournal.prefix}$accountId:counters');
      await _prefs.remove(SyncStateJournal.ownerKey);
      _journals.remove(accountId);
      _journals.remove(null);
      _journal = _journalFor(null);
      if (_databaseOpened) {
        await _localQueueDb.delete(
          'queue',
          where: 'account_id = ? OR account_id IS NULL',
          whereArgs: [accountId],
        );
        await _localQueueDb.delete(
          'sync_account_queue',
          where: 'account_id = ?',
          whereArgs: [accountId],
        );
      }
      _publishRestoredState();
    } finally {
      _signingOut = false;
    }
  }

  Future<void> notifySettingsChanged({String? key}) async {
    if (_disposed) return;
    try {
      for (final changed in key == null ? syncedStateKeys : {key}) {
        if (!syncedStateKeys.contains(changed)) continue;
        await _journal.record(changed);
      }
    } catch (_) {
      // The actual preference remains local; never claim a failed journal
      // write was synchronized or enqueue an unsupported modification time.
      if (!_disposed) {
        _ref.read(syncStatusProvider.notifier).state = SyncStatus.failed;
      }
      return;
    }
    if (_disposed || _ref.read(authStateProvider) == null) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), _queueStateSync);
  }

  /// A mutation waits for account activation before touching its preferences.
  /// If the account changes while waiting, retain the edit in its own journal.
  Future<bool> writeLocalState(
    String key,
    Object? value,
    Future<bool> Function() write,
  ) async {
    if (_disposed) return write();
    if (_signingOut) return false;
    final logoutGeneration = _logoutGeneration;
    final accountId = _ref.read(authStateProvider)?.id;
    if (!_disposed &&
        accountId != null &&
        _databaseOpened &&
        (_journal.account != accountId ||
            _prefs.getString(SyncStateJournal.ownerKey) != accountId)) {
      await _prepareAccount(accountId);
    }
    if (_signingOut || logoutGeneration != _logoutGeneration) return false;
    if (!_disposed && accountId != null && !_sameAccount(accountId)) {
      await _journalFor(accountId).recordValue(key, jsonEncode(value));
      return true;
    }
    final result = await write();
    if (_signingOut || logoutGeneration != _logoutGeneration) return result;
    if (result && accountId != null && !_sameAccount(accountId)) {
      await _journalFor(accountId).recordValue(key, jsonEncode(value));
    } else if (result) {
      await notifySettingsChanged(key: key);
    }
    return result;
  }

  Future<void> incrementCounter(String key, int amount) async {
    if (_disposed) return;
    if (_ref.read(authStateProvider) == null) return;
    if (!syncedCounterKeys.contains(key)) return;
    _counterRevisions[key] = (_counterRevisions[key] ?? 0) + 1;
    final accountId = _ref.read(authStateProvider)!.id;
    _counterWrites[key] = (_counterWrites[key] ?? 0) + 1;
    try {
      await init();
      if (!_sameAccount(accountId)) return;

      final eventId = const Uuid().v4();
      final payload = {
        'key': key,
        'event_id': eventId,
        'increment_value': amount,
      };

      await _localQueueDb.insert('queue', {
        'type': 'counter',
        'payload': jsonEncode(payload),
        'account_id': accountId,
      });
    } finally {
      _counterWrites[key] = (_counterWrites[key] ?? 1) - 1;
    }

    unawaited(_processQueue());
  }

  /// THE ONLY PREFERENCE KEYS THAT TRAVEL BETWEEN DEVICES.
  ///
  /// It used to be "everything that does not start with `local_`" - every
  /// setting in the app - and the pull below wrote each one straight back
  /// with no look at `updated_at`. So a stale snapshot silently reverted
  /// settings the owner had never touched, WHILE THE APP WAS OPEN, behind
  /// notifiers that had already read them: «وضع التركيز بيشتغل لوحده» · «وضع
  /// الـRGB بيشتغل لوحده» · «صوت الأذان بيشتغل لوحده» · «سلوك التطبيق مش
  /// مظبوط».
  ///
  /// His rule, asked and answered: «خلي بس الحاجات الاساسية تتزامن اللي لو
  /// ضاعت هبدا اعد من الاول زي الختمة والتسابيح والاذكار». So what travels is
  /// what he would have to earn again, and nothing else. A theme, a font
  /// size, a reciter, a full-screen toggle belong to the phone in his hand.
  ///
  /// The tasbih and adhkar totals are NOT here on purpose: they go down the
  /// `counter` path, which ADDS the two devices' progress instead of letting
  /// the last writer win. Putting them here as well would have the two paths
  /// fight each other.
  ///
  /// Adding a key here is a decision about someone's data. Make it
  /// deliberately.
  static const syncedStateKeys = <String>{
    'khatma_list_v1', // الختمة: the plans, the pages read, the streak
    'ayah_notes_v1', // his own notes on ayahs - text he wrote
    'quran_last_page', // «متابعة القراءة»
    'tasbeeh_custom_target', // the target he set himself
  };

  Future<void> _queueStateSync() async {
    if (_disposed) return;
    final accountId = _ref.read(authStateProvider)?.id;
    if (accountId == null) return;
    await init();
    if (!_sameAccount(accountId)) return;
    await _enqueueDirtyState(accountId);
    unawaited(_processQueue());
  }

  bool _sameAccount(String id) =>
      !_disposed && _ref.read(authStateProvider)?.id == id;

  void _publishRestoredState() {
    if (!_disposed) _ref.read(syncStateRevisionProvider.notifier).state++;
  }

  Future<void> _prepareAccount(String accountId) {
    return _accountPreparation = _accountPreparation.catchError((Object _) {}).then((
      _,
    ) async {
      if (!_sameAccount(accountId)) return;
      final previous = _prefs.getString(SyncStateJournal.ownerKey);
      // Version-one rows have no owner; bind them before switching preferences.
      await _localQueueDb.update('queue', {
        'account_id': previous ?? accountId,
      }, where: 'account_id IS NULL');
      // Old clients read every active row; keep foreign accounts separate.
      await _localQueueDb.transaction((txn) async {
        await txn.rawInsert(
          'INSERT INTO sync_account_queue (account_id, type, payload) '
          'SELECT account_id, type, payload FROM queue WHERE account_id <> ?',
          [accountId],
        );
        await txn.delete(
          'queue',
          where: 'account_id <> ?',
          whereArgs: [accountId],
        );
        final archived = await txn.query(
          'sync_account_queue',
          where: 'account_id = ?',
          whereArgs: [accountId],
        );
        for (final row in archived) {
          await txn.insert('queue', {
            'account_id': accountId,
            'type': row['type'],
            'payload': row['payload'],
          });
        }
        await txn.delete(
          'sync_account_queue',
          where: 'account_id = ?',
          whereArgs: [accountId],
        );
      });
      if (!_sameAccount(accountId)) return;
      _journal = await _journal.switchAccount(
        accountId,
        syncedStateKeys,
        syncedCounterKeys,
        nextJournal: _journalFor(accountId),
      );
      if (previous == null) _journals.remove(null);
      if (!_sameAccount(accountId)) return;
      final pending = await _localQueueDb.query(
        'queue',
        where: 'type = ? AND account_id = ?',
        whereArgs: ['state', accountId],
      );
      for (final row in pending) {
        for (final item
            in (jsonDecode(row['payload'] as String) as List)
                .cast<Map<String, dynamic>>()) {
          if (syncedStateKeys.contains(item['key'])) {
            _journal.adoptQueued(Map<String, dynamic>.from(item as Map));
          }
        }
      }
      for (final key in syncedStateKeys) {
        if (_prefs.containsKey(key) || _journal.entries.containsKey(key)) {
          await _journal.record(key);
        }
      }
      await _journal.save();
      await _enqueueDirtyState(accountId);
      if (previous != null && previous != accountId) _publishRestoredState();
    });
  }

  Future<void> _enqueueDirtyState(String accountId) async {
    if (!_sameAccount(accountId)) return;
    final rows = await _localQueueDb.query(
      'queue',
      where: 'type = ? AND account_id = ?',
      whereArgs: ['state', accountId],
    );
    final existing = <String>{
      for (final row in rows)
        for (final item in jsonDecode(row['payload'] as String) as List)
          jsonEncode(item),
    };
    final updates = _journal
        .dirty(syncedStateKeys)
        .where((item) => !existing.contains(jsonEncode(item)))
        .toList();
    if (updates.isNotEmpty && _sameAccount(accountId)) {
      await _localQueueDb.insert('queue', {
        'type': 'state',
        'payload': jsonEncode(updates),
        'account_id': accountId,
      });
    }
  }

  Future<void> _processQueue() {
    if (_disposed) return Future<void>.value();
    _queueRequested = true;
    return _queueProcessing ??= _drainRequestedQueue().whenComplete(() {
      _queueProcessing = null;
    });
  }

  Future<void> _drainRequestedQueue() async {
    do {
      _queueRequested = false;
      final accountId = _ref.read(authStateProvider)?.id;
      final delivered = await _deliverQueue();
      if (!delivered &&
          (_disposed || _ref.read(authStateProvider)?.id == accountId)) {
        return;
      }
    } while (_queueRequested && !_disposed);
  }

  Future<bool> _deliverQueue() async {
    if (_disposed || _isSyncing) return false;
    final account = _ref.read(authStateProvider);
    if (account == null) return true;

    final connectivity = await Connectivity().checkConnectivity();
    if (!_sameAccount(account.id)) return false;
    if (connectivity.contains(ConnectivityResult.none)) return true;
    if (_prefs.getString(SyncStateJournal.ownerKey) != account.id) {
      await _prepareAccount(account.id);
    }
    if (!_sameAccount(account.id)) return false;
    await _localQueueDb.update('queue', {
      'account_id': account.id,
    }, where: 'account_id IS NULL');

    _isSyncing = true;

    try {
      // A coalesced request may reach an already-drained queue. Keep its
      // completed state while authentication runs; only real work is syncing.
      final pending = await _localQueueDb.query(
        'queue',
        where: 'account_id = ?',
        whereArgs: [account.id],
        limit: 1,
      );
      if (!_sameAccount(account.id)) return false;
      if (pending.isNotEmpty) {
        _ref.read(syncStatusProvider.notifier).state = SyncStatus.syncing;
      }
      final auth = await account.authentication;
      if (!_sameAccount(account.id)) return false;
      final idToken = auth.idToken;
      if (idToken == null) throw Exception('No idToken');

      while (true) {
        if (!_sameAccount(account.id)) return false;
        // Bound the database read too; each row can contain multiple states.
        final queuedItems = await _localQueueDb.query(
          'queue',
          orderBy: 'id ASC',
          where: 'account_id = ?',
          whereArgs: [account.id],
          limit: SyncQueueBatch.maxCounters,
        );
        if (!_sameAccount(account.id)) return false;
        if (queuedItems.isEmpty) break;
        // Writes can arrive while authentication is pending.
        _ref.read(syncStatusProvider.notifier).state = SyncStatus.syncing;
        for (final batch in syncQueueBatches(queuedItems)) {
          if (!_sameAccount(account.id)) return false;
          final response = await _withTimeout(
            (_client?.post ?? http.post)(
              Uri.parse(_syncApiUrl),
              headers: {
                'Authorization': 'Bearer $idToken',
                'Content-Type': 'application/json; charset=utf-8',
              },
              body: batch.body,
            ),
          );
          if (!_sameAccount(account.id)) return false;
          if (response.statusCode != 200) {
            _ref.read(syncStatusProvider.notifier).state = SyncStatus.error;
            return false;
          }
          for (final item
              in ((jsonDecode(batch.body) as Map)['counters'] as List)
                  .cast<Map<String, dynamic>>()) {
            final key = item['key'] as String;
            _counterAcknowledgements[key] =
                (_counterAcknowledgements[key] ?? 0) + 1;
          }
          await _localQueueDb.transaction((txn) async {
            final deletes = txn.batch();
            for (final id in batch.completedIds) {
              deletes.delete('queue', where: 'id = ?', whereArgs: [id]);
            }
            await deletes.commit(noResult: true);
          });
          if (!_sameAccount(account.id)) return false;
          await _journal.acknowledge(
            (jsonDecode(batch.body) as Map)['updates'] as List,
          );
        }
      }
      _ref.read(lastSyncTimeProvider.notifier).state = DateTime.now();
      _ref.read(syncStatusProvider.notifier).state = SyncStatus.done;
      return true;
    } catch (e) {
      if (_disposed) return false;
      _ref.read(syncStatusProvider.notifier).state = SyncStatus.failed;
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _fullSync() async {
    if (_disposed) return;
    final account = _ref.read(authStateProvider);
    if (account == null) return;

    try {
      final auth = await account.authentication;
      if (!_sameAccount(account.id)) return;
      final idToken = auth.idToken;
      if (idToken == null) return;

      final startValues = {
        for (final key in syncedStateKeys) key: jsonEncode(_prefs.get(key)),
      };
      final counterRevisions = Map<String, int>.from(_counterRevisions);
      final counterAcknowledgements = Map<String, int>.from(
        _counterAcknowledgements,
      );
      final pendingCounterWrites = {
        for (final item in _counterWrites.entries)
          if (item.value > 0) item.key,
      };
      final journal = _journal;
      final response = await _withTimeout(
        (_client?.get ?? http.get)(
          Uri.parse(_syncApiUrl),
          headers: {'Authorization': 'Bearer $idToken'},
        ),
      );
      if (!_sameAccount(account.id)) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final rawPrefs = _prefs;
        var changed = false;

        final stateItems = (data['state'] as List).cast<Map<String, dynamic>>();
        for (final item in stateItems) {
          if (!_sameAccount(account.id)) return;
          final key = item['key'] as String;
          // THE PULL FILTERS TOO, and it matters more than the push: the
          // server still holds every setting an older build sent it, and
          // without this line it would keep restoring them for ever.
          if (!syncedStateKeys.contains(key)) continue;
          if (jsonEncode(rawPrefs.get(key)) != startValues[key] ||
              item['value'] is! String ||
              !journal.accepts(
                key,
                item['value'] as String,
                item['updated_at'],
              )) {
            continue;
          }
          try {
            final value = jsonDecode(item['value'] as String);
            if (!validSyncStateValue(key, value)) continue;
            final previousEntry = journal.entries[key];
            if (await writePreferenceValue(rawPrefs, key, value)) {
              if (!_sameAccount(account.id)) return;
              if (jsonEncode(rawPrefs.get(key)) != item['value'] ||
                  !identical(journal.entries[key], previousEntry)) {
                changed = true;
                continue;
              }
              await journal.received(
                key,
                item['value'] as String,
                item['updated_at'] as int,
              );
              changed = true;
            }
          } on FormatException {
            // Ignore only the malformed row, retaining other valid states.
          }
        }

        // Handling downloaded counters
        final queuedCounters = await _localQueueDb.query(
          'queue',
          where: 'type = ? AND account_id = ?',
          whereArgs: ['counter', account.id],
        );
        final Map<String, int> unsynced = {};
        for (final row in queuedCounters) {
          final payload =
              jsonDecode(row['payload'] as String) as Map<String, dynamic>;
          final k = payload['key'] as String;
          final inc = payload['increment_value'] as int;
          unsynced[k] = (unsynced[k] ?? 0) + inc;
        }

        final counterItems = (data['counters'] as List)
            .cast<Map<String, dynamic>>();
        for (final item in counterItems) {
          if (!_sameAccount(account.id)) return;
          final key = item['key'] as String;
          if (!syncedCounterKeys.contains(key) ||
              item['total'] is! int ||
              (_counterRevisions[key] ?? 0) != (counterRevisions[key] ?? 0) ||
              (_counterAcknowledgements[key] ?? 0) !=
                  (counterAcknowledgements[key] ?? 0) ||
              pendingCounterWrites.contains(key) ||
              (_counterWrites[key] ?? 0) > 0 ||
              unsynced.containsKey(key)) {
            continue;
          }
          final total = item['total'] as int;
          if (total.abs() > SyncStateJournal.maxTimestamp) continue;
          await rawPrefs.setInt(key, total);
          changed = true;
        }
        if (changed && _sameAccount(account.id)) _publishRestoredState();
      }
    } catch (e) {
      // Ignore
    }
  }
}
