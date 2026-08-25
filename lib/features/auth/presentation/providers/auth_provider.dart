import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/sync_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService();
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).userChanges;
});

class AuthController extends StateNotifier<AsyncValue<User?>> {
  final AuthService _authService;
  final SyncService _syncService;

  AuthController(this._authService, this._syncService) : super(const AsyncData(null)) {
    _authService.userChanges.listen((user) {
      state = AsyncData(user);
    });
  }

  Future<void> signIn() async {
    state = const AsyncLoading();
    final user = await _authService.signInWithGoogle();
    if (user != null) {
      // Upon successful sign-in, automatically sync down to restore their preferences
      await _syncService.syncDown(user.uid);
    }
    state = AsyncData(user);
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    await _authService.signOut();
    state = const AsyncData(null);
  }

  Future<void> manualSyncUp() async {
    final user = _authService.currentUser;
    if (user != null) {
      await _syncService.syncUp(user.uid);
    }
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AsyncValue<User?>>((ref) {
  return AuthController(
    ref.watch(authServiceProvider),
    ref.watch(syncServiceProvider),
  );
});
