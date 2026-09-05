import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/models.dart';
import '../../../core/db/quran_repository.dart';

/// Everything the mushaf browser needs, resolved once from the bundled DB.
class MushafData {
  final List<Surah> surahs;
  final Map<int, int> surahStartPages;
  final Map<int, int> juzStartPages;

  /// P3‑43 #9: real quarter-hizb (رُبع الحزب) start pages — index 0 is
  /// رُبع 1's own start page, index 239 is رُبع 240's. 240 real divisions
  /// (30 juz × 2 hizb × 4 quarters), fetched once from api.quran.com's
  /// real `rub_el_hizb_number` per-ayah metadata (the same trusted source
  /// this project already uses for tafsir/translations) — see
  /// `assets/data/mushaf/rub_el_hizb_pages.json`'s own generation script.
  /// This bundled DB has no hizb/quarter column of its own, unlike
  /// `juz_number`, so this couldn't be derived locally the way
  /// `juzStartPages` is.
  final List<int> rubElHizbPages;

  final QuranRepository repo;

  const MushafData({
    required this.surahs,
    required this.surahStartPages,
    required this.juzStartPages,
    required this.rubElHizbPages,
    required this.repo,
  });

  String surahNameAr(int id) => surahs
      .takeWhile((s) => s.id <= id)
      .lastWhere(
        (s) => s.id == id,
        orElse: () => const Surah(
          id: 0,
          nameAr: '',
          nameEn: '',
          revelationType: '',
          ayahsCount: 0,
        ),
      )
      .nameAr;
}

Future<List<int>> _loadRubElHizbPages() async {
  final raw = await rootBundle.loadString(
    'assets/data/mushaf/rub_el_hizb_pages.json',
  );
  return (jsonDecode(raw) as List<dynamic>).cast<int>();
}

final mushafDataProvider = FutureProvider<MushafData>((ref) async {
  final repo = await ref.watch(quranRepositoryProvider.future);
  final results = await Future.wait([
    repo.surahs(),
    repo.surahStartPages(),
    repo.juzStartPages(),
    _loadRubElHizbPages(),
  ]);
  return MushafData(
    surahs: results[0] as List<Surah>,
    surahStartPages: results[1] as Map<int, int>,
    juzStartPages: results[2] as Map<int, int>,
    rubElHizbPages: results[3] as List<int>,
    repo: repo,
  );
});
