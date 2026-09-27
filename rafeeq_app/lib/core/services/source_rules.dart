import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';
import '../config/content_mirrors.dart';

/// How the app reads the two sites it parses live - dorar.net and
/// shamela.ws - kept as data, so a change on either site is fixed by
/// publishing a new `config/source_rules.json` on R2 (mirrored on the
/// `content-mirror` GitHub release) instead of shipping a new APK.
///
/// Owner, 2026-09-27: «احتياط ديناميكي بحيث لو الموقعين غيروا حاجة
/// الاستيراد الخارجي يبقى ديناميكي».
///
/// Rules are markers (`indexOf` strings), regular expressions and URL
/// templates. [defaults] are the values the parsers were written and tested
/// with; a published rule replaces a default only when it is newer
/// ([version]) and, for a regex, compiles. A broken or missing download
/// leaves the defaults (or the last good cached copy) in place.
/// `scripts/check_sources.py` runs the same rules against the live sites.
class SourceRules {
  SourceRules._();
  static final SourceRules instance = SourceRules._();

  /// The version [defaults] correspond to. A published file must be newer.
  static const int builtInVersion = 1;

  static const Map<String, String> defaults = {
    // dorar.net encyclopaedias (dorar_encyclopedia.dart)
    'dorar.toc.start': 'id="mtree"',
    'dorar.toc.token': r'<ul\b|</ul>|<a\s+href="([^"]*)"[^>]*>(.*?)</a>',
    'dorar.section.start': '<div class="w-100 mt-4">',
    'dorar.section.end': 'id="more-titles"',
    'dorar.section.end_alt': 'public-qa-section',
    'dorar.section.card': 'id="cntnt"',
    'dorar.section.title': r'<h1[^>]*>(.*?)</h1>',
    'dorar.section.footnote': r'<span class="tip">(.*?)</span>',
    'dorar.section.heading': r'<span class="title-\d">(.*?)</span>',
    'dorar.section.drop': r'<a id="enc-tip".*?</a>',
    // dorar.net Tafseer encyclopaedia: surah cards and chained pages
    'dorar.tafseer.surah':
        r'<a href="/tafseer/(\d+)">\s*<strong>(.*?)</strong>',
    'dorar.chain.article': r'<article[^>]*>(.*?)</article>',
    'dorar.chain.heading': r'<h5[^>]*>(.*?)</h5>',
    'dorar.chain.title': r'<title>(.*?)</title>',
    'dorar.chain.link': r'<a[^>]*href="(/[a-z]+/[\d/]+)"[^>]*>(.*?)</a>',
    'dorar.chain.prev': 'السابق',
    'dorar.chain.next': 'التالي',
    // dorar.net hadith grading API (dorar_service.dart)
    'dorar.api.url': 'https://dorar.net/dorar_api.json',
    'dorar.api.block':
        r'<div class="hadith"[^>]*>(.*?)</div>\s*<div class="hadith-info">(.*?)</div>',
    'dorar.api.label.rawi': 'الراوي',
    'dorar.api.label.muhaddith': 'المحدث',
    'dorar.api.label.source': 'المصدر',
    'dorar.api.label.page': 'الصفحة أو الرقم',
    'dorar.api.label.grade': 'خلاصة حكم المحدث',
    // shamela.ws (shamela_book_builder.dart)
    'shamela.card': r'<div style="line-height: 1\.8;">(.*?)</div>',
    'shamela.card.title': r'الكتاب\s*:\s*(.+)',
    'shamela.card.author': r'المؤلف\s*:\s*(.+)',
    'shamela.page.path': '/ajax/pageContent/{book}/{page}',
  };

  final Map<String, String> _live = Map.of(defaults);
  int _version = builtInVersion;
  final Map<String, RegExp> _regexCache = {};

  int get version => _version;

  /// A marker or template.
  String s(String key) => _live[key] ?? defaults[key]!;

  /// A regular expression - dotAll by default (block patterns); line
  /// patterns such as «الكتاب : (.+)» pass `dotAll: false`.
  RegExp re(String key, {bool dotAll = true}) =>
      _regexCache['$key|$dotAll'] ??= RegExp(s(key), dotAll: dotAll);

  static const _path = 'config/source_rules.json';

  Future<File> _cacheFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/source_rules.json');
  }

  /// Applies the cached copy at once, then fetches the published one in the
  /// background. Called once at launch.
  Future<void> load() async {
    try {
      final f = await _cacheFile();
      if (f.existsSync()) apply(await f.readAsString());
    } catch (e) {
      debugPrint('source rules cache: $e');
    }
    try {
      final body = await ContentMirrors.fetchFirst<String>(
        '${AppConfig.contentBaseUrl}/$_path',
        (u) async => (await Dio().get<String>(u,
                options: Options(
                  responseType: ResponseType.plain,
                  receiveTimeout: const Duration(seconds: 20),
                )))
            .data!,
        accept: (b) => b.trimLeft().startsWith('{'),
      );
      if (apply(body)) {
        await (await _cacheFile()).writeAsString(body);
      }
    } catch (e) {
      debugPrint('source rules fetch: $e');
    }
  }

  /// Takes a published rules file. Returns whether it was applied: only a
  /// newer version, and only its rules that are known keys and, for
  /// patterns, compile. Public for tests.
  bool apply(String json) {
    final Map<String, dynamic> j;
    try {
      j = jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return false;
    }
    final v = (j['version'] as num?)?.toInt() ?? 0;
    if (v <= _version) return false;
    final rules = (j['rules'] as Map?)?.cast<String, dynamic>() ?? const {};
    for (final e in rules.entries) {
      if (!defaults.containsKey(e.key) || e.value is! String) continue;
      final value = e.value as String;
      if (_isPattern(e.key)) {
        try {
          RegExp(value, dotAll: true);
        } catch (_) {
          continue; // a broken pattern never replaces a working one
        }
      }
      _live[e.key] = value;
    }
    _version = v;
    _regexCache.clear();
    return true;
  }

  /// Keys whose value is a regular expression (the rest are plain markers,
  /// labels or URL templates).
  static bool _isPattern(String key) => const {
        'dorar.toc.token',
        'dorar.section.title',
        'dorar.section.footnote',
        'dorar.section.heading',
        'dorar.section.drop',
        'dorar.api.block',
        'dorar.tafseer.surah',
        'dorar.chain.article',
        'dorar.chain.heading',
        'dorar.chain.title',
        'dorar.chain.link',
        'shamela.card',
        'shamela.card.title',
        'shamela.card.author',
      }.contains(key);

  /// Back to [defaults] (tests).
  @visibleForTesting
  void reset() {
    _live
      ..clear()
      ..addAll(defaults);
    _version = builtInVersion;
    _regexCache.clear();
  }
}
