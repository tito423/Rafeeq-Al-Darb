import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/models/mushaf_style.dart';
import 'r2_storage_service.dart';

// ── Download categories ───────────────────────────────────────────────────────

enum DownloadCategory { mushaafPage, audioSurah, audioAdhan, book }

// ── Task model ────────────────────────────────────────────────────────────────

class DownloadTask {
  final String id;
  final String url;
  final String filename;
  final DownloadCategory category;
  final double progress;
  final bool isDownloading;
  final bool isCompleted;
  final bool isCancelled;
  final String? error;

  const DownloadTask({
    required this.id,
    required this.url,
    required this.filename,
    required this.category,
    this.progress = 0.0,
    this.isDownloading = false,
    this.isCompleted = false,
    this.isCancelled = false,
    this.error,
  });

  DownloadTask copyWith({
    double? progress,
    bool? isDownloading,
    bool? isCompleted,
    bool? isCancelled,
    String? error,
  }) => DownloadTask(
    id: id,
    url: url,
    filename: filename,
    category: category,
    progress: progress ?? this.progress,
    isDownloading: isDownloading ?? this.isDownloading,
    isCompleted: isCompleted ?? this.isCompleted,
    isCancelled: isCancelled ?? this.isCancelled,
    error: error,
  );

  bool get hasError => error != null && !isCompleted;
  bool get isPending =>
      !isDownloading && !isCompleted && !hasError && !isCancelled;
}

// ── State ─────────────────────────────────────────────────────────────────────

class DownloadManagerState {
  final Map<String, DownloadTask> tasks;
  final int activeCount;
  final bool isBulkDownloading;
  final int bulkTotal;
  final int bulkCompleted;
  final Set<String> localRegistry; // The Offline-First SharedPreferences registry

  const DownloadManagerState({
    this.tasks = const {},
    this.activeCount = 0,
    this.isBulkDownloading = false,
    this.bulkTotal = 0,
    this.bulkCompleted = 0,
    this.localRegistry = const {},
  });

  DownloadManagerState copyWith({
    Map<String, DownloadTask>? tasks,
    int? activeCount,
    bool? isBulkDownloading,
    int? bulkTotal,
    int? bulkCompleted,
    Set<String>? localRegistry,
  }) => DownloadManagerState(
    tasks: tasks ?? this.tasks,
    activeCount: activeCount ?? this.activeCount,
    isBulkDownloading: isBulkDownloading ?? this.isBulkDownloading,
    bulkTotal: bulkTotal ?? this.bulkTotal,
    bulkCompleted: bulkCompleted ?? this.bulkCompleted,
    localRegistry: localRegistry ?? this.localRegistry,
  );

  double get bulkProgress => bulkTotal > 0 ? bulkCompleted / bulkTotal : 0.0;
  List<DownloadTask> get activeTasks => tasks.values.where((t) => t.isDownloading).toList();
  bool isAssetDownloaded(String assetId) => localRegistry.contains(assetId);
}

// ── Manager ───────────────────────────────────────────────────────────────────

class DownloadManager extends StateNotifier<DownloadManagerState> {
  final Dio _dio = Dio();
  final Map<String, CancelToken> _cancelTokens = {};

  static const String _registryKey = 'offline_assets_registry';

  DownloadManager() : super(const DownloadManagerState()) {
    _initRegistry();
  }

  // ── Offline-First Registry (Zero Server Calls) ──────────────────────────────
  
  Future<void> _initRegistry() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> cachedAssets = prefs.getStringList(_registryKey) ?? [];
    state = state.copyWith(localRegistry: cachedAssets.toSet());
  }

  Future<void> _registerAsset(String assetId) async {
    final prefs = await SharedPreferences.getInstance();
    final updatedRegistry = Set<String>.from(state.localRegistry)..add(assetId);
    await prefs.setStringList(_registryKey, updatedRegistry.toList());
    state = state.copyWith(localRegistry: updatedRegistry);
  }

  bool isDownloadedLocally(String assetId) {
    return state.localRegistry.contains(assetId);
  }

  // ── File paths ────────────────────────────────────────────────────────────

  Future<Directory> _mushaafDir(String styleName) async {
    final dir = await getApplicationDocumentsDirectory();
    final d = Directory('${dir.path}/mushaaf_pages/$styleName');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  Future<Directory> get _audioDir async {
    final dir = await getApplicationDocumentsDirectory();
    final d = Directory('${dir.path}/audio');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  Future<Directory> get _bookDir async {
    final dir = await getApplicationDocumentsDirectory();
    final d = Directory('${dir.path}/books');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  Future<String> getBookPath(String bookId) async {
    final dir = await _bookDir;
    return '${dir.path}/$bookId.json';
  }

  Future<String> getBookPdfPath(String bookId) async {
    final dir = await _bookDir;
    return '${dir.path}/$bookId.pdf';
  }

  Future<bool> isBookPdfDownloaded(String bookId) async {
    return isDownloadedLocally('book_$bookId');
  }

  Future<String> getMushaafPagePath(int pageNumber, String styleName) async {
    final dir = await _mushaafDir(styleName);
    final filename = 'page_${pageNumber.toString().padLeft(3, '0')}.jpg';
    return '${dir.path}/$filename';
  }

  Future<bool> isPageDownloaded(int pageNumber, String styleName) async {
    return isDownloadedLocally('page_${styleName}_$pageNumber');
  }

  Future<String?> getLocalPagePath(int pageNumber, String styleName) async {
    final dir = await _mushaafDir(styleName);
    final p3 = pageNumber.toString().padLeft(3, '0');
    final jpgPath = '${dir.path}/page_$p3.jpg';
    if (File(jpgPath).existsSync()) return jpgPath;
    final pngPath = '${dir.path}/page_$p3.png';
    if (File(pngPath).existsSync()) return pngPath;
    return null;
  }

  // ── Core download & auto-extract logic ────────────────────────────────────

  Future<void> _startDownload({
    required String id,
    required String url,
    required String savePath,
    required DownloadCategory category,
    bool autoExtractZip = true,
  }) async {
    if (isDownloadedLocally(id)) return; // Strictly intercept if in registry

    final filename = savePath.split(RegExp(r'[/\\]')).last;
    final cancelToken = CancelToken();
    _cancelTokens[id] = cancelToken;

    _updateTask(
      id,
      DownloadTask(
        id: id,
        url: url,
        filename: filename,
        category: category,
        isDownloading: true,
        progress: 0.0,
      ),
    );

    try {
      await _dio.download(
        url,
        savePath,
        cancelToken: cancelToken,
        options: Options(
          receiveTimeout: const Duration(minutes: 5),
          headers: {'User-Agent': 'RafeeqAlDarb/2.0'},
        ),
        onReceiveProgress: (received, total) {
          if (total > 0) {
            _updateProgress(id, received / total);
          }
        },
      );

      // ZIP Auto-Extraction Logic
      if (autoExtractZip && savePath.toLowerCase().endsWith('.zip')) {
        _updateTask(id, state.tasks[id]!.copyWith(progress: 0.99)); // Extraction phase
        
        // Extract to parent directory
        final File zipFile = File(savePath);
        final extractDir = zipFile.parent;
        
        final bytes = zipFile.readAsBytesSync();
        final archive = ZipDecoder().decodeBytes(bytes);
        
        for (final file in archive) {
          if (file.isFile) {
            final outputFilename = file.name.split('/').last; 
            final data = file.content as List<int>;
            File('${extractDir.path}/$outputFilename')
              ..createSync(recursive: true)
              ..writeAsBytesSync(data);
          }
        }
        
        // Delete zip to save storage
        zipFile.deleteSync();
      }

      await _registerAsset(id); // Persist to local registry

      _updateTask(
        id,
        state.tasks[id]!.copyWith(
          isDownloading: false,
          isCompleted: true,
          progress: 1.0,
        ),
      );
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        _updateTask(
          id,
          state.tasks[id]!.copyWith(isDownloading: false, isCancelled: true),
        );
        final f = File(savePath);
        if (f.existsSync()) f.deleteSync();
      } else {
        _updateTask(id, state.tasks[id]!.copyWith(isDownloading: false, error: e.message));
      }
    } catch (e) {
      _updateTask(id, state.tasks[id]!.copyWith(isDownloading: false, error: e.toString()));
    } finally {
      _cancelTokens.remove(id);
    }
  }

  // ── Download a Book ───────────────────────────────────────────────────────

  Future<void> downloadBook({
    required String bookId,
    required String downloadUrl,
  }) async {
    final id = 'book_$bookId';
    if (state.tasks[id]?.isDownloading == true) return;

    // Check offline cache
    if (isDownloadedLocally(id)) return;

    final isZip = downloadUrl.toLowerCase().endsWith('.zip');
    final savePath = isZip ? '${(await _bookDir).path}/$bookId.zip' : await getBookPath(bookId);

    await _startDownload(
      id: id,
      url: downloadUrl,
      savePath: savePath,
      category: DownloadCategory.book,
      autoExtractZip: true,
    );
  }

  Future<void> downloadBookPdf(String bookId, String url, String title) async {
    final id = 'book_$bookId';
    if (state.tasks[id]?.isDownloading == true) return;
    
    if (isDownloadedLocally(id)) return;

    final isZip = url.toLowerCase().endsWith('.zip');
    final savePath = isZip ? '${(await _bookDir).path}/$bookId.zip' : await getBookPdfPath(bookId);

    await _startDownload(
      id: id,
      url: url,
      savePath: savePath,
      category: DownloadCategory.book,
      autoExtractZip: true,
    );
  }

  // ── Download Mushaf Page ──────────────────────────────────────────────────

  Future<void> downloadMushaafPage(int pageNumber, {required MushafStyleInfo styleInfo}) async {
    final styleName = styleInfo.style.name;
    final id = 'page_${styleName}_$pageNumber';
    if (state.tasks[id]?.isDownloading == true) return;
    
    if (isDownloadedLocally(id)) return;

    final savePath = await getMushaafPagePath(pageNumber, styleName);
    await _startDownload(
      id: id,
      url: styleInfo.pageUrl(pageNumber),
      savePath: savePath,
      category: DownloadCategory.mushaafPage,
    );
  }

  Future<void> downloadAllMushaafPages({
    required MushafStyleInfo styleInfo,
    void Function(int completed, int total)? onProgress,
    int concurrency = 5,
  }) async {
    const total = 604;
    final styleName = styleInfo.style.name;
    final id = 'mushaf_${styleName}_zip';

    state = state.copyWith(
      isBulkDownloading: true,
      bulkTotal: total,
      bulkCompleted: 0,
    );

    try {
      if (!isDownloadedLocally(id)) {
        final zipUrl = 'https://pub-b9273af6154c4a618f813447e8a9fc09.r2.dev/mushaf_${styleName}.zip';
        final dir = await getApplicationDocumentsDirectory();
        final zipPath = '${dir.path}/$id.zip';

        await _startDownload(
          id: id,
          url: zipUrl,
          savePath: zipPath,
          category: DownloadCategory.mushaafPage,
          autoExtractZip: true, 
        );

        while (state.tasks[id]?.isDownloading == true) {
          final prog = state.tasks[id]?.progress ?? 0.0;
          final simulatedPages = (prog * (total * 0.8)).toInt();
          state = state.copyWith(bulkCompleted: simulatedPages);
          onProgress?.call(simulatedPages, total);
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }

      state = state.copyWith(bulkCompleted: total, isBulkDownloading: false);
      onProgress?.call(total, total);
      
    } catch (e) {
      state = state.copyWith(isBulkDownloading: false);
    }
  }

  // ── Adhan Downloads ─────────────────────────────────────────────────────────

  Future<void> downloadAdhan(String adhanId, String url) async {
    final id = 'adhan_$adhanId';
    if (state.tasks[id]?.isDownloading == true) return;

    if (isDownloadedLocally(id)) return;

    final dir = await _getAdhansDirectory();
    final file = File('${dir.path}/$adhanId.mp3');

    await _startDownload(
      id: id,
      url: url,
      savePath: file.path,
      category: DownloadCategory.audioAdhan,
    );
  }

  Future<bool> isAdhanDownloaded(String adhanId) async {
    return isDownloadedLocally('adhan_$adhanId');
  }

  Future<String?> getAdhanPath(String adhanId) async {
    if (isDownloadedLocally('adhan_$adhanId')) {
      final dir = await _getAdhansDirectory();
      return '${dir.path}/$adhanId.mp3';
    }
    return null;
  }

  Future<Directory> _getAdhansDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/adhans');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // ── Missing Legacy Methods ────────────────────────────────────────────────
  
  Future<String> getMushafCoordsPath(String styleName) async {
    final dir = await getApplicationDocumentsDirectory();
    final d = Directory('${dir.path}/mushaf_coords');
    if (!d.existsSync()) d.createSync(recursive: true);
    return '${d.path}/$styleName.json';
  }

  Future<String?> downloadMushafCoords(String styleName) async {
    final id = 'mushaf_coords_$styleName';
    final path = await getMushafCoordsPath(styleName);
    
    if (isDownloadedLocally(id)) {
      return path;
    }
    
    try {
      final url = 'https://pub-b9273af6154c4a618f813447e8a9fc09.r2.dev/mushaf_coords/$styleName.json';
      await _startDownload(
        id: id,
        url: url,
        savePath: path,
        category: DownloadCategory.mushaafPage,
      );
      
      // Wait for completion
      while (state.tasks[id]?.isDownloading == true) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
      return path;
    } catch (e) {
      return null;
    }
  }

  void cancelBulkDownload() {
    state = state.copyWith(isBulkDownloading: false);
    for (final token in _cancelTokens.values) {
      token.cancel('User cancelled');
    }
    _cancelTokens.clear();
  }

  Future<void> downloadSurahAudio({
    required int surahNumber,
    required String reciterId,
    required String mp3quranBaseUrl,
  }) async {
    final s = surahNumber.toString().padLeft(3, '0');
    final id = 'audio_${reciterId}_$surahNumber';
    final url = '$mp3quranBaseUrl/$s.mp3';
    
    if (isDownloadedLocally(id)) return;
    if (state.tasks[id]?.isDownloading == true) return;

    final audioDir = await _audioDir;
    final savePath = '${audioDir.path}/$id.mp3';

    await _startDownload(
      id: id,
      url: url,
      savePath: savePath,
      category: DownloadCategory.audioSurah,
    );
  }

  Future<void> downloadFullReciterArchive({
    required String reciterId,
    required String mp3quranBaseUrl,
    void Function(int completed, int total)? onProgress,
  }) async {
    const total = 114;
    int completed = 0;

    state = state.copyWith(
      isBulkDownloading: true,
      bulkTotal: total,
      bulkCompleted: 0,
    );

    for (int surah = 1; surah <= total; surah++) {
      if (!state.isBulkDownloading) break;

      final id = 'audio_${reciterId}_$surah';
      await downloadSurahAudio(
        surahNumber: surah,
        reciterId: reciterId,
        mp3quranBaseUrl: mp3quranBaseUrl,
      );
      
      while (state.tasks[id]?.isDownloading == true) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
      
      completed++;
      state = state.copyWith(bulkCompleted: completed);
      onProgress?.call(completed, total);
    }

    state = state.copyWith(isBulkDownloading: false);
  }

  // ── Helper functions ────────────────────────────────────────────────────────
  
  void _updateTask(String id, DownloadTask task) {
    final newTasks = Map<String, DownloadTask>.from(state.tasks);
    newTasks[id] = task;
    state = state.copyWith(
      tasks: newTasks,
      activeCount: newTasks.values.where((t) => t.isDownloading).length,
    );
  }

  void _updateProgress(String id, double progress) {
    if (!state.tasks.containsKey(id)) return;
    _updateTask(id, state.tasks[id]!.copyWith(progress: progress));
  }

  void cancelTask(String id) {
    _cancelTokens[id]?.cancel('User cancelled');
    _cancelTokens.remove(id);
  }

  void removeTask(String id) {
    final newTasks = Map<String, DownloadTask>.from(state.tasks);
    newTasks.remove(id);
    state = state.copyWith(tasks: newTasks);
  }

  @override
  void dispose() {
    for (final token in _cancelTokens.values) token.cancel();
    _dio.close();
    super.dispose();
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final downloadManagerProvider =
    StateNotifierProvider<DownloadManager, DownloadManagerState>(
      (ref) => DownloadManager(),
    );

final pageDownloadTaskProvider = Provider.family<DownloadTask?, String>((
  ref,
  taskId,
) {
  final tasks = ref.watch(downloadManagerProvider).tasks;
  return tasks[taskId];
});
