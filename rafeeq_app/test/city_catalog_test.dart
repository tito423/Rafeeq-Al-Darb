import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/services/city_catalog.dart';

/// Runs against the REAL list the app ships (assets/data/cities.tsv.gz,
/// built by scripts/build_cities.py - the same bytes as R2 geo/cities.tsv.gz).
void main() {
  final gz = File(CityCatalog.asset);
  final tmp = Directory.systemTemp.createTempSync('cities');
  final tsv = '${tmp.path}/cities.tsv';
  final key = '${tmp.path}/cities.key';

  setUpAll(() {
    prepareCityFiles(gz.readAsBytesSync(), tsv, key);
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
  });

  test('the unpacked-file name tracks the bundled list', () {
    // bundledBytes names the index on the device: a new list with a stale
    // constant would keep searching the old one.
    expect(gz.lengthSync(), CityCatalog.bundledBytes);
  });
}
