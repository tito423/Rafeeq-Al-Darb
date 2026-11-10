import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/digits.dart';

/// The mark «۞» as the mushaf text stores it.
const rubElHizbMark = '۞';

/// Which of the 240 quarter-hizb divisions an ayah opens.
///
/// Owner, 2026-11-06: a tap on «۞» should say which quarter it is - a
/// quarter, a half, three quarters of a hizb, a hizb or a juz.
class RubInfo {
  /// 1..240.
  final int number;
  const RubInfo(this.number);

  /// 1..60.
  int get hizb => (number - 1) ~/ 4 + 1;

  /// 1..30.
  int get juz => (hizb - 1) ~/ 2 + 1;

  /// 0 = the hizb opens here, 1 = a quarter of it is done, 2 = half, 3 =
  /// three quarters.
  int get part => (number - 1) % 4;

  /// True where a juz opens (every second hizb).
  bool get opensJuz => part == 0 && hizb.isOdd;

  /// «ربع الحزب ٣», «نصف الحزب ٣», «ثلاثة أرباع الحزب ٣», «الحزب ٣».
  String get title => trn(
    const [
      'quran.rub_hizb_start',
      'quran.rub_quarter',
      'quran.rub_half',
      'quran.rub_three_quarters',
    ][part],
    args: ['$hizb'],
  );

  /// What the printed Madinah mushaf sets in the margin beside the mark,
  /// line by line (read off the 1428 AH printing, pages 5, 7, 9 and 22):
  /// «ربع / الحزب / ١», «نصف / الحزب / ١», «ثلاثة أرباع / الحزب / ١», and
  /// where a juz opens «الجزء ٢ / الحزب ٣».
  List<String> get marginLines {
    final h = localizeDigits('$hizb', uiLanguageCode);
    final hizbWord = 'quran.rub_m_hizb'.tr();
    if (opensJuz) {
      final j = localizeDigits('$juz', uiLanguageCode);
      return ['${'quran.rub_m_juz'.tr()} $j', '$hizbWord $h'];
    }
    return [
      if (part > 0)
        const [
          'quran.rub_m_quarter',
          'quran.rub_m_half',
          'quran.rub_m_three_quarters',
        ][part - 1].tr(),
      hizbWord,
      h,
    ];
  }

  /// «الجزء ٢ · الربع ١٠ من ٢٤٠».
  String get subtitle =>
      '${trn(opensJuz ? 'quran.rub_juz_start' : 'quran.rub_juz', args: ['$juz'])}'
      ' · ${trn('quran.rub_of_all', args: ['$number'])}';
}

/// The quarter starts, from `assets/data/mushaf/rub_el_hizb_ayahs.json`
/// (`scripts/build_rub_el_hizb_ayahs.py`: api.quran.com's per-ayah quarter
/// number, checked against the 199 marks in the bundled text).
class RubElHizbIndex {
  final Map<int, int> _numberByAyah;
  final Set<int> _marked;
  const RubElHizbIndex._(this._numberByAyah, this._marked);

  static int _key(int surah, int ayah) => surah * 1000 + ayah;

  factory RubElHizbIndex.fromJson(String raw) {
    final numbers = <int, int>{};
    final marked = <int>{};
    final list = jsonDecode(raw) as List<dynamic>;
    for (var i = 0; i < list.length; i++) {
      final e = (list[i] as List<dynamic>).cast<int>();
      final key = _key(e[0], e[1]);
      numbers[key] = i + 1;
      if (e[2] == 1) marked.add(key);
    }
    return RubElHizbIndex._(numbers, marked);
  }

  int get length => _numberByAyah.length;

  /// The quarter that opens at this ayah, when the mushaf prints «۞» there.
  RubInfo? markAt(int surah, int ayah) {
    final key = _key(surah, ayah);
    if (!_marked.contains(key)) return null;
    return RubInfo(_numberByAyah[key]!);
  }
}

final rubElHizbIndexProvider = FutureProvider<RubElHizbIndex>((ref) async {
  final raw = await rootBundle.loadString(
    'assets/data/mushaf/rub_el_hizb_ayahs.json',
  );
  return RubElHizbIndex.fromJson(raw);
});
