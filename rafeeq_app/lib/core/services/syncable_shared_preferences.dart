import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sync_service.dart';

class SyncableSharedPreferences implements SharedPreferences {
  final SharedPreferences _delegate;
  final Ref _ref;

  SyncableSharedPreferences(this._delegate, this._ref);

  void _notifySync() {
    try {
      _ref.read(syncServiceProvider).notifySettingsChanged();
    } catch (_) {
      // Ignored if syncServiceProvider is not yet initialized
    }
  }

  @override
  Future<bool> setBool(String key, bool value) async {
    final result = await _delegate.setBool(key, value);
    if (result) _notifySync();
    return result;
  }

  @override
  Future<bool> setDouble(String key, double value) async {
    final result = await _delegate.setDouble(key, value);
    if (result) _notifySync();
    return result;
  }

  @override
  Future<bool> setInt(String key, int value) async {
    final result = await _delegate.setInt(key, value);
    if (result) _notifySync();
    return result;
  }

  @override
  Future<bool> setString(String key, String value) async {
    final result = await _delegate.setString(key, value);
    if (result) _notifySync();
    return result;
  }

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    final result = await _delegate.setStringList(key, value);
    if (result) _notifySync();
    return result;
  }

  @override
  Future<bool> remove(String key) async {
    final result = await _delegate.remove(key);
    if (result) _notifySync();
    return result;
  }

  @override
  Future<bool> clear() async {
    final result = await _delegate.clear();
    if (result) _notifySync();
    return result;
  }

  @override
  Future<bool> commit() => _delegate.commit();

  @override
  bool containsKey(String key) => _delegate.containsKey(key);

  @override
  Object? get(String key) => _delegate.get(key);

  @override
  bool? getBool(String key) => _delegate.getBool(key);

  @override
  double? getDouble(String key) => _delegate.getDouble(key);

  @override
  int? getInt(String key) => _delegate.getInt(key);

  @override
  Set<String> getKeys() => _delegate.getKeys();

  @override
  String? getString(String key) => _delegate.getString(key);

  @override
  List<String>? getStringList(String key) => _delegate.getStringList(key);

  @override
  Future<void> reload() => _delegate.reload();
}
