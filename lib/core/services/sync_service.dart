import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SyncService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Authentication ────────────────────────────────────────────────────────
  
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      if (userCredential.user != null) {
        // Run initial sync pull on fresh login
        await _pullUserData(userCredential.user!.uid);
      }
      return userCredential.user;
    } catch (e) {
      debugPrint("Error signing in with Google: $e");
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ── Sync (Push & Pull) ────────────────────────────────────────────────────
  
  Future<void> _pullUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        final prefs = await SharedPreferences.getInstance();
        
        // Restore last read
        if (data.containsKey('last_read_surah_id')) {
          await prefs.setInt('last_read_surah_id', data['last_read_surah_id']);
          await prefs.setInt('last_read_ayah', data['last_read_ayah'] ?? 1);
          await prefs.setInt('last_read_page', data['last_read_page'] ?? 1);
        }
        
        // Restore bookmarks
        if (data.containsKey('bookmarks')) {
          final bookmarksList = List<String>.from(data['bookmarks'] ?? []);
          await prefs.setStringList('bookmarks', bookmarksList);
        }
      }
    } catch (e) {
      debugPrint("Error pulling user data: $e");
    }
  }

  Future<void> pushUserData() async {
    final user = currentUser;
    if (user == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get current state
      final lastSurah = prefs.getInt('last_read_surah_id');
      final lastAyah = prefs.getInt('last_read_ayah');
      final lastPage = prefs.getInt('last_read_page');
      final bookmarks = prefs.getStringList('bookmarks') ?? [];
      
      final Map<String, dynamic> data = {
        'last_sync': FieldValue.serverTimestamp(),
        'email': user.email,
        'displayName': user.displayName,
        'bookmarks': bookmarks,
      };

      if (lastSurah != null) {
        data['last_read_surah_id'] = lastSurah;
        data['last_read_ayah'] = lastAyah ?? 1;
        data['last_read_page'] = lastPage ?? 1;
      }

      await _firestore.collection('users').doc(user.uid).set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error pushing user data: $e");
    }
  }
}

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService();
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(syncServiceProvider).authStateChanges;
});
