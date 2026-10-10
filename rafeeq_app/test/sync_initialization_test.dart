import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path/path.dart' as p;
import 'package:rafeeq_app/core/services/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class ControlledSignIn extends GoogleSignIn {
  final changes = StreamController<GoogleSignInAccount?>.broadcast();
  final silent = Completer<GoogleSignInAccount?>();
  int streamReads = 0;
  int silentCalls = 0;

  Future<void> close() => changes.close();

  @override
  Stream<GoogleSignInAccount?> get onCurrentUserChanged {
    streamReads++;
    return changes.stream;
  }

  @override
  Future<GoogleSignInAccount?> signInSilently({
    bool suppressErrors = true,
    bool reAuthenticate = false,
  }) {
    silentCalls++;
    return silent.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test(
    'concurrent and repeated sync init owns one listener pair until disposal',
    () async {
      final originalPath = await databaseFactory.getDatabasesPath();
      final directory = Directory.systemTemp.createTempSync('rafeeq-init-');
      await databaseFactory.setDatabasesPath(directory.path);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final auth = ControlledSignIn();
      var connectivityListens = 0;
      var connectivityCancels = 0;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const events = MethodChannel(
        'dev.fluttercommunity.plus/connectivity_status',
      );
      messenger.setMockMethodCallHandler(events, (call) async {
        if (call.method == 'listen') connectivityListens++;
        if (call.method == 'cancel') connectivityCancels++;
        return null;
      });
      final container = ProviderContainer(
        overrides: [
          googleSignInProvider.overrideWithValue(auth),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(() async {
        container.dispose();
      await auth.close();
        messenger.setMockMethodCallHandler(events, null);
        final database = await databaseFactory.openDatabase(
          p.join(directory.path, 'sync_queue.db'),
        );
        await database.close();
        await databaseFactory.setDatabasesPath(originalPath);
        directory.deleteSync(recursive: true);
      });
      final service = container.read(syncServiceProvider);
      final starts = [for (var i = 0; i < 6; i++) service.init()];
      await Future<void>.delayed(const Duration(milliseconds: 100));
      auth.silent.complete(null);
      await Future.wait(starts);
      await service.init();
      expect(auth.silentCalls, 1);
      expect(auth.streamReads, 1);
      expect(auth.changes.hasListener, isTrue);
      expect(connectivityListens, 1);
      container.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(auth.changes.hasListener, isFalse);
      expect(connectivityCancels, 1);
      // A disposed provider's service cannot restart listeners on a late frame.
      await service.init();
      expect(auth.silentCalls, 1);
      expect(auth.changes.hasListener, isFalse);
    },
  );
}
