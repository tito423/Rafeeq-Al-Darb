import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/services/city_catalog.dart';

/// Runs against the REAL list built by scripts/build_cities.py (the bytes
/// uploaded to R2 geo/cities.tsv.gz). Skipped where that file is absent.
void main() {
  final gz = File('../scripts/_geonames/out/cities.tsv.gz');
  final tmp = Directory.systemTemp.createTempSync('cities');
  final tsv = '${tmp.path}/cities.tsv';
  final key = '${tmp.path}/cities.key';

  setUpAll(() {
    if (gz.existsSync()) prepareCityFiles(gz.readAsBytesSync(), tsv, key);
  });

  String first(String q, [String lang = 'en']) {
    final hits = searchCityFiles(tsv, key, foldForSearch(q), 5);
    final p = hits.first.place;
    return '${p.cityIn(lang)}, ${p.countryIn(lang)}';
  }

  test('Arabic and Latin queries find the right place first', () {
    final sw = Stopwatch()..start();
    expect(first('دبي', 'ar'), 'دبي, الإمارات العربية المتحدة');
    expect(first('دبى', 'ar'), 'دبي, الإمارات العربية المتحدة');
    expect(first('dubai'), 'Dubai, United Arab Emirates');
    expect(first('Dubaï'), 'Dubai, United Arab Emirates');
    expect(first('القاهرة', 'ar'), startsWith('القاهرة, مصر'));
    expect(first('طنطا', 'ar'), startsWith('طنطا'));
    expect(first('makkah'), contains('Saudi Arabia'));
    // ignore: avoid_print
    print('6 searches: ${sw.elapsedMilliseconds} ms');
  }, skip: gz.existsSync() ? false : 'no built city list');
}
