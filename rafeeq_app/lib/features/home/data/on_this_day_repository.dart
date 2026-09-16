/// «في مثل هذا اليوم» — what happened on today's date, from Wikipedia.
///
/// «عايز لما أضغط على التاريخ الهجري تجيب ما يوافقه في كارت … ويعرض الأحداث
/// التاريخية خاصة اللي تخص التاريخ الإسلامي اللي حصلت في اليوم ده».
///
/// WHERE THE EVENTS COME FROM, AND WHY NOT FROM ME.
/// §1.1 forbids writing content and presenting it as sourced, and a calendar
/// of events I composed would be exactly that. Wikimedia's `onthisday` feed is
/// a real, openly licensed source that covers all 366 days — the owner's own
/// point that «كل يوم فيه حاجات حصلت» is true, and this is the list that
/// proves it rather than a list that asserts it. The text is CC BY-SA 4.0, so
/// the card credits Wikipedia and links to the day's own page.
///
/// Bundled, not fetched: the app is offline-first and a card that needs the
/// network to show a date is blank on a plane. `scripts/fetch_on_this_day.py`
/// builds the asset.
///
/// A day is keyed by its GREGORIAN month and day, because that is what the
/// source is keyed by. The Hijri date is shown beside it — that is the
/// conversion the owner asked for — but no event is claimed to fall on a
/// Hijri day it was not recorded against.
library;

import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HistoricalEvent {
  /// The year as Wikipedia records it; null when the source gives none.
  final int? year;
  final String text;

  const HistoricalEvent({required this.year, required this.text});
}

class OnThisDay {
  final Map<String, List<HistoricalEvent>> _byDay;

  /// The language the rows are actually IN — not the language that was
  /// asked for. The Gregorian feed exists in ar and en, so a French reader is
  /// served the English rows, and the Hijri set exists only in Arabic. A sheet
  /// that wants to say «these are in Arabic» has to be told, and a keyword
  /// match over the text has to know which language it is matching.
  final String lang;

  const OnThisDay(this._byDay, {this.lang = ''});

  static const empty = OnThisDay({});

  bool get isEmpty => _byDay.isEmpty;

  /// Events for a Gregorian date.
  List<HistoricalEvent> forDate(DateTime date) => forMonthDay(
        date.month,
        date.day,
      );

  /// Events for a month/day pair in whichever calendar this set is keyed by.
  List<HistoricalEvent> forMonthDay(int month, int day) {
    final key = '${month.toString().padLeft(2, '0')}-'
        '${day.toString().padLeft(2, '0')}';
    return _byDay[key] ?? const [];
  }
}

/// The dataset for the reader's language, falling back to English and then to
/// nothing. Nothing is a fine answer: the card still shows both dates.
final onThisDayProvider =
    FutureProvider.family<OnThisDay, String>((ref, locale) async {
  for (final lang in {locale, 'en'}) {
    try {
      final raw = await rootBundle.load('assets/data/on_this_day_$lang.json');
      var bytes = raw.buffer.asUint8List(raw.offsetInBytes, raw.lengthInBytes);
      // Stored gzipped with no Content-Encoding, exactly like the books —
      // sniffed by its magic bytes rather than trusted from the name.
      if (bytes.length > 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
        bytes = Uint8List.fromList(gzip.decode(bytes));
      }
      final doc = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final days = (doc['days'] as Map<String, dynamic>?) ?? const {};
      return OnThisDay({
        for (final e in days.entries)
          e.key: [
            for (final r in (e.value as List<dynamic>))
              HistoricalEvent(
                year: (r as Map<String, dynamic>)['y'] as int?,
                text: (r['t'] as String?) ?? '',
              ),
          ],
      }, lang: lang);
    } catch (_) {
      // Try the fallback language, then give up quietly.
    }
  }
  return OnThisDay.empty;
});

/// «في مثل هذا اليوم الهجري» — the same idea, keyed by the HIJRI month and day.
///
/// Built by `scripts/fetch_on_this_day_hijri.py` from Arabic Wikipedia's own
/// per-Hijri-day pages, whose «أحداث» sections are dated by Hijri year. The
/// Gregorian feed could never answer for «١٧ رمضان», because it is keyed by a
/// different calendar entirely — which is why the two dates on the Home header
/// now open two different sheets instead of one.
///
/// Arabic only, and not by choice: English Wikipedia has no Hijri day pages at
/// all (`17_Ramadan` → 404). The sheet says so in the reader's language rather
/// than passing Arabic prose off as a localised list.
final onThisDayHijriProvider = FutureProvider<OnThisDay>((ref) async {
  try {
    final raw = await rootBundle.load('assets/data/on_this_day_hijri_ar.json');
    var bytes = raw.buffer.asUint8List(raw.offsetInBytes, raw.lengthInBytes);
    if (bytes.length > 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
      bytes = Uint8List.fromList(gzip.decode(bytes));
    }
    final doc = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    final days = (doc['days'] as Map<String, dynamic>?) ?? const {};
    return OnThisDay({
      for (final e in days.entries)
        e.key: [
          for (final r in (e.value as List<dynamic>))
            HistoricalEvent(
              year: (r as Map<String, dynamic>)['y'] as int?,
              text: (r['t'] as String?) ?? '',
            ),
        ],
    }, lang: 'ar');
  } catch (_) {
    return OnThisDay.empty;
  }
});
