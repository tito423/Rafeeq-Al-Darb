import 'package:flutter/foundation.dart';

import '../../../core/services/download_notifications.dart';
import '../../../core/utils/digits.dart';
import '../../library/data/library_api_service.dart';
import 'shamela_book_builder.dart';
import 'shamela_library.dart';
import 'package:easy_localization/easy_localization.dart';

/// The owner's Shamela imports are in the GitHub build only
/// («الجزء ده بالذات في تطبيقنا احنا بس مش البلاي ستور»). A build without
/// `--dart-define=RAFEEQ_SHAMELA=true` has no Shamela screen at all;
/// `build_github_release.bat` passes it, as it passes the support link.
const bool kShamelaEnabled = bool.fromEnvironment('RAFEEQ_SHAMELA');

/// One import in progress.
class ShamelaImportJob {
  ShamelaImportJob(this.shamelaId, this.title);
  final int shamelaId;
  final String title;
  int pages = 0;
  String? error;
}

/// Runs imports one after another, reports progress app-wide (the book
/// card, the Downloads panel, a notification), and installs each finished
/// book into the library through the same path as a hosted book.
class ShamelaImportService {
  ShamelaImportService._();
  static final ShamelaImportService instance = ShamelaImportService._();

  /// Every import asked for and not finished, keyed by Shamela id.
  final ValueNotifier<Map<int, ShamelaImportJob>> jobs = ValueNotifier({});
  final Map<int, ShamelaBookBuilder> _builders = {};
  Future<void> _queue = Future<void>.value();

  bool isRunning(int id) => jobs.value.containsKey(id);

  void _touch() => jobs.value = Map.of(jobs.value);

  /// Queues [card]'s book. Returns when it is installed (or failed).
  Future<void> start(int shamelaId, ShamelaCard card) {
    if (isRunning(shamelaId)) return _queue;
    final job = ShamelaImportJob(shamelaId, card.title);
    jobs.value = {...jobs.value, shamelaId: job};
    return _queue = _queue.then((_) => _run(job, card));
  }

  void cancel(int shamelaId) {
    _builders[shamelaId]?.cancel();
    jobs.value = Map.of(jobs.value)..remove(shamelaId);
    DownloadNotifications.instance.clear('shamela_$shamelaId');
  }

  Future<void> _run(ShamelaImportJob job, ShamelaCard card) async {
    if (!isRunning(job.shamelaId)) return; // cancelled while queued
    final builder = ShamelaBookBuilder(job.shamelaId);
    _builders[job.shamelaId] = builder;
    final nid = 'shamela_${job.shamelaId}';
    await DownloadNotifications.instance.ensureInitialized();
    try {
      final bookId = ShamelaLibrary.idFor(job.shamelaId);
      final bytes = await builder.build(
        card,
        bookId: bookId,
        onPage: (n) {
          job.pages = n;
          _touch();
          DownloadNotifications.instance.showProgress(
            id: nid,
            title: job.title,
            done: 0,
            total: 0, // Shamela gives no page total up front
            detail: localizeDigits(
              'shamela.importing'.tr(args: ['$n']),
              uiLanguageCode,
            ),
            payload: 'dl:files',
          );
        },
      );
      // Recorded first, so when the install announces itself the library
      // tabs already know the book (they list the registry on that event).
      await ShamelaLibrary.instance.add(
        shamelaId: job.shamelaId,
        titleAr: card.title,
        authorAr: card.author,
        pageCount: job.pages,
        sizeBytes: bytes.length,
      );
      try {
        await LibraryApiService.instance.installBookBytes(bookId, bytes);
      } catch (_) {
        await ShamelaLibrary.instance.remove(bookId);
        rethrow;
      }
      await DownloadNotifications.instance.showComplete(
        id: nid,
        title: job.title,
        payload: 'dl:files',
      );
      jobs.value = Map.of(jobs.value)..remove(job.shamelaId);
    } catch (e) {
      debugPrint('shamela import ${job.shamelaId} failed: $e');
      DownloadNotifications.instance.clear(nid);
      if (isRunning(job.shamelaId)) {
        job.error = '$e';
        _touch();
      }
    } finally {
      _builders.remove(job.shamelaId);
    }
  }

  /// Takes a finished error off the list.
  void dismiss(int shamelaId) =>
      jobs.value = Map.of(jobs.value)..remove(shamelaId);
}
