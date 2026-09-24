import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:geocoding/geocoding.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';
import '../config/content_mirrors.dart';
import '../utils/arabic_normalize.dart';
import 'manual_location.dart';

/// The world city list behind manual prayer location.
///
/// GeoNames `cities1000` (CC BY 4.0, credited on the Sources screen): every
/// place over 1,000 people or an administrative seat - 171,075 of them - with
/// names only where GeoNames tags the language (scripts/build_cities.py).
/// HOSTED, not bundled - «without app size growing» (owner, 2026-09-25):
/// 5.08 MB on R2 `geo/cities.tsv.gz` and the GitHub mirror, downloaded once,
/// then searched on the device with no network at all.
class CityCatalog {
  CityCatalog._();
  static final CityCatalog instance = CityCatalog._();

  static String get url => '${AppConfig.contentBaseUrl}/geo/cities.tsv.gz';

  /// Measured on R2, 2026-09-25 (head_object ContentLength).
  static const downloadBytes = 5080747;

  Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    final d = Directory(p.join(base.path, 'geo'));
    if (!d.existsSync()) await d.create(recursive: true);
    return d;
  }

  Future<File> _tsv() async => File(p.join((await _dir()).path, 'cities.tsv'));
  Future<File> _keys() async => File(p.join((await _dir()).path, 'cities.key'));

  Future<bool> isInstalled() async =>
      (await _tsv()).existsSync() && (await _keys()).existsSync();

  /// Downloads the list (first host that answers, [ContentMirrors]) and
  /// prepares the search index. [onProgress] gets 0..1.
  Future<void> download({void Function(double)? onProgress}) async {
    final bytes = await ContentMirrors.fetchFirst<List<int>>(url, (u) async {
      final res = await Dio().get<List<int>>(
        u,
        options: Options(responseType: ResponseType.bytes),
        onReceiveProgress: (r, t) =>
            onProgress?.call((t > 0 ? r / t : r / downloadBytes) * 0.9),
      );
      return res.data ?? const [];
    }, accept: (b) => b.length > 1000);
    final tsv = await _tsv();
    final keys = await _keys();
    // gzip without Content-Encoding (trap #6): decoded here, and the index
    // is built off the UI thread.
    await _prepareOffThread(bytes, tsv.path, keys.path);
    onProgress?.call(1);
  }

  Future<void> delete() async {
    for (final f in [await _tsv(), await _keys()]) {
      if (f.existsSync()) await f.delete();
    }
  }

  /// Up to [limit] places whose name in any language starts with, or
  /// contains, [query]; best match first, then the larger place.
  Future<List<CityHit>> search(String query, {int limit = 40}) async {
    final q = foldForSearch(query.trim());
    if (q.length < 2 || !await isInstalled()) return const [];
    final tsv = (await _tsv()).path;
    final keys = (await _keys()).path;
    return _searchOffThread(tsv, keys, q, limit);
  }

  /// A place found by name through the phone's geocoder - any village or
  /// address on Earth, but only with a connection. Names come back in
  /// [lang]; nothing is filled in that the geocoder did not return.
  Future<List<CityHit>> searchOnline(String query, String lang) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    try {
      await setLocaleIdentifier(lang);
      final found = await locationFromAddress(q);
      final out = <CityHit>[];
      for (final l in found.take(5)) {
        final marks =
            await placemarkFromCoordinates(l.latitude, l.longitude);
        final m = marks.isEmpty ? null : marks.first;
        final city = [m?.locality, m?.subAdministrativeArea,
                      m?.administrativeArea, q]
            .firstWhere((s) => s != null && s.isNotEmpty)!;
        out.add(CityHit(
          ManualPlace(
            latitude: l.latitude,
            longitude: l.longitude,
            names: {'name': city, lang: city},
            countries: {
              if (m?.country?.isNotEmpty ?? false) ...{
                'name': m!.country!,
                lang: m.country!,
              },
            },
          ),
          population: 0,
        ));
      }
      return out;
    } catch (_) {
      return const [];
    }
  }
}

// Top level ON PURPOSE. Isolate.run sends its closure's whole scope, and
// inside [CityCatalog.download] that scope held the progress callback -
// which holds the screen's State, which cannot cross to an isolate. The
// download reached 46 % and then failed on emulator-5554 (2026-09-25). Here
// the scope is only strings and bytes.
Future<void> _prepareOffThread(List<int> gz, String tsv, String key) =>
    Isolate.run(() => prepareCityFiles(gz, tsv, key));

Future<List<CityHit>> _searchOffThread(
        String tsv, String key, String q, int limit) =>
    Isolate.run(() => searchCityFiles(tsv, key, q, limit));

class CityHit {
  final ManualPlace place;
  final int population;
  const CityHit(this.place, {required this.population});
}

const _langs = ['ar', 'ur', 'ru', 'fr', 'es', 'pt', 'en'];

/// Lower case, Arabic letters folded the way the Quran search folds them
/// (alef/hamza/ta marbuta/ya forms, no tashkeel), Latin accents dropped -
/// so «دبى», «دبي», «Dubaï» and «dubai» all meet.
String foldForSearch(String s) {
  var t = normalizeArabicLoose(s.toLowerCase());
  final b = StringBuffer();
  for (final r in t.runes) {
    final c = String.fromCharCode(r);
    b.write(_latinFold[c] ?? c);
  }
  t = b.toString();
  return t.replaceAll(RegExp(r"[\s\-'’`.]+"), ' ').trim();
}

const _latinFold = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a',
  'ç': 'c', 'č': 'c', 'ć': 'c', 'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
  'ē': 'e', 'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ı': 'i', 'ī': 'i',
  'ñ': 'n', 'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o',
  'ō': 'o', 'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u', 'ý': 'y',
  'ÿ': 'y', 'ş': 's', 'š': 's', 'ś': 's', 'ğ': 'g', 'ž': 'z', 'ź': 'z',
  'ż': 'z', 'ł': 'l', 'ß': 'ss', 'ḥ': 'h', 'ṣ': 's', 'ṭ': 't', 'ḍ': 'd',
  'ẓ': 'z', 'ʿ': '', 'ʾ': '',
};

@visibleForTesting
void prepareCityFiles(List<int> gz, String tsvPath, String keyPath) {
  final lines = utf8.decode(gzip.decode(gz)).split('\n');
  final keys = StringBuffer();
  final out = StringBuffer();
  for (final line in lines) {
    if (line.isEmpty) continue;
    out.writeln(line);
    if (line.startsWith('#')) {
      keys.writeln('');
      continue;
    }
    final c = line.split('\t');
    // name (4), ar..en (5..11), search-only Arabic-script alternates (12)
    final names = <String>{
      for (var i = 4; i < c.length && i <= 11; i++)
        if (c[i].isNotEmpty) foldForSearch(c[i]),
      if (c.length > 12)
        for (final a in c[12].split('|'))
          if (a.isNotEmpty) foldForSearch(a),
    };
    keys.writeln(names.join('|'));
  }
  File(tsvPath).writeAsStringSync(out.toString());
  File(keyPath).writeAsStringSync(keys.toString());
}

@visibleForTesting
List<CityHit> searchCityFiles(String tsvPath, String keyPath, String q, int limit) {
  final lines = File(tsvPath).readAsLinesSync();
  final keys = File(keyPath).readAsLinesSync();
  final countries = <String, Map<String, String>>{};
  final scored = <(int, int, int)>[]; // (score, -population, line)
  for (var i = 0; i < lines.length && i < keys.length; i++) {
    final line = lines[i];
    if (line.startsWith('#')) {
      final c = line.substring(1).split('\t');
      // #cc en ar ur ru fr es pt
      countries[c[0]] = {
        'name': c[1],
        'en': c[1],
        for (var k = 0; k < 6 && k + 2 < c.length; k++)
          if (c[k + 2].isNotEmpty) _langs[k]: c[k + 2],
      };
      continue;
    }
    final key = keys[i];
    if (!key.contains(q)) continue;
    var best = 9;
    for (final n in key.split('|')) {
      final s = n == q
          ? 0
          : n.startsWith(q)
              ? 1
              : n.contains(' $q')
                  ? 2
                  : n.contains(q) && q.length >= 3
                      ? 3
                      : 9;
      if (s < best) best = s;
    }
    if (best == 9) continue;
    final pop = int.tryParse(line.split('\t')[3]) ?? 0;
    scored.add((best, -pop, i));
  }
  scored.sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2);
  return [
    for (final s in scored.take(limit)) _hit(lines[s.$3], countries),
  ];
}

CityHit _hit(String line, Map<String, Map<String, String>> countries) {
  final c = line.split('\t');
  return CityHit(
    ManualPlace(
      latitude: double.parse(c[0]),
      longitude: double.parse(c[1]),
      names: {
        'name': c[4],
        for (var k = 0; k < _langs.length && k + 5 < c.length; k++)
          if (c[k + 5].isNotEmpty) _langs[k]: c[k + 5],
      },
      countries: countries[c[2]] ?? {'name': c[2]},
    ),
    population: int.tryParse(c[3]) ?? 0,
  );
}
