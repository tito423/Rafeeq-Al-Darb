import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

// ── Translation Service ───────────────────────────────────────────────────────────

class TranslationService {
  static final TranslationService _instance = TranslationService._();
  factory TranslationService() => _instance;
  TranslationService._();

  static const _baseUrl = 'https://api.alquran.cloud/v1';

  // ── Local storage paths ───────────────────────────────────────────────────

  Future<Directory> get _translationDir async {
    final dir = await getApplicationDocumentsDirectory();
    final d = Directory('${dir.path}/translations');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  String _translationFilename(String edition, int surahId) =>
      'trans_${edition}_surah_${surahId.toString().padLeft(3, '0')}.json';

  Future<String> _translationFilePath(String edition, int surahId) async {
    final dir = await _translationDir;
    return '${dir.path}/${_translationFilename(edition, surahId)}';
  }

  // ── Download check ────────────────────────────────────────────────────────

  Future<bool> isTranslationDownloaded(String edition) async {
    final dir = await _translationDir;
    for (final surahId in [1, 2, 114]) {
      final path = '${dir.path}/${_translationFilename(edition, surahId)}';
      if (!File(path).existsSync()) return false;
    }
    return true;
  }

  Future<int> downloadedSurahCount(String edition) async {
    final dir = await _translationDir;
    int count = 0;
    for (int s = 1; s <= 114; s++) {
      final path = '${dir.path}/${_translationFilename(edition, s)}';
      if (File(path).existsSync()) count++;
    }
    return count;
  }

  // ── Download ──────────────────────────────────────────────────────────────

  Future<bool> downloadTranslation(
    String edition, {
    void Function(int completed, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    int completed = 0;
    const total = 114;

    for (int surahId = 1; surahId <= total; surahId++) {
      if (isCancelled?.call() == true) return false;

      final filePath = await _translationFilePath(edition, surahId);
      if (File(filePath).existsSync()) {
        completed++;
        onProgress?.call(completed, total);
        continue;
      }

      try {
        final url = Uri.parse('$_baseUrl/surah/$surahId/$edition');
        final response = await http.get(
          url,
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          await File(filePath).writeAsString(response.body, flush: true);
        } else {
          debugPrint('TranslationService: HTTP ${response.statusCode} for $edition surah $surahId');
        }
      } catch (e) {
        debugPrint('TranslationService: error downloading $edition/$surahId — $e');
      }

      completed++;
      onProgress?.call(completed, total);
      await Future.delayed(const Duration(milliseconds: 100)); // rate limiting
    }
    return true;
  }

  Future<void> deleteTranslation(String edition) async {
    final dir = await _translationDir;
    for (int s = 1; s <= 114; s++) {
      final f = File('${dir.path}/${_translationFilename(edition, s)}');
      if (f.existsSync()) await f.delete();
    }
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  Future<String?> getAyahTranslation({
    required String edition,
    required int surahId,
    required int ayahNumberInSurah,
  }) async {
    final filePath = await _translationFilePath(edition, surahId);
    final file = File(filePath);
    if (!file.existsSync()) return null;

    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      if (decoded['code'] == 200) {
        final ayahs = decoded['data']['ayahs'] as List<dynamic>;
        if (ayahNumberInSurah > 0 && ayahNumberInSurah <= ayahs.length) {
           final ayah = ayahs[ayahNumberInSurah - 1];
           return ayah['text'] as String?;
        }
      }
    } catch (e) {
      debugPrint('TranslationService read error: $e');
    }
    return null;
  }
}

// ── Notifier ────────────────────────────────────────────────────────────────

class TranslationDownloadState {
  final Map<String, bool> isDownloading;
  final Map<String, double> progress;
  final Map<String, bool> isCompleted;
  final Map<String, String> errors;

  const TranslationDownloadState({
    this.isDownloading = const {},
    this.progress = const {},
    this.isCompleted = const {},
    this.errors = const {},
  });

  TranslationDownloadState copyWith({
    Map<String, bool>? isDownloading,
    Map<String, double>? progress,
    Map<String, bool>? isCompleted,
    Map<String, String>? errors,
  }) {
    return TranslationDownloadState(
      isDownloading: isDownloading ?? this.isDownloading,
      progress: progress ?? this.progress,
      isCompleted: isCompleted ?? this.isCompleted,
      errors: errors ?? this.errors,
    );
  }
}

class TranslationDownloadNotifier extends StateNotifier<TranslationDownloadState> {
  final _service = TranslationService();
  final Map<String, bool> _cancellationFlags = {};

  TranslationDownloadNotifier() : super(const TranslationDownloadState()) {
    _checkExisting();
  }

  Future<void> _checkExisting() async {
    final Map<String, bool> completed = {};
    for (final e in kTranslations.values) {
      if (await _service.isTranslationDownloaded(e.edition)) {
        completed[e.edition] = true;
      }
    }
    if (mounted) {
      state = state.copyWith(isCompleted: completed);
    }
  }

  void startDownload(String edition) async {
    _cancellationFlags[edition] = false;
    state = state.copyWith(
      isDownloading: {...state.isDownloading, edition: true},
      errors: {...state.errors}..remove(edition),
      progress: {...state.progress, edition: 0.0},
    );

    final success = await _service.downloadTranslation(
      edition,
      isCancelled: () => _cancellationFlags[edition] ?? false,
      onProgress: (completed, total) {
        if (!mounted) return;
        state = state.copyWith(
          progress: {...state.progress, edition: completed / total},
        );
      },
    );

    if (!mounted) return;

    if (success) {
      state = state.copyWith(
        isDownloading: {...state.isDownloading, edition: false},
        isCompleted: {...state.isCompleted, edition: true},
      );
    } else {
      state = state.copyWith(
        isDownloading: {...state.isDownloading, edition: false},
        errors: {...state.errors, edition: 'فشل التنزيل أو تم الإلغاء'},
      );
    }
  }

  void cancelDownload(String edition) {
    _cancellationFlags[edition] = true;
    state = state.copyWith(
      isDownloading: {...state.isDownloading, edition: false},
    );
  }

  void deleteTranslation(String edition) async {
    await _service.deleteTranslation(edition);
    state = state.copyWith(
      isCompleted: {...state.isCompleted}..remove(edition),
      progress: {...state.progress}..remove(edition),
    );
  }
}

final translationDownloadProvider = StateNotifierProvider<TranslationDownloadNotifier, TranslationDownloadState>(
  (ref) => TranslationDownloadNotifier(),
);

// ── Supported Translations ────────────────────────────────────────────────────

class TranslationConfig {
  final String languageName;
  final String edition;
  const TranslationConfig(this.languageName, this.edition);
}

const kTranslations = {
  'fr': TranslationConfig('Français (French)', 'fr.hamidullah'),
  'id': TranslationConfig('Bahasa Indonesia', 'id.indonesian'),
  'ms': TranslationConfig('Bahasa Melayu', 'ms.basmeih'),
  'tr': TranslationConfig('Türkçe (Turkish)', 'tr.diyanet'),
  'ur': TranslationConfig('اردو (Urdu)', 'ur.jalandhry'),
  'hi': TranslationConfig('हिन्दी (Hindi)', 'hi.hindi'),
  'bn': TranslationConfig('বাংলা (Bengali)', 'bn.bengali'),
  'fa': TranslationConfig('فارسی (Persian)', 'fa.ayati'),
  'es': TranslationConfig('Español (Spanish)', 'es.cortes'),
  'ru': TranslationConfig('Русский (Russian)', 'ru.kuliev'),
  'zh': TranslationConfig('中文 (Chinese)', 'zh.jian'),
  'de': TranslationConfig('Deutsch (German)', 'de.aburida'),
  'it': TranslationConfig('Italiano (Italian)', 'it.piccardo'),
  'pt': TranslationConfig('Português (Portuguese)', 'pt.elhayek'),
  'ha': TranslationConfig('Hausa', 'ha.gumi'),
  'en': TranslationConfig('English', 'en.asad'),
};
