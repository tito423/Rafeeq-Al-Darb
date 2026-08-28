import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import '../models/tafseer.dart';
import '../../features/quran/data/datasources/quran_sciences_db_helper.dart';

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
    // For sciences tafseers (saadi, muyassar), check if sciences database exists
    if (tafseerID == 'saadi' || tafseerID == 'muyassar') {
      try {
        final sciencesDb = QuranSciencesDbHelper();
        return await sciencesDb.isDatabaseAvailable();
      } catch (e) {
        return false;
      }
    }

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
    // For sciences tafseers, if database exists, assume all surahs available
    if (tafseerID == 'saadi' || tafseerID == 'muyassar') {
      try {
        final sciencesDb = QuranSciencesDbHelper();
        final available = await sciencesDb.isDatabaseAvailable();
        return available ? 114 : 0;
      } catch (e) {
        return 0;
      }
    }

    final dir = await _tafseerDir;
    int count = 0;
    for (int s = 1; s <= 114; s++) {
      final path = '${dir.path}/${_tafseerFilename(tafseerID, s)}';
      if (File(path).existsSync()) count++;
    }
    return count;
  }

  // ── Download ──────────────────────────────────────────────────────────────

  /// Download all 114 surahs for a tafseer sequentially from quran.com API.
  /// Calls [onProgress] with (completed, total) as extraction happens.
  /// Returns true on full success.
  Future<bool> downloadTafseer(
    String tafseerID, {
    void Function(int completed, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    // Sciences tafseers (saadi, muyassar) are already available via local database
    if (tafseerID == 'saadi' || tafseerID == 'muyassar') {
      onProgress?.call(114, 114);
      return true;
    }

    const total = 114;
    int completed = 0;
    
    try {
      final extractDir = await _tafseerDir;
      final dio = Dio();
      
      for (int s = 1; s <= 114; s++) {
        if (isCancelled?.call() == true) {
          return false;
        }

        // Find the quran.com numeric ID
        final book = kTafseers.firstWhere((b) => b.id == tafseerID, orElse: () => kTafseers.first);
        final quranComId = book.quranComId;
        
        final url = 'https://api.quran.com/api/v4/quran/tafsirs/$quranComId?chapter_number=$s';
        final response = await dio.get(url);
        
        if (response.statusCode == 200) {
          final data = response.data;
          final filename = _tafseerFilename(tafseerID, s);
          final file = File('${extractDir.path}/$filename');
          await file.writeAsString(jsonEncode(data));
          
          completed++;
          onProgress?.call(completed, total);
        } else {
          // If a single surah fails, we could retry or just abort. Let's abort to be safe.
          return false;
        }
      }
      return true;
    } catch (e) {
      debugPrint('TafseerService: error downloading $tafseerID — $e');
      return false;
    }
  }

/// Delete all files for a tafseer
  Future<void> deleteTafseer(String tafseerID) async {
    // Sciences tafseers are stored in the common sciences database; skip deletion
    if (tafseerID == 'saadi' || tafseerID == 'muyassar') {
      return;
    }

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
    // First, check if this is a sciences tafseer (saadi, muyassar) from local sciences database
    if (tafseerID == 'saadi' || tafseerID == 'muyassar') {
      try {
        final sciencesDb = QuranSciencesDbHelper();
        final data = await sciencesDb.getAyahSciences(surahId, ayahNumber);
        if (data != null) {
          final text = tafseerID == 'saadi' ? data.tafseerSaadi : data.tafseerMoyassar;
          if (text.isNotEmpty) return text;
        }
      } catch (e) {
        debugPrint('TafseerService: error reading sciences DB — $e');
      }
    }

    // Otherwise, fallback to downloaded tafseer files (quran.com API)
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
