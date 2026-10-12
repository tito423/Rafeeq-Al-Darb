import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sync_service.dart';

class SyncableSharedPreferences implements SharedPreferences {
  final SharedPreferences _delegate;
  final Ref _ref;

  SyncableSharedPreferences(this._delegate, this._ref);

  Future<bool> _write(
    String key,
    Object? value,
    Future<bool> Function() write,
  ) async {
    if (!SyncService.syncedStateKeys.contains(key)) return write();
    SyncService service;
    try {
      service = _ref.read(syncServiceProvider);
    } catch (_) {
      return write();
    }
    return service.writeLocalState(key, value, write);
  }

  Future<void> _notifySync({String? key}) async {
    try {
      await _ref.read(syncServiceProvider).notifySettingsChanged(key: key);
    } catch (_) {
      // Ignored if syncServiceProvider is not yet initialized
    }
  }

  @override
  Future<bool> setBool(String key, bool value) async {
    return _write(key, value, () => _delegate.setBool(key, value));
  }

  @override
  Future<bool> setDouble(String key, double value) async {
    return _write(key, value, () => _delegate.setDouble(key, value));
  }

  @override
  Future<bool> setInt(String key, int value) async {
    return _write(key, value, () => _delegate.setInt(key, value));
  }

  @override
  Future<bool> setString(String key, String value) async {
    return _write(key, value, () => _delegate.setString(key, value));
  }

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    return _write(key, value, () => _delegate.setStringList(key, value));
  }

  @override
  Future<bool> remove(String key) async {
    return _write(key, null, () => _delegate.remove(key));
  }

  @override
  Future<bool> clear() async {
    final result = await _delegate.clear();
    if (result) await _notifySync();
    return result;
  }

  @override
  // ignore: deprecated_member_use
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
