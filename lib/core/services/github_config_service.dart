import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_config.dart';

// ----------------------------------------------------------------------------
// URL of the rafeeq_config.json file hosted on GitHub
// ----------------------------------------------------------------------------
const _githubConfigUrl = 'https://raw.githubusercontent.com/tito423/rafeeq-api/master/rafeeq_config.json';
const _cacheKey = 'cached_app_config';

final githubConfigProvider = StateNotifierProvider<GithubConfigNotifier, AsyncValue<AppConfig>>((ref) {
  return GithubConfigNotifier();
});

class GithubConfigNotifier extends StateNotifier<AsyncValue<AppConfig>> {
  GithubConfigNotifier() : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    // 1. Load cached config first for fast startup
    final cachedData = await _loadCachedConfig();
    if (cachedData != null) {
      state = AsyncValue.data(cachedData);
    }

    // 2. Fetch fresh config from GitHub
    await refreshConfig(showLoading: cachedData == null);
  }

  Future<void> refreshConfig({bool showLoading = false}) async {
    if (showLoading) {
      state = const AsyncValue.loading();
    }
    
    try {
      final response = await http.get(Uri.parse(_githubConfigUrl)).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        // Parse and decode UTF-8 to handle Arabic text correctly
        final jsonString = utf8.decode(response.bodyBytes);
        final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
        
        final config = AppConfig.fromJson(jsonMap);
        
        // Cache the new config
        await _cacheConfig(jsonString);
        
        state = AsyncValue.data(config);
      } else if (!state.hasValue) {
        state = AsyncValue.error('Failed to load config from GitHub: ${response.statusCode}', StackTrace.current);
      }
    } catch (e, st) {
      // If network fails, keep the cached value if it exists, otherwise show error
      if (!state.hasValue) {
        state = AsyncValue.error('Network Error: $e', st);
      }
    }
  }

  Future<AppConfig?> _loadCachedConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedString = prefs.getString(_cacheKey);
      if (cachedString != null) {
        final Map<String, dynamic> jsonMap = jsonDecode(cachedString);
        return AppConfig.fromJson(jsonMap);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _cacheConfig(String jsonString) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonString);
    } catch (_) {}
  }
}
