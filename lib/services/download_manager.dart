import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../core/models/mushaf_style.dart';

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

  const DownloadManagerState({
    this.tasks = const {},
    this.activeCount = 0,
    this.isBulkDownloading = false,
    this.bulkTotal = 0,
    this.bulkCompleted = 0,
  });

  DownloadManagerState copyWith({
    Map<String, DownloadTask>? tasks,
    int? activeCount,
    bool? isBulkDownloading,
    int? bulkTotal,
    int? bulkCompleted,
  }) => DownloadManagerState(
    tasks: tasks ?? this.tasks,
    activeCount: activeCount ?? this.activeCount,
    isBulkDownloading: isBulkDownloading ?? this.isBulkDownloading,
    bulkTotal: bulkTotal ?? this.bulkTotal,
    bulkCompleted: bulkCompleted ?? this.bulkCompleted,
  );

  double get bulkProgress => bulkTotal > 0 ? bulkCompleted / bulkTotal : 0.0;

  List<DownloadTask> get activeTasks =>
      tasks.values.where((t) => t.isDownloading).toList();
}

// ── Manager ───────────────────────────────────────────────────────────────────

class DownloadManager extends StateNotifier<DownloadManagerState> {
  final Dio _dio = Dio();
  final Map<String, CancelToken> _cancelTokens = {};

  // PNG base URL pattern for Quran-PNG repository (Legacy fallback)
  static const String _mushaafBaseUrl =
      'https://raw.githubusercontent.com/Govarjabbar/Quran-PNG/main/images/';

  DownloadManager() : super(const DownloadManagerState());

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

  Future<String> getMushaafPagePath(int pageNumber, String styleName) async {
    final dir = await _mushaafDir(styleName);
    final filename = 'page_${pageNumber.toString().padLeft(3, '0')}.jpg';
    return '${dir.path}/$filename';
  }

  Future<bool> isPageDownloaded(int pageNumber, String styleName) async {
    final path = await getLocalPagePath(pageNumber, styleName);
    return path != null;
  }

  Future<String?> getLocalPagePath(int pageNumber, String styleName) async {
    final dir = await _mushaafDir(styleName);
    final p3 = pageNumber.toString().padLeft(3, '0');
    final jpgPath = '${dir.path}/page_$p3.jpg';
    if (File(jpgPath).existsSync() && File(jpgPath).lengthSync() > 1000) return jpgPath;
    final pngPath = '${dir.path}/page_$p3.png';
    if (File(pngPath).existsSync() && File(pngPath).lengthSync() > 1000) return pngPath;
    return null;
  }

  // ── Download a single page ────────────────────────────────────────────────

  Future<void> downloadMushaafPage(int pageNumber, {required MushafStyleInfo styleInfo}) async {
    final styleName = styleInfo.style.name;
    final id = 'page_${styleName}_$pageNumber';
    if (state.tasks[id]?.isDownloading == true) return;
    
    if (await isPageDownloaded(pageNumber, styleName)) {
      _updateTask(
        id,
        DownloadTask(
          id: id,
          url: styleInfo.pageUrl(pageNumber),
          filename: 'page_${pageNumber.toString().padLeft(3, '0')}.png',
          category: DownloadCategory.mushaafPage,
          isCompleted: true,
          progress: 1.0,
        ),
      );
      return;
    }

    final savePath = await getMushaafPagePath(pageNumber, styleName);
    await _startDownload(
      id: id,
      url: styleInfo.pageUrl(pageNumber),
      savePath: savePath,
      category: DownloadCategory.mushaafPage,
    );
  }

  /// Download all 604 Mushaaf pages sequentially (bulk)
  Future<void> downloadAllMushaafPages({
    required MushafStyleInfo styleInfo,
    void Function(int completed, int total)? onProgress,
  }) async {
    const total = 604;
    int completed = 0;
    final styleName = styleInfo.style.name;

    state = state.copyWith(
      isBulkDownloading: true,
      bulkTotal: total,
      bulkCompleted: 0,
    );

    for (int page = 1; page <= total; page++) {
      if (!state.isBulkDownloading) break; // cancelled

      if (!await isPageDownloaded(page, styleName)) {
        await downloadMushaafPage(page, styleInfo: styleInfo);
        // Wait for completion
        await _waitForTask('page_${styleName}_$page');
      }
      completed++;
      state = state.copyWith(bulkCompleted: completed);
      onProgress?.call(completed, total);
    }

    state = state.copyWith(isBulkDownloading: false);
  }

  void cancelBulkDownload() {
    state = state.copyWith(isBulkDownloading: false);
    for (final token in _cancelTokens.values) {
      token.cancel('User cancelled');
    }
  }

  /// Download surah audio (mp3quran.net — reliable, no CDN auth required)
  Future<void> downloadSurahAudio({
    required int surahNumber,
    required String reciterId,
    required String mp3quranBaseUrl,
  }) async {
    final s = surahNumber.toString().padLeft(3, '0');
    final id = 'audio_${reciterId}_$surahNumber';
    final url = '$mp3quranBaseUrl/$s.mp3';
    final audioDir = await _audioDir;

    final savePath = '${audioDir.path}/$id.mp3';

    await _startDownload(
      id: id,
      url: url,
      savePath: savePath,
      category: DownloadCategory.audioSurah,
    );
  }

  Future<void> downloadBook({
    required String bookId,
    required String downloadUrl,
  }) async {
    final id = 'book_$bookId';
    if (state.tasks[id]?.isDownloading == true) return;

    final savePath = await getBookPath(bookId);
    
    // Check if already downloaded
    if (File(savePath).existsSync()) {
      _updateTask(
        id,
        DownloadTask(
          id: id,
          url: downloadUrl,
          filename: '$bookId.json',
          category: DownloadCategory.book,
          isCompleted: true,
          progress: 1.0,
        ),
      );
      return;
    }

    await _startDownload(
      id: id,
      url: downloadUrl,
      savePath: savePath,
      category: DownloadCategory.book,
    );
  }

  // ── Core download logic ───────────────────────────────────────────────────

  Future<void> startDownload({
    required String id,
    required String url,
    required String filename,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final savePath = '${dir.path}/$filename';
    await _startDownload(
      id: id,
      url: url,
      savePath: savePath,
      category: DownloadCategory.audioSurah,
    );
  }

  Future<void> _startDownload({
    required String id,
    required String url,
    required String savePath,
    required DownloadCategory category,
  }) async {
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
        // Delete partial file
        final f = File(savePath);
        if (f.existsSync()) f.deleteSync();
      } else {
        _updateTask(
          id,
          state.tasks[id]!.copyWith(isDownloading: false, error: e.message),
        );
      }
    } catch (e) {
      _updateTask(
        id,
        state.tasks[id]!.copyWith(isDownloading: false, error: e.toString()),
      );
    } finally {
      _cancelTokens.remove(id);
    }
  }

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

  Future<void> _waitForTask(String id) async {
    while (state.tasks[id]?.isDownloading == true) {
      await Future.delayed(const Duration(milliseconds: 200));
    }
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
    for (final token in _cancelTokens.values) {
      token.cancel();
    }
    _dio.close();
    super.dispose();
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final downloadManagerProvider =
    StateNotifierProvider<DownloadManager, DownloadManagerState>(
      (ref) => DownloadManager(),
    );

/// Convenience: watch a specific page download task
final pageDownloadTaskProvider = Provider.family<DownloadTask?, String>((
  ref,
  taskId,
) {
  final tasks = ref.watch(downloadManagerProvider).tasks;
  return tasks[taskId];
});
