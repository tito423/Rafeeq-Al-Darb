import 'dart:async';
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../config/app_config.dart';

/// On-device storage for the Quran translations that are **not** bundled.
///
/// The six translations in `quran_sciences.db` (en/es/fr/pt/ru/ur) are
/// untouched by this class and keep working with no connection. Every other
/// language is fetched once from R2 (~250-450 KB gzipped) and then lives here,
/// so it is offline from the second time onwards.
///
/// One row per ayah rather than one blob per language: the reader asks for a
/// single ayah at a time, and a 6,236-row keyed lookup is instant, whereas
/// holding several decoded languages in memory would not be.
class QuranTranslationStore {
  QuranTranslationStore._();
  static final QuranTranslationStore instance = QuranTranslationStore._();

  static const _dbName = 'quran_translations.db';

  Database? _db;
  final Dio _dio = Dio();

  /// Languages already on disk. Kept in memory because the picker rebuilds on
  /// every ayah and must not hit SQLite each time.
  final ValueNotifier<Set<String>> installed = ValueNotifier(const {});

  /// Language currently downloading -> 0..1 progress, for the picker's spinner.
  final ValueNotifier<Map<String, double>> downloading = ValueNotifier(const {});

  Future<Database> get _database async {
    if (_db != null) return _db!;
    final path = p.join(await getDatabasesPath(), _dbName);
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE verses (
            lang TEXT NOT NULL,
            ref  TEXT NOT NULL,
            text TEXT NOT NULL,
            PRIMARY KEY (lang, ref)
          )
        ''');
        await db.execute('''
          CREATE TABLE editions (
            lang       TEXT PRIMARY KEY,
            edition    TEXT,
            translator TEXT
          )
        ''');
      },
    );
    return _db!;
  }

  /// Loads [installed] from disk. Call once at startup.
  Future<void> refreshInstalled() async {
    final db = await _database;
    final rows = await db.rawQuery('SELECT lang FROM editions');
    installed.value = {for (final r in rows) r['lang'] as String};
  }

  bool isInstalled(String lang) => installed.value.contains(lang);

  /// One ayah in [lang], or null when that language isn't downloaded.
  Future<String?> verse(String lang, int surah, int ayah) async {
    final db = await _database;
    final rows = await db.rawQuery(
      'SELECT text FROM verses WHERE lang = ? AND ref = ? LIMIT 1',
      [lang, '$surah:$ayah'],
    );
    if (rows.isEmpty) return null;
    return rows.first['text'] as String?;
  }

  /// The translator credited for a downloaded [lang], or null.
  Future<String?> translator(String lang) async {
    final db = await _database;
    final rows = await db.rawQuery(
      'SELECT translator FROM editions WHERE lang = ? LIMIT 1',
      [lang],
    );
    if (rows.isEmpty) return null;
    return rows.first['translator'] as String?;
  }

  void _setProgress(String lang, double? value) {
    final next = Map<String, double>.from(downloading.value);
    if (value == null) {
      next.remove(lang);
    } else {
      next[lang] = value;
    }
    downloading.value = next;
  }

  /// Fetches [lang] from R2 and stores every ayah. Safe to call for a language
  /// that is already installed (returns immediately) or already downloading.
  ///
  /// Throws on failure so the caller can show a real error rather than an
  /// empty translation pane.
  Future<void> download(String lang) async {
    if (isInstalled(lang) || downloading.value.containsKey(lang)) return;
    _setProgress(lang, 0);
    try {
      final res = await _dio.get<List<int>>(
        AppConfig.quranTranslationUrl(lang),
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 60),
        ),
        onReceiveProgress: (received, total) {
          if (total > 0) _setProgress(lang, received / total);
        },
      );

      var bytes = res.data ?? const <int>[];
      if (bytes.length < 1024) {
        throw StateError('Translation $lang came back empty');
      }
      // The object is stored with Content-Encoding: gzip, so most clients hand
      // it back already inflated — but not all do, and Dio's behaviour depends
      // on the platform HTTP stack. Sniff the gzip magic number instead of
      // assuming either way.
      if (bytes.length > 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
        bytes = const GZipDecoder().decodeBytes(bytes);
      }

      final doc =
          jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final verses = (doc['verses'] as Map<String, dynamic>);
      if (verses.length != 6236) {
        throw StateError(
          'Translation $lang is incomplete (${verses.length}/6236 ayahs)',
        );
      }

      final db = await _database;
      await db.transaction((txn) async {
        final batch = txn.batch();
        batch.delete('verses', where: 'lang = ?', whereArgs: [lang]);
        verses.forEach((ref, text) {
          batch.insert('verses', {
            'lang': lang,
            'ref': ref,
            'text': text as String,
          });
        });
        batch.insert(
          'editions',
          {
            'lang': lang,
            'edition': doc['edition'] as String? ?? '',
            'translator': doc['translator'] as String? ?? '',
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await batch.commit(noResult: true);
      });

      installed.value = {...installed.value, lang};
    } finally {
      _setProgress(lang, null);
    }
  }

  /// Deletes a downloaded language, freeing its rows.
  Future<void> remove(String lang) async {
    final db = await _database;
    await db.delete('verses', where: 'lang = ?', whereArgs: [lang]);
    await db.delete('editions', where: 'lang = ?', whereArgs: [lang]);
    installed.value = {...installed.value}..remove(lang);
  }
}
