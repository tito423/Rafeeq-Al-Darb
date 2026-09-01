import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/models.dart';
import '../../../core/db/quran_repository.dart';

/// Everything the mushaf browser needs, resolved once from the bundled DB.
class MushafData {
  final List<Surah> surahs;
  final Map<int, int> surahStartPages;
  final Map<int, int> juzStartPages;
  final QuranRepository repo;

  const MushafData({
    required this.surahs,
    required this.surahStartPages,
    required this.juzStartPages,
    required this.repo,
  });

  String surahNameAr(int id) =>
      surahs.takeWhile((s) => s.id <= id).lastWhere(
            (s) => s.id == id,
            orElse: () => const Surah(
              id: 0,
              nameAr: '',
              nameEn: '',
              revelationType: '',
              ayahsCount: 0,
            ),
          ).nameAr;
}

final mushafDataProvider = FutureProvider<MushafData>((ref) async {
  final repo = await ref.watch(quranRepositoryProvider.future);
  final results = await Future.wait([
    repo.surahs(),
    repo.surahStartPages(),
    repo.juzStartPages(),
  ]);
  return MushafData(
    surahs: results[0] as List<Surah>,
    surahStartPages: results[1] as Map<int, int>,
    juzStartPages: results[2] as Map<int, int>,
    repo: repo,
  );
});