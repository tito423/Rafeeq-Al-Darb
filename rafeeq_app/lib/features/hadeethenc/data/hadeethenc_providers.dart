import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_locale_provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/db/db_helper.dart';
import '../../../core/db/hadeethenc_repository.dart';
import '../../../core/services/download_manager.dart';

/// One language pack of موسوعة الأحاديث النبوية.
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

  /// The database the pack becomes on the device.
  String get fileName => 'hadeethenc_$lang.db';

  /// The name the zip is SAVED UNDER locally — and it has to be
  /// `<fileName without .db>.zip`, not `<lang>.zip`.
  ///
  /// `DownloadManager._unzipToDatabases` names the extracted database after
  /// the **zip's** basename, not after the entry inside it:
  /// `p.basenameWithoutExtension(zipPath) + '.db'`. `hadith.zip` has always
  /// worked because those two names happen to be the same word. Saving these
  /// packs as `ar.zip` produced `ar.db`, while the repository opened
  /// `hadeethenc_ar.db` — so the download succeeded, the unzip succeeded, and
  /// the tab kept showing its download button forever. Found by opening the
  /// tab on emulator-5554; `flutter analyze`, 66 passing tests and a verified
  /// upload all said it was fine (CLAUDE.md §1.3, and trap #23's lesson
  /// exactly).
  ///
  /// Derived from [fileName] rather than written out again, so the two cannot
  /// drift apart; `hadeethenc_pack_test.dart` asserts they never do.
  String get zipFileName => '${fileName.substring(0, fileName.length - 3)}.zip';

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

/// The repository over the pack for the app's language — which is always on
/// the device now.
///
/// «نزّل الموسوعة الحديثية وادمجها مع التطبيق out of box». All seven packs
/// ship inside the APK as `assets/data/hadeethenc/hadeethenc_<lang>.zip`
/// (15.9 MB together; each zip was checked byte-for-byte against the
/// catalogue and row-for-row against its hadith count before it was bundled).
/// Only the pack for the language in use is unpacked, the first time it is
/// opened — so there is no download, no «حزمة العربية» to explain, and the
/// Home card has its explanation from the first launch with no network.
final hadeethEncRepositoryProvider =
    FutureProvider<HadeethEncRepository?>((ref) async {
  final catalog = await ref.watch(hadeethEncCatalogProvider.future);
  final pack = catalog.forLocale(ref.watch(appLocaleProvider));
  if (pack == null) return null;
  final db = await HadeethEncInstaller.open(pack);
  return db == null ? null : HadeethEncRepository(db);
});

/// Unpacks a bundled pack into the databases directory once, and opens it.
class HadeethEncInstaller {
  HadeethEncInstaller._();

  static String assetFor(HadeethEncPack pack) =>
      'assets/data/hadeethenc/${pack.zipFileName}';

  static Future<Database?> open(HadeethEncPack pack) async {
    // A pack downloaded by an earlier build is the same file under the same
    // version stamp, so it opens as it is.
    final existing = await DbHelper.instance.openDownloaded(
      pack.fileName,
      expectedVersion: AppConfig.hadeethEncVersion,
    );
    if (existing != null) {
      unawaited(_forgetDownloadedPacks());
      return existing;
    }

    final data = await rootBundle.load(assetFor(pack));
    final zipped =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    // 21 MB of Arabic inflates off the UI thread.
    final db = await Isolate.run(() {
      for (final entry in ZipDecoder().decodeBytes(zipped)) {
        if (entry.isFile && entry.name.toLowerCase().endsWith('.db')) {
          return Uint8List.fromList(entry.content as List<int>);
        }
      }
      return null;
    });
    if (db == null) return null;

    final support = await getApplicationSupportDirectory();
    final dir = p.join(support.path, 'databases');
    await Directory(dir).create(recursive: true);
    final target = p.join(dir, pack.fileName);
    final tmp = File('$target.tmp');
    await tmp.writeAsBytes(db, flush: true);
    final dest = File(target);
    if (dest.existsSync()) await dest.delete();
    await tmp.rename(target);
    await File('$target.version')
        .writeAsString(AppConfig.hadeethEncVersion, flush: true);
    unawaited(_forgetDownloadedPacks());
    return DbHelper.instance.openDownloaded(
      pack.fileName,
      expectedVersion: AppConfig.hadeethEncVersion,
    );
  }

  /// Earlier builds registered each downloaded pack as a download — the
  /// «العربية» row under «العناصر المنزَّلة» he asked about. The file is the
  /// installed database now, so the entry is dropped without deleting it.
  static Future<void> _forgetDownloadedPacks() async {
    try {
      await DownloadManager.instance.forgetCategory('hadeethenc');
    } catch (_) {}
  }
}
