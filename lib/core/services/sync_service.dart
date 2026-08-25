import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SyncService {
  static final SyncService _instance = SyncService._();
  factory SyncService() => _instance;
  SyncService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Keys that shouldn't be synced
  static const Set<String> _excludedKeys = {
    'first_open',
    'app_version',
  };

  /// Uploads all relevant SharedPreferences to Firestore for the given [uid].
  Future<void> syncUp(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      final Map<String, dynamic> data = {};
      for (final key in keys) {
        if (_excludedKeys.contains(key)) continue;
        data[key] = prefs.get(key);
      }

      data['last_synced'] = FieldValue.serverTimestamp();

      await _firestore.collection('users').doc(uid).set(
        data,
        SetOptions(merge: true),
      );
      
      debugPrint('Sync up completed successfully for $uid');
    } catch (e) {
      debugPrint('Sync up failed: $e');
    }
  }

  /// Downloads preferences from Firestore and applies them locally for the given [uid].
  Future<void> syncDown(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return; // No data to sync down

      final data = doc.data()!;
      final prefs = await SharedPreferences.getInstance();

      for (final entry in data.entries) {
        if (entry.key == 'last_synced') continue;

        final val = entry.value;
        if (val is bool) {
          await prefs.setBool(entry.key, val);
        } else if (val is int) {
          await prefs.setInt(entry.key, val);
        } else if (val is double) {
          await prefs.setDouble(entry.key, val);
        } else if (val is String) {
          await prefs.setString(entry.key, val);
        } else if (val is List) {
          await prefs.setStringList(entry.key, val.map((e) => e.toString()).toList());
        }
      }
      
      debugPrint('Sync down completed successfully for $uid');
    } catch (e) {
      debugPrint('Sync down failed: $e');
    }
  }
}
