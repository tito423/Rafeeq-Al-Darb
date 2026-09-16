import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Hijri «في مثل هذا اليوم» dataset, checked as data rather than as code.
///
/// The Home header's two dates open two different sheets now, and the Hijri one
/// is only worth opening if this file really answers for the day it is asked
/// about. The failure this guards against is the one the feature was built to
/// fix: a sheet that opens on «١٧ رمضان» and shows a list keyed to 8 March.
///
/// The dataset is built by `scripts/fetch_on_this_day_hijri.py` from Arabic
/// Wikipedia's per-Hijri-day pages. Two things about it are worth pinning:
///
///   * **every Hijri day has an entry but two.** A Hijri month is 29 or 30 days,
///     so the keys run 01-01 … 12-30 and a reader can land on any of them —
///     «٢٠ محرم» and «٢٨ محرم» are the two the source itself is silent on.
///   * **the years are parsed, not left in the sentence.** The year link is
///     plain on some lines and piped on others — «[[2 هـ]] - …» beside
///     «[[1021 هـ|1021هـ]] - …» — and the first cut of the parser only handled
///     the plain form, which left twelve of the eighteen lines of «12 ربيع
///     الأول» with an empty year chip and the year sitting inside the text.
void main() {
  late Map<String, dynamic> days;

  setUpAll(() {
    final bytes =
        File('assets/data/on_this_day_hijri_ar.json').readAsBytesSync();
    final raw = (bytes.length > 2 && bytes[0] == 0x1f && bytes[1] == 0x8b)
        ? utf8.decode(gzip.decode(bytes))
        : utf8.decode(bytes);
    final doc = jsonDecode(raw) as Map<String, dynamic>;
    expect(doc['calendar'], 'hijri');
    expect(doc['lang'], 'ar');
    days = doc['days'] as Map<String, dynamic>;
  });

  test('all but the two days the source itself is silent on have events', () {
    final missing = <String>[];
    for (var m = 1; m <= 12; m++) {
      for (var d = 1; d <= 30; d++) {
        final key = '${m.toString().padLeft(2, '0')}-'
            '${d.toString().padLeft(2, '0')}';
        final rows = days[key] as List<dynamic>?;
        if (rows == null || rows.isEmpty) missing.add(key);
      }
    }
    // «٢٠ محرم» and «٢٨ محرم» exist on Arabic Wikipedia and carry no
    // «أحداث» section at all — checked on the pages themselves, not inferred
    // from a failed fetch. The sheet says «لا توجد أحداث مسجّلة لهذا اليوم»
    // on those two, which is the honest answer; inventing two entries to make
    // a test pass is exactly what §1.1 forbids.
    expect(missing, ['01-20', '01-28'],
        reason: 'either a day lost its events, or the source gained some: '
            '${missing.join(', ')}');
    expect(days.length, 358);
  });

  test('the years were parsed out of the lines, not left inside them', () {
    var withYear = 0;
    var total = 0;
    final yearLeftInText = <String>[];
    // A line that still begins with «1021هـ - » is one the parser failed on.
    final leading = RegExp(r'^\s*\d{1,4}\s*(ق\.?\s*هـ|هـ)\s*[-–—:]');

    for (final entry in days.entries) {
      for (final r in (entry.value as List<dynamic>)) {
        final row = r as Map<String, dynamic>;
        final text = row['t'] as String;
        total++;
        if (row['y'] != null) withYear++;
        if (leading.hasMatch(text)) {
          yearLeftInText.add('${entry.key}: ${text.substring(0, 24)}');
        }
      }
    }

    expect(total, greaterThan(3000), reason: 'measured: the crawl found this '
        'many lines across the twelve months');
    expect(yearLeftInText, isEmpty,
        reason: 'the year belongs in its own column:\n'
            '${yearLeftInText.take(10).join('\n')}');
    // Not every line carries a year — Wikipedia writes a few without one — but
    // the overwhelming majority do, and a parser that broke would show it here.
    expect(withYear / total, greaterThan(0.95));
  });

  test('no wiki markup survived into the text', () {
    final markup = <String>[];
    for (final entry in days.entries) {
      for (final r in (entry.value as List<dynamic>)) {
        final t = (r as Map<String, dynamic>)['t'] as String;
        if (t.contains('[[') ||
            t.contains(']]') ||
            t.contains('{{') ||
            t.contains('<ref') ||
            t.contains("'''")) {
          markup.add('${entry.key}: ${t.substring(0, 30)}');
        }
      }
    }
    expect(markup, isEmpty, reason: markup.take(10).join('\n'));
  });

  test('the days that matter most say what they should', () {
    // Read by hand off the pages themselves before this test was written.
    String textOf(String key, int year) => ((days[key] as List<dynamic>)
            .firstWhere((r) => (r as Map<String, dynamic>)['y'] == year)
        as Map<String, dynamic>)['t'] as String;

    // ١٧ رمضان ٢هـ — بدر.
    expect(textOf('09-17', 2), contains('بدر'));
    // ١٠ محرم ٦١هـ — كربلاء.
    expect(textOf('01-10', 61), contains('كربلاء'));
    // ١٢ ربيع الأول ١١هـ — بيعة أبي بكر رضي الله عنه.
    expect(textOf('03-12', 11), contains('أبي بكر'));
  });
}
