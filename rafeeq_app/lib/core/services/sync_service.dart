import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../config/app_config.dart';

final googleSignInProvider = Provider((ref) => GoogleSignIn(
      serverClientId: AppConfig.googleServerClientId,
      scopes: ['email', 'profile'],
    ));

final authStateProvider = StateProvider<GoogleSignInAccount?>((ref) => null);
final syncStatusProvider = StateProvider<String>((ref) => 'لم تتم المزامنة');
final lastSyncTimeProvider = StateProvider<DateTime?>((ref) => null);

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(
    ref.read(googleSignInProvider),
    ref.read(sharedPreferencesProvider),
    ref,
  );
  return service;
});

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());

class SyncService {
  final GoogleSignIn _googleSignIn;
  final SharedPreferences _prefs;
  final Ref _ref;
  
  static String get _syncApiUrl => '${AppConfig.syncBackendUrl}/sync';
  
  Timer? _debounceTimer;
  late Database _localQueueDb;
  bool _isSyncing = false;

  SyncService(this._googleSignIn, this._prefs, this._ref);

  Future<void> init() async {
    final dbPath = p.join(await getDatabasesPath(), 'sync_queue.db');
    _localQueueDb = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            payload TEXT NOT NULL
          )
        ''');
      },
    );

    _googleSignIn.onCurrentUserChanged.listen((account) {
      _ref.read(authStateProvider.notifier).state = account;
      if (account != null) {
        _fullSync();
      }
    });

    Connectivity().onConnectivityChanged.listen((results) {
      if (results.contains(ConnectivityResult.none) == false) {
        _processQueue();
      }
    });

    try {
      await _googleSignIn.signInSilently();
    } catch (_) {}
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
    _ref.read(authStateProvider.notifier).state = account;
    return account;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _ref.read(authStateProvider.notifier).state = null;
    await _prefs.clear(); // Optionally clear data on sign out?
    // Wait, prompt says: "زر خروج يمسح الحساب والبيانات". Yes.
  }

  void notifySettingsChanged() {
    if (_ref.read(authStateProvider) == null) return;
    
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      _queueStateSync();
    });
  }

  Future<void> incrementCounter(String key, int amount) async {
    if (_ref.read(authStateProvider) == null) return;
    
    final eventId = const Uuid().v4();
    final payload = {
      'key': key,
      'event_id': eventId,
      'increment_value': amount,
    };
    
    await _localQueueDb.insert('queue', {
      'type': 'counter',
      'payload': jsonEncode(payload),
    });
    
    _processQueue();
  }

  Future<void> _queueStateSync() async {
    final keys = _prefs.getKeys();
    final List<Map<String, dynamic>> updates = [];
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final key in keys) {
      // Exclude local specific keys if any
      if (key.startsWith('local_')) continue;
      
      final value = _prefs.get(key);
      if (value != null) {
        updates.add({
          'key': key,
          'value': jsonEncode(value),
          'updated_at': now,
        });
      }
    }

    await _localQueueDb.insert('queue', {
      'type': 'state',
      'payload': jsonEncode(updates),
    });

    _processQueue();
  }

  Future<void> _processQueue() async {
    if (_isSyncing) return;
    final account = _ref.read(authStateProvider);
    if (account == null) return;

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) return;

    _isSyncing = true;
    _ref.read(syncStatusProvider.notifier).state = 'جاري المزامنة...';

    try {
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) throw Exception('No idToken');

      final queuedItems = await _localQueueDb.query('queue', orderBy: 'id ASC');
      if (queuedItems.isEmpty) {
        _isSyncing = false;
        _ref.read(syncStatusProvider.notifier).state = 'تمت المزامنة';
        return;
      }

      final List<Map<String, dynamic>> stateUpdates = [];
      final List<Map<String, dynamic>> counterUpdates = [];
      final List<int> processedIds = [];

      for (final item in queuedItems) {
        final payload = jsonDecode(item['payload'] as String);
        if (item['type'] == 'state') {
          stateUpdates.addAll(List<Map<String, dynamic>>.from(payload));
        } else if (item['type'] == 'counter') {
          counterUpdates.add(payload);
        }
        processedIds.add(item['id'] as int);
      }

      final body = {
        'updates': stateUpdates,
        'counters': counterUpdates,
      };

      final response = await http.post(
        Uri.parse(_syncApiUrl),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        for (final id in processedIds) {
          await _localQueueDb.delete('queue', where: 'id = ?', whereArgs: [id]);
        }
        _ref.read(lastSyncTimeProvider.notifier).state = DateTime.now();
        _ref.read(syncStatusProvider.notifier).state = 'تمت المزامنة';
      } else {
        _ref.read(syncStatusProvider.notifier).state = 'خطأ في المزامنة';
      }
    } catch (e) {
      _ref.read(syncStatusProvider.notifier).state = 'فشلت المزامنة';
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _fullSync() async {
    final account = _ref.read(authStateProvider);
    if (account == null) return;

    try {
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) return;

      final response = await http.get(
        Uri.parse(_syncApiUrl),
        headers: {
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rawPrefs = await SharedPreferences.getInstance();
        
        final stateItems = data['state'] as List;
        for (final item in stateItems) {
          final key = item['key'];
          final value = jsonDecode(item['value']);
          
          if (value is String) {
            await rawPrefs.setString(key, value);
          } else if (value is int) {
            await rawPrefs.setInt(key, value);
          } else if (value is double) {
            await rawPrefs.setDouble(key, value);
          } else if (value is bool) {
            await rawPrefs.setBool(key, value);
          } else if (value is List) {
            await rawPrefs.setStringList(key, List<String>.from(value));
          }
        }
        
        // Handling downloaded counters
        final queuedCounters = await _localQueueDb.query('queue', where: 'type = ?', whereArgs: ['counter']);
        final Map<String, int> unsynced = {};
        for (final row in queuedCounters) {
           final payload = jsonDecode(row['payload'] as String);
           final k = payload['key'] as String;
           final inc = payload['increment_value'] as int;
           unsynced[k] = (unsynced[k] ?? 0) + inc;
        }

        final counterItems = data['counters'] as List;
        for (final item in counterItems) {
           final key = item['key'];
           final total = item['total'] as int;
           final finalTotal = total + (unsynced[key] ?? 0);
           await rawPrefs.setInt(key, finalTotal);
        }
      }
    } catch (e) {
      // Ignore
    }
  }
}
