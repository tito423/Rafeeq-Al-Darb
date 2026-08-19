import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/tafseer.dart';

// ── Tafseer Service ───────────────────────────────────────────────────────────

class TafseerService {
  static final TafseerService _instance = TafseerService._();
  factory TafseerService() => _instance;
  TafseerService._();

  // quran.com v4 API endpoint for tafsirs
  static const _baseUrl = 'https://api.quran.com/api/v4';

  // ── Local storage paths ───────────────────────────────────────────────────

  Future<Directory> get _tafseerDir async {
    final dir = await getApplicationDocumentsDirectory();
    final d = Directory('${dir.path}/tafseers');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  String _tafseerFilename(String tafseerID, int surahId) =>
      'tafseer_${tafseerID}_surah_${surahId.toString().padLeft(3, '0')}.json';

  Future<String> _tafseerFilePath(String tafseerID, int surahId) async {
    final dir = await _tafseerDir;
    return '${dir.path}/${_tafseerFilename(tafseerID, surahId)}';
  }

  // ── Download check ────────────────────────────────────────────────────────

  /// Returns true if all 114 surahs of this tafseer are downloaded
  Future<bool> isTafseerDownloaded(String tafseerID) async {
    final dir = await _tafseerDir;
    // Check a sample — surahs 1, 2, 36, 114
    for (final surahId in [1, 2, 36, 114]) {
      final path = '${dir.path}/${_tafseerFilename(tafseerID, surahId)}';
      if (!File(path).existsSync()) return false;
    }
    return true;
  }

  /// Returns the number of surahs downloaded for a given tafseer (0-114)
  Future<int> downloadedSurahCount(String tafseerID) async {
    final dir = await _tafseerDir;
    int count = 0;
    for (int s = 1; s <= 114; s++) {
      final path = '${dir.path}/${_tafseerFilename(tafseerID, s)}';
      if (File(path).existsSync()) count++;
    }
    return count;
  }

  // ── Download ──────────────────────────────────────────────────────────────

  /// Download all 114 surahs for a tafseer from quran.com API.
  /// Calls [onProgress] with (completed, total) as each surah is downloaded.
  /// Returns true on full success.
  Future<bool> downloadTafseer(
    String tafseerID, {
    void Function(int completed, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final book =
        kTafseers.firstWhere((t) => t.id == tafseerID, orElse: () => kTafseers.first);

    int completed = 0;
    const total = 114;

    for (int surahId = 1; surahId <= total; surahId++) {
      if (isCancelled?.call() == true) return false;

      // Skip if already downloaded
      final filePath = await _tafseerFilePath(tafseerID, surahId);
      if (File(filePath).existsSync()) {
        completed++;
        onProgress?.call(completed, total);
        continue;
      }

      try {
        final url = Uri.parse(
          '$_baseUrl/tafsirs/${book.quranComId}/by_chapter/$surahId'
          '?fields=text&page_size=300',
        );
        final response = await http.get(
          url,
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          await File(filePath).writeAsString(response.body, flush: true);
        } else {
          debugPrint(
              'TafseerService: HTTP ${response.statusCode} for $tafseerID surah $surahId');
          // Continue — don't abort entire download for one surah
        }
      } catch (e) {
        debugPrint('TafseerService: error downloading $tafseerID/$surahId — $e');
      }

      completed++;
      onProgress?.call(completed, total);

      // Polite rate limiting
      await Future.delayed(const Duration(milliseconds: 100));
    }
    return true;
  }

  /// Delete all files for a tafseer
  Future<void> deleteTafseer(String tafseerID) async {
    final dir = await _tafseerDir;
    for (int s = 1; s <= 114; s++) {
      final f = File('${dir.path}/${_tafseerFilename(tafseerID, s)}');
      if (f.existsSync()) await f.delete();
    }
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Get tafseer text for a specific ayah.
  /// Returns null if not downloaded.
  Future<String?> getAyahTafseer({
    required String tafseerID,
    required int surahId,
    required int ayahNumber,
  }) async {
    final filePath = await _tafseerFilePath(tafseerID, surahId);
    final file = File(filePath);
    if (!file.existsSync()) return null;

    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final tafsirs = decoded['tafsirs'] as List<dynamic>? ?? [];

      // Each entry has ayah_key like "1:1", "2:3" etc.
      // Find the one matching our ayah number
      for (final entry in tafsirs) {
        final map = entry as Map<String, dynamic>;
        final key = map['ayah_key'] as String? ?? '';
        final parts = key.split(':');
        if (parts.length == 2) {
          final ayahNum = int.tryParse(parts[1]);
          if (ayahNum == ayahNumber) {
            // Strip HTML tags from text
            final raw = map['text'] as String? ?? '';
            return _stripHtml(raw);
          }
        }
      }
    } catch (e) {
      debugPrint('TafseerService: parse error for $tafseerID/$surahId/$ayahNumber — $e');
    }
    return null;
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .trim();
  }
}

// ── Download state ────────────────────────────────────────────────────────────

class TafseerDownloadState {
  final Map<String, double> progress;   // tafseerID → 0.0–1.0
  final Map<String, bool> isDownloading;
  final Map<String, bool> isCompleted;
  final Map<String, String?> errors;

  const TafseerDownloadState({
    this.progress = const {},
    this.isDownloading = const {},
    this.isCompleted = const {},
    this.errors = const {},
  });

  TafseerDownloadState copyWith({
    Map<String, double>? progress,
    Map<String, bool>? isDownloading,
    Map<String, bool>? isCompleted,
    Map<String, String?>? errors,
  }) =>
      TafseerDownloadState(
        progress: progress ?? this.progress,
        isDownloading: isDownloading ?? this.isDownloading,
        isCompleted: isCompleted ?? this.isCompleted,
        errors: errors ?? this.errors,
      );
}

// ── Provider / Notifier ───────────────────────────────────────────────────────

class TafseerDownloadNotifier extends StateNotifier<TafseerDownloadState> {
  final TafseerService _service = TafseerService();
  final Map<String, bool> _cancelFlags = {};

  TafseerDownloadNotifier() : super(const TafseerDownloadState()) {
    _checkExisting();
  }

  Future<void> _checkExisting() async {
    final completedMap = <String, bool>{};
    for (final t in kTafseers) {
      completedMap[t.id] = await _service.isTafseerDownloaded(t.id);
    }
    state = state.copyWith(isCompleted: completedMap);
  }

  Future<void> startDownload(String tafseerID) async {
    if (state.isDownloading[tafseerID] == true) return;
    _cancelFlags[tafseerID] = false;

    // Mark as downloading
    state = state.copyWith(
      isDownloading: {...state.isDownloading, tafseerID: true},
      progress: {...state.progress, tafseerID: 0.0},
      errors: {...state.errors, tafseerID: null},
    );

    final success = await _service.downloadTafseer(
      tafseerID,
      onProgress: (completed, total) {
        state = state.copyWith(
          progress: {
            ...state.progress,
            tafseerID: completed / total,
          },
        );
      },
      isCancelled: () => _cancelFlags[tafseerID] == true,
    );

    state = state.copyWith(
      isDownloading: {...state.isDownloading, tafseerID: false},
      isCompleted: {...state.isCompleted, tafseerID: success},
      errors: {
        ...state.errors,
        tafseerID: success ? null : 'فشل التحميل',
      },
    );
  }

  void cancelDownload(String tafseerID) {
    _cancelFlags[tafseerID] = true;
    state = state.copyWith(
      isDownloading: {...state.isDownloading, tafseerID: false},
    );
  }

  Future<void> deleteTafseer(String tafseerID) async {
    await _service.deleteTafseer(tafseerID);
    state = state.copyWith(
      isCompleted: {...state.isCompleted, tafseerID: false},
      progress: {...state.progress, tafseerID: 0.0},
    );
  }
}

final tafseerDownloadProvider =
    StateNotifierProvider<TafseerDownloadNotifier, TafseerDownloadState>(
  (_) => TafseerDownloadNotifier(),
);

final tafseerServiceProvider = Provider<TafseerService>((_) => TafseerService());

/// Provider to get tafseer text for a specific ayah
final ayahTafseerProvider = FutureProvider.family<String?, ({String tafseerID, int surahId, int ayahNumber})>(
  (ref, args) => TafseerService().getAyahTafseer(
    tafseerID: args.tafseerID,
    surahId: args.surahId,
    ayahNumber: args.ayahNumber,
  ),
);

/// The currently selected tafseer ID (persisted)
final selectedTafseerProvider = StateProvider<String>((ref) => 'muyassar');
