import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One Quran translation language the reader can choose.
///
/// The owner asked for 30+ languages for the **Quran translation** — not for
/// the app's own UI chrome, which stays on its six locales. The catalog is
/// built by `scripts/r2_upload_quran_translations.py` from api.alquran.cloud
/// (the same provider the bundled six already came from, and one the app
/// already credits on its Sources screen), one established translation per
/// language, rehosted first-party on R2.
class QuranTranslationInfo {
  /// ISO code, e.g. 'tr'.
  final String lang;

  /// The language's own name, e.g. 'Türkçe' — what a reader looking for their
  /// language actually scans for, so the picker shows this rather than an
  /// Arabic or English exonym.
  final String nativeName;

  /// Upstream edition identifier, e.g. 'tr.diyanet'.
  final String edition;

  final String translator;

  /// Gzipped download size. Shown in the picker so a reader on mobile data
  /// knows what a language costs before tapping it.
  final int gzBytes;

  /// True for the six translations that ship inside `quran_sciences.db` — they
  /// need no download and work with no connection at all.
  final bool bundled;

  const QuranTranslationInfo({
    required this.lang,
    required this.nativeName,
    required this.edition,
    required this.translator,
    required this.gzBytes,
    required this.bundled,
  });

  factory QuranTranslationInfo.fromJson(Map<String, dynamic> j) =>
      QuranTranslationInfo(
        lang: j['lang'] as String,
        nativeName: j['native_name'] as String,
        edition: j['edition'] as String,
        translator: j['translator'] as String? ?? '',
        gzBytes: j['gz_bytes'] as int? ?? 0,
        bundled: j['bundled'] as bool? ?? false,
      );

  /// Languages written right-to-left, so the ayah's translation is laid out
  /// the way its readers actually read it.
  static const _rtl = {'ur', 'fa', 'ps', 'sd', 'ku', 'dv', 'ug'};

  bool get isRtl => _rtl.contains(lang);

  String get sizeLabel => gzBytes < 1024 * 1024
      ? '${(gzBytes / 1024).round()} KB'
      : '${(gzBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Every translation language on offer, newest catalog wins.
final quranTranslationCatalogProvider =
    FutureProvider<List<QuranTranslationInfo>>((ref) async {
  final raw = await rootBundle
      .loadString('assets/data/catalogs/quran_translations.json');
  final doc = jsonDecode(raw) as Map<String, dynamic>;
  final list = [
    for (final e in doc['translations'] as List<dynamic>)
      QuranTranslationInfo.fromJson(e as Map<String, dynamic>)
  ];
  // Bundled languages first (they always work), then the rest by native name.
  list.sort((a, b) {
    if (a.bundled != b.bundled) return a.bundled ? -1 : 1;
    return a.nativeName.compareTo(b.nativeName);
  });
  return list;
});
