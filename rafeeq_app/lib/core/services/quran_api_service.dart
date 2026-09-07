import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Single word from Quran.com word-by-word API.
class QuranWordWbw {
  final int id;
  final int position;
  final String textUthmani;
  final String location;
  final String? translationText;
  final String? transliterationText;
  final String? audioUrl;

  const QuranWordWbw({
    required this.id,
    required this.position,
    required this.textUthmani,
    required this.location,
    this.translationText,
    this.transliterationText,
    this.audioUrl,
  });

  factory QuranWordWbw.fromJson(Map<String, dynamic> json) {
    final translation = json['translation'] as Map<String, dynamic>?;
    final transliteration = json['transliteration'] as Map<String, dynamic>?;

    return QuranWordWbw(
      id: json['id'] as int? ?? 0,
      position: json['position'] as int? ?? 0,
      textUthmani: (json['text_uthmani'] as String?) ??
          (json['text'] as String?) ??
          '',
      location: json['location'] as String? ?? '',
      translationText: translation?['text'] as String?,
      transliterationText: transliteration?['text'] as String?,
      audioUrl: json['audio_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'position': position,
        'text_uthmani': textUthmani,
        'location': location,
        if (translationText != null) 'translation': {'text': translationText},
        if (transliterationText != null)
          'transliteration': {'text': transliterationText},
        if (audioUrl != null) 'audio_url': audioUrl,
      };
}

/// Service to query Quran.com API v4 with resilient caching.
class QuranApiService {
  static final QuranApiService instance = QuranApiService._();
  QuranApiService._();

  static const String _baseUrl = 'https://api.quran.com/api/v4';
  static const Map<String, String> _headers = {
    'User-Agent': 'RafiqAlDarb/1.0 (Islamic App; Mobile)',
    'Accept': 'application/json',
  };

  final Map<String, String> _memoryTransliterationCache = {};
  final Map<String, List<QuranWordWbw>> _memoryWbwCache = {};

  String _transKey(int surah, int ayah) => 'quran_transliteration_${surah}_$ayah';
  String _wbwKey(int surah, int ayah) => 'quran_wbw_${surah}_$ayah';

  /// Get English transliteration for an ayah.
  /// Checks memory cache -> SharedPreferences cache -> Quran.com API v4.
  Future<String?> getAyahTransliteration(int surah, int ayah) async {
    final cacheKey = '$surah:$ayah';
    if (_memoryTransliterationCache.containsKey(cacheKey)) {
      return _memoryTransliterationCache[cacheKey];
    }

    // Try persistent cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_transKey(surah, ayah));
      if (saved != null && saved.isNotEmpty) {
        _memoryTransliterationCache[cacheKey] = saved;
        return saved;
      }
    } catch (e) {
      debugPrint('QuranApiService: prefs read error: $e');
    }

    // Fetch from Quran.com API v4
    try {
      final uri = Uri.parse('$_baseUrl/verses/by_key/$surah:$ayah?translations=57');
      final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final verse = data['verse'] as Map<String, dynamic>?;
        final translations = verse?['translations'] as List<dynamic>?;
        if (translations != null && translations.isNotEmpty) {
          final first = translations.first as Map<String, dynamic>;
          final text = (first['text'] as String?)?.trim() ?? '';
          if (text.isNotEmpty) {
            _memoryTransliterationCache[cacheKey] = text;
            _persistTransliteration(surah, ayah, text);
            return text;
          }
        }
      }
    } catch (e) {
      debugPrint('QuranApiService: transliteration fetch error: $e');
    }

    // Fallback: fetch WBW words and concatenate transliterations
    try {
      final words = await getAyahWordsWbw(surah, ayah);
      if (words.isNotEmpty) {
        final combined = words
            .map((w) => w.transliterationText)
            .where((t) => t != null && t.trim().isNotEmpty)
            .join(' ');
        if (combined.isNotEmpty) {
          _memoryTransliterationCache[cacheKey] = combined;
          _persistTransliteration(surah, ayah, combined);
          return combined;
        }
      }
    } catch (e) {
      debugPrint('QuranApiService: wbw fallback error: $e');
    }

    return null;
  }

  /// Get word-by-word data for an ayah.
  Future<List<QuranWordWbw>> getAyahWordsWbw(int surah, int ayah) async {
    final cacheKey = '$surah:$ayah';
    if (_memoryWbwCache.containsKey(cacheKey)) {
      return _memoryWbwCache[cacheKey]!;
    }

    // Check persistent cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_wbwKey(surah, ayah));
      if (saved != null && saved.isNotEmpty) {
        final list = (jsonDecode(saved) as List<dynamic>)
            .map((e) => QuranWordWbw.fromJson(e as Map<String, dynamic>))
            .toList();
        _memoryWbwCache[cacheKey] = list;
        return list;
      }
    } catch (e) {
      debugPrint('QuranApiService: wbw prefs read error: $e');
    }

    // Fetch from API
    try {
      final uri = Uri.parse(
          '$_baseUrl/verses/by_key/$surah:$ayah?words=true&word_fields=text_uthmani,location,translation,transliteration&language=ar');
      final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final verse = data['verse'] as Map<String, dynamic>?;
        final wordsJson = verse?['words'] as List<dynamic>?;
        if (wordsJson != null) {
          final words = wordsJson
              .map((e) => QuranWordWbw.fromJson(e as Map<String, dynamic>))
              .where((w) => w.textUthmani.isNotEmpty && w.textUthmani != 'end')
              .toList();

          _memoryWbwCache[cacheKey] = words;
          _persistWbw(surah, ayah, words);
          return words;
        }
      }
    } catch (e) {
      debugPrint('QuranApiService: fetch wbw error: $e');
    }

    return const [];
  }

  /// Prefetch transliterations for an entire chapter at once
  Future<Map<int, String>> prefetchChapterTransliterations(int surah) async {
    final result = <int, String>{};
    try {
      final uri = Uri.parse('$_baseUrl/quran/translations/57?chapter_number=$surah');
      final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final translations = data['translations'] as List<dynamic>?;
        if (translations != null) {
          final prefs = await SharedPreferences.getInstance();
          for (int i = 0; i < translations.length; i++) {
            final ayahNum = i + 1;
            final item = translations[i] as Map<String, dynamic>;
            final text = (item['text'] as String?)?.trim() ?? '';
            if (text.isNotEmpty) {
              result[ayahNum] = text;
              _memoryTransliterationCache['$surah:$ayahNum'] = text;
              await prefs.setString(_transKey(surah, ayahNum), text);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('QuranApiService: chapter prefetch error: $e');
    }
    return result;
  }

  void _persistTransliteration(int surah, int ayah, String text) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_transKey(surah, ayah), text);
    } catch (e) {
      debugPrint('QuranApiService: persist transliteration error: $e');
    }
  }

  void _persistWbw(int surah, int ayah, List<QuranWordWbw> words) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(words.map((w) => w.toJson()).toList());
      await prefs.setString(_wbwKey(surah, ayah), raw);
    } catch (e) {
      debugPrint('QuranApiService: persist wbw error: $e');
    }
  }
}

final quranApiServiceProvider = Provider<QuranApiService>((ref) {
  return QuranApiService.instance;
});
