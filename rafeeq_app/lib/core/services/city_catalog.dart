import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:geocoding/geocoding.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/arabic_normalize.dart';
import 'manual_location.dart';

/// The world city list behind manual prayer location.
///
/// GeoNames `cities1000` (CC BY 4.0, credited on the Sources screen): every
/// place over 1,000 people or an administrative seat - 171,075 of them - with
/// names only where GeoNames tags the language (scripts/build_cities.py).
/// BUNDLED: «خلي مواقيت مدن العالم بندلد في التطبيق ... دول خمسة ميجا بس»
/// (owner, 2026-09-25) - so a first search works with no network ever. The
/// 5.08 MB gzip ships as an asset and is unpacked and indexed once, off the
/// UI thread. The same file stays on R2 `geo/cities.tsv.gz` + the mirror.
class CityCatalog {
  CityCatalog._();
  static final CityCatalog instance = CityCatalog._();

  static const asset = 'assets/data/cities.tsv.gz';

  /// The asset's size (test/city_catalog_test.dart checks it). It names the
  /// unpacked files, so an app update that ships a new list re-indexes.
  static const bundledBytes = 5080747;

  Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    final d = Directory(p.join(base.path, 'geo'));
    if (!d.existsSync()) await d.create(recursive: true);
    return d;
  }

  Future<File> _tsv() async =>
      File(p.join((await _dir()).path, 'cities-$bundledBytes.tsv'));
  Future<File> _keys() async =>
      File(p.join((await _dir()).path, 'cities-$bundledBytes.key'));

  Future<bool> isInstalled() async =>
      (await _tsv()).existsSync() && (await _keys()).existsSync();

  Future<void>? _preparing;

  /// Unpacks the bundled list on first use; later calls return at once.
  Future<void> ensureReady() => _preparing ??= _prepare().catchError((Object e) {
        _preparing = null; // let the next call try again
        throw e;
      });

  Future<void> _prepare() async {
    if (await isInstalled()) return;
    final dir = await _dir();
    // files of an older list, and the 3.63 pre-release download
    for (final f in dir.listSync().whereType<File>()) {
      if (p.basename(f.path).startsWith('cities')) await f.delete();
    }
    final data = await rootBundle.load(asset);
    final gz = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    final tsv = await _tsv();
    final keys = await _keys();
    // written under temporary names and renamed, so a kill mid-way never
    // leaves a half file that isInstalled() would take for a whole one
    await _prepareOffThread(gz, '${tsv.path}.part', '${keys.path}.part');
    await File('${keys.path}.part').rename(keys.path);
    await File('${tsv.path}.part').rename(tsv.path);
  }

  /// Up to [limit] places whose name in any language starts with, or
  /// contains, [query]; best match first, then the larger place.
  Future<List<CityHit>> search(String query, {int limit = 40}) async {
    final q = foldForSearch(query.trim());
    if (q.length < 2) return const [];
    await ensureReady();
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

// Top level ON PURPOSE. Isolate.run sends its closure's whole scope; a
// closure inside a method that also holds a callback into a widget's State
// cannot cross to an isolate. Here the scope is only strings and bytes.
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
