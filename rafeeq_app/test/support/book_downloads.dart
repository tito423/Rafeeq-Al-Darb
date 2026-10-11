import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/library/data/book_catalog.dart';
import 'package:rafeeq_app/features/library/data/library_api_service.dart';
import 'package:rafeeq_app/features/library/presentation/widgets/book_card.dart';
import 'package:sqflite/sqflite.dart';

const bookDownloadLocales = ['ar', 'en', 'fr', 'es', 'pt', 'ru', 'ur'];
const downloadBookId = 'al_usul_wal_dawabit';
const bookDownloadCases = [
  'duplicate',
  'queuedCancel',
  'activeCancel',
  'retry',
  'failure',
  'success',
];

class _Request {
  final RequestOptions options;
  final response = Completer<ResponseBody>();
  _Request(this.options);
}

class _Transport implements HttpClientAdapter {
  final requests = <_Request>[];
  bool closed = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    if (closed) return Future.error(StateError('Transport closed'));
    final request = _Request(options);
    requests.add(request);
    options.onReceiveProgress?.call(3350, 6700);
    return request.response.future;
  }

  @override
  void close({bool force = false}) {
    closed = true;
    for (final request in requests) {
      if (!request.response.isCompleted) {
        request.response.completeError(StateError('Test transport closed'));
      }
    }
  }
}

Future<void> _until(bool Function() ready) async {
  for (var i = 0; i < 200 && !ready(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(ready(), isTrue, reason: 'Download state never became ready');
}

Future<Database> createBookTestDatabase(DatabaseFactory factory) async {
  final db = await factory.openDatabase(inMemoryDatabasePath);
  await db.execute(
    'CREATE TABLE book_meta (id TEXT PRIMARY KEY, '
    'title_ar TEXT, author_ar TEXT, page_count INTEGER)',
  );
  await db.execute(
    'CREATE TABLE book_pages (book_id TEXT, page_index INTEGER, '
    'printed_page INTEGER, content TEXT, body_norm TEXT, '
    'PRIMARY KEY (book_id, page_index))',
  );
  return db;
}

Future<void> verifyBookDownload(
  String scenario,
  Uint8List unchangedBook,
  DatabaseFactory factory,
  Directory documents,
) async {
  final db = await createBookTestDatabase(factory);
  final transport = _Transport();
  final dio = Dio()..httpClientAdapter = transport;
  final api = LibraryApiService.forTesting(
    dio,
    database: db,
    documents: documents.path,
  );
  final outcomes = <Future<Object?>>[];
  var commitSeen = false;
  api.bookDownloads.addListener(() {
    if (api.bookDownloads.value.containsKey(downloadBookId) &&
        !api.canCancelBookDownload(downloadBookId)) {
      commitSeen = true;
      expect(
        api.cancelBookDownload(downloadBookId),
        isFalse,
        reason: 'Do not interrupt the file/index commit',
      );
    }
  });
  Future<void> start(String id) {
    final result = api.downloadBook(
      id,
      scenario == 'activeCancel'
          ? bookById(id)!.textEdition!.url
          : 'http://127.0.0.1/$id',
    );
    outcomes.add(result.then<Object?>((_) => null, onError: (Object e) => e));
    return result;
  }

  void release(_Request request, {bool invalid = false}) {
    if (!request.response.isCompleted) {
      request.response.complete(
        ResponseBody.fromBytes(
          invalid ? [] : unchangedBook,
          200,
          headers: {
            Headers.contentLengthHeader: ['${unchangedBook.length}'],
          },
        ),
      );
    }
  }

  try {
    final first = start(downloadBookId);
    await _until(() => transport.requests.isNotEmpty);
    if (scenario == 'duplicate') {
      final second = start(downloadBookId);
      expect(
        identical(first, second),
        isTrue,
        reason: 'All callers must join the same book operation',
      );
      release(transport.requests.first);
      await Future.wait(outcomes);
      expect(transport.requests, hasLength(1));
    } else if (scenario == 'queuedCancel') {
      unawaited(start('audit_A29_queued'));
      expect(api.bookDownloads.value.containsKey('audit_A29_queued'), isTrue);
      expect(api.bookDownloads.value['audit_A29_queued'], isNull);
      expect(api.cancelBookDownload('audit_A29_queued'), isTrue);
      expect(api.bookDownloads.value.containsKey('audit_A29_queued'), isFalse);
      release(transport.requests.first);
      await Future.wait(outcomes);
      expect(transport.requests, hasLength(1));
      expect(
        await db.query(
          'book_meta',
          where: 'id = ?',
          whereArgs: ['audit_A29_queued'],
        ),
        isEmpty,
      );
    } else if (scenario == 'activeCancel' || scenario == 'retry') {
      expect(api.cancelBookDownload(downloadBookId), isTrue);
      expect(api.bookDownloads.value, isEmpty);
      await outcomes.first;
      expect(transport.requests.first.options.cancelToken!.isCancelled, isTrue);
      expect(await db.query('book_meta'), isEmpty);
      expect(
        await File(await api.bookFilePath(downloadBookId)).exists(),
        isFalse,
      );
      if (scenario == 'retry') {
        unawaited(start(downloadBookId));
        await _until(() => transport.requests.length == 2);
        release(transport.requests.first);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(
          api.bookDownloads.value.containsKey(downloadBookId),
          isTrue,
          reason: 'Old cleanup must not remove the new operation',
        );
        release(transport.requests.last);
      } else {
        release(transport.requests.first);
      }
      await Future.wait(outcomes);
      expect(api.bookDownloads.value, isEmpty);
      if (scenario == 'activeCancel') {
        expect(
          transport.requests,
          hasLength(1),
          reason: 'Cancellation must not fetch a mirror',
        );
      }
    } else if (scenario == 'failure') {
      unawaited(start('audit_A29_next'));
      expect(transport.requests, hasLength(1), reason: 'Books must queue');
      release(transport.requests.first, invalid: true);
      await _until(() => transport.requests.length == 2);
      release(transport.requests.last);
      final results = await Future.wait(outcomes);
      expect(results.first, isNotNull);
      expect(results.last, isNull);
      expect(
        await db.query(
          'book_meta',
          where: 'id = ?',
          whereArgs: ['audit_A29_next'],
        ),
        hasLength(1),
      );
    } else {
      release(transport.requests.first);
      await Future.wait(outcomes);
    }
    if (['success', 'duplicate', 'retry'].contains(scenario)) {
      expect(commitSeen, isTrue);
      expect(
        await db.query(
          'book_meta',
          where: 'id = ?',
          whereArgs: [downloadBookId],
        ),
        hasLength(1),
      );
      expect(await db.query('book_pages'), isNotEmpty);
      expect(
        await File(await api.bookFilePath(downloadBookId)).readAsBytes(),
        unchangedBook,
        reason: 'Religious bytes must remain unchanged',
      );
    }
    expect(api.bookDownloads.value, isEmpty);
  } finally {
    transport.close();
    await Future.wait(outcomes);
    await db.close();
  }
}

/// Actual streamed HTTP, Dio cancellation, unchanged bytes and SQLite index.
/// The server is loopback-only and does not change any hosted religious data.
Future<void> verifyBookHttp(
  Uint8List bytes,
  DatabaseFactory factory,
  Directory documents, {
  required bool cancel,
}) async {
  final db = await createBookTestDatabase(factory);
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final finish = Completer<void>();
  final responseClosed = Completer<void>();
  var requestSeen = false;
  server.listen((request) async {
    requestSeen = true;
    try {
      request.response.bufferOutput = false;
      request.response.contentLength = bytes.length;
      request.response.add(bytes.sublist(0, bytes.length ~/ 2));
      await request.response.flush();
      await finish.future;
      request.response.add(bytes.sublist(bytes.length ~/ 2));
      await request.response.close();
    } on SocketException {
      // An intentionally cancelled client may close before the final chunk.
    } on HttpException {
      // The same cancellation can surface as an HTTP connection close.
    } finally {
      responseClosed.complete();
    }
  });
  final dio = Dio();
  final api = LibraryApiService.forTesting(
    dio,
    database: db,
    documents: documents.path,
  );
  final outcome = api
      .downloadBook(downloadBookId, 'http://127.0.0.1:${server.port}/book')
      .then<Object?>((_) => null, onError: (Object e) => e);
  Object? completedWith;
  unawaited(outcome.then((value) => completedWith = value));
  try {
    try {
      await _until(() => (api.bookDownloads.value[downloadBookId] ?? 0) > 0);
    } catch (error) {
      throw StateError('HTTP readiness: requestSeen=$requestSeen, '
          'state=${api.bookDownloads.value}, result=$completedWith; $error');
    }
    if (cancel) expect(api.cancelBookDownload(downloadBookId), isTrue);
    finish.complete();
    expect(await outcome, isNull);
    await responseClosed.future;
    final file = File(await api.bookFilePath(downloadBookId));
    expect(await file.exists(), !cancel);
    expect(await db.query('book_meta'), cancel ? isEmpty : hasLength(1));
    expect(await db.query('book_pages'), cancel ? isEmpty : isNotEmpty);
    if (!cancel) expect(await file.readAsBytes(), bytes);
    expect(api.bookDownloads.value, isEmpty);
  } finally {
    if (!finish.isCompleted) finish.complete();
    await server.close(force: true);
    dio.close(force: true);
    await outcome;
    await db.close();
  }
}

class _Translations extends AssetLoader {
  const _Translations();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => {};
}

Future<void> verifyBookCard(
  WidgetTester tester,
  String locale, {
  required bool queued,
  Future<void> Function()? capture,
}) async {
  final transport = _Transport();
  final dio = Dio()..httpClientAdapter = transport;
  final api = LibraryApiService.forTesting(dio);
  final outcomes = <Future<Object?>>[];
  final book = bookById(downloadBookId)!;
  var downloads = 0;
  var opens = 0;
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: [for (final code in bookDownloadLocales) Locale(code)],
      startLocale: Locale(locale),
      path: '.',
      saveLocale: false,
      assetLoader: const _Translations(),
      child: Builder(
        builder: (context) => MaterialApp(
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: context.localizationDelegates,
          home: Scaffold(
            body: SingleChildScrollView(
              child: BookCard(
                book: book,
                paths: const {},
                downloads: api,
                onDownload: () => downloads++,
                onOpen: () => opens++,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    for (final id in [if (queued) 'audit_A29_blocker', book.id]) {
      outcomes.add(
        api
            .downloadBook(id, 'http://127.0.0.1/$id')
            .then<Object?>((_) => null, onError: (Object e) => e),
      );
    }
    await _until(() => transport.requests.isNotEmpty);
  });
  try {
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      queued ? null : .5,
    );
    expect(find.byIcon(Icons.download_rounded), findsNothing);
    expect(find.byIcon(Icons.stop_circle_outlined), findsOneWidget);
    expect(downloads, 0);
    expect(opens, 0);
    if (capture != null) await capture();
    await tester.tap(find.byIcon(Icons.stop_circle_outlined));
    await tester.pump();
    expect(api.bookDownloads.value.containsKey(book.id), isFalse);
    if (queued) {
      expect(
        api.bookDownloads.value.containsKey('audit_A29_blocker'),
        isTrue,
        reason: 'Cancelling one card must preserve another book',
      );
    } else {
      expect(transport.requests.first.options.cancelToken!.isCancelled, isTrue);
    }
    await tester.pump();
    await tester.tap(find.byIcon(Icons.download_rounded));
    expect(downloads, 1);
    expect(opens, 0);
  } finally {
    transport.close();
    await tester.runAsync(() => Future.wait(outcomes));
  }
  await tester.pumpWidget(const SizedBox());
  api.bookDownloads.dispose();
}
