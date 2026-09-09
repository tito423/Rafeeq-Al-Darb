import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_locale_provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/db/db_helper.dart';
import '../../../core/db/hadeethenc_repository.dart';

/// One downloadable language pack of موسوعة الأحاديث النبوية.
///
/// [bytes] is not an estimate: `scripts/r2_upload_hadeethenc.py` writes the
/// catalogue only after reading each object back off the public endpoint and
/// checking that it answers `PK` with a matching `Content-Length`. CLAUDE.md
/// §1.1 — «الحجم: 1.0 MB» was written into a widget once and every book on
/// the shelf claimed it.
class HadeethEncPack {
  final String lang;

  /// The language's own name — what a reader scans for.
  final String name;
  final int hadeeths;
  final int categories;

  /// The zip on the bucket, measured.
  final int bytes;

  /// The unpacked `.db`, so the download screen can say what it costs on
  /// disk as well as over the wire.
  final int dbBytes;

  const HadeethEncPack({
    required this.lang,
    required this.name,
    required this.hadeeths,
    required this.categories,
    required this.bytes,
    required this.dbBytes,
  });

  factory HadeethEncPack.fromJson(Map<String, dynamic> j) => HadeethEncPack(
        lang: j['lang'] as String,
        name: j['name'] as String,
        hadeeths: j['hadeeths'] as int? ?? 0,
        categories: j['categories'] as int? ?? 0,
        bytes: j['bytes'] as int? ?? 0,
        dbBytes: j['db_bytes'] as int? ?? 0,
      );

  String get fileName => 'hadeethenc_$lang.db';
  String get downloadId => 'hadeethenc_$lang';
  String get url => AppConfig.hadeethEncUrl(lang);

  /// Right-to-left packs, so a hadith is laid out the way its readers read
  /// it. Arabic and Urdu are the two here; the paragraph direction matters
  /// even when the app's own chrome is left-to-right — CLAUDE.md trap and
  /// `ArabicText`'s reason for existing.
  bool get isRtl => lang == 'ar' || lang == 'ur';
}

/// What the bundled catalogue offers, and the source it credits.
class HadeethEncCatalog {
  final String sourceAr;
  final String sourceEn;
  final String sourceUrl;
  final List<HadeethEncPack> packs;

  const HadeethEncCatalog({
    required this.sourceAr,
    required this.sourceEn,
    required this.sourceUrl,
    required this.packs,
  });

  /// The publisher's name as that language writes it. The credit the
  /// source's terms require has to be readable by the person reading it, so
  /// an English UI is credited «Hadeeth Encyclopedia (HadeethEnc.com)» and an
  /// Arabic one «موسوعة الأحاديث النبوية». Urdu takes the Arabic form: it is
  /// the name the encyclopedia itself uses on its Arabic pages and an Urdu
  /// reader reads it, the same finding as the Urdu grading terminology.
  String nameFor(String localeCode) =>
      localeCode == 'ar' || localeCode == 'ur' ? sourceAr : sourceEn;

  /// The pack for [localeCode] if there is one. Every one of the app's seven
  /// locales has a pack, so this is never null in practice — but it is
  /// nullable rather than falling back to Arabic, because silently handing a
  /// French reader an Arabic corpus is the kind of "helpful" default this
  /// project does not ship.
  HadeethEncPack? forLocale(String localeCode) {
    for (final p in packs) {
      if (p.lang == localeCode) return p;
    }
    return null;
  }
}

final hadeethEncCatalogProvider =
    FutureProvider<HadeethEncCatalog>((ref) async {
  final raw =
      await rootBundle.loadString('assets/data/catalogs/hadeethenc.json');
  final doc = jsonDecode(raw) as Map<String, dynamic>;
  final source = doc['source'] as Map<String, dynamic>;
  return HadeethEncCatalog(
    sourceAr: source['title_ar'] as String,
    sourceEn: source['title_en'] as String,
    sourceUrl: source['url'] as String,
    packs: [
      for (final e in doc['languages'] as List<dynamic>)
        HadeethEncPack.fromJson(e as Map<String, dynamic>)
    ],
  );
});

/// The pack that matches the app's current language.
final hadeethEncPackProvider = Provider<AsyncValue<HadeethEncPack?>>((ref) {
  final locale = ref.watch(appLocaleProvider);
  return ref
      .watch(hadeethEncCatalogProvider)
      .whenData((c) => c.forLocale(locale));
});

/// The repository over the downloaded pack, or null when it is not on the
/// device yet.
///
/// Keyed on the app's locale so switching language moves to that language's
/// pack — including back to "not downloaded", which is the honest state for a
/// language whose pack the reader has never fetched.
final hadeethEncRepositoryProvider =
    FutureProvider<HadeethEncRepository?>((ref) async {
  final pack = ref.watch(hadeethEncPackProvider).valueOrNull;
  if (pack == null) return null;
  final db = await DbHelper.instance.openDownloaded(
    pack.fileName,
    expectedVersion: AppConfig.hadeethEncVersion,
  );
  return db == null ? null : HadeethEncRepository(db);
});
