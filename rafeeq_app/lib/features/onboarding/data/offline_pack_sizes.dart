import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Measured sizes for the «التحميلات المبدئية» page. Nothing here is typed by
/// hand: `scripts/measure_recitation_sizes.py` sums every reciter's 6,236
/// ayah files from everyayah's own listing, and
/// `scripts/measure_offline_pack_sizes.py` sums the bucket's folders.
class OfflinePackSizes {
  /// alquran.cloud edition id -> bytes of its 6,236 per-ayah files.
  final Map<String, int> ayahReciters;

  /// The paper mushaf (madinah_qc, 604 pages) on the bucket.
  final int mushaf;

  /// mp3quran moshaf id -> bytes of its 114 surahs on the bucket.
  final Map<int, int> surahRecitations;

  const OfflinePackSizes({
    required this.ayahReciters,
    required this.mushaf,
    required this.surahRecitations,
  });

  /// Bucket slug of each whole recitation mirrored there
  /// (`Mp3Moshaf.r2Mirrors`), keyed the way the sizes file names them.
  static const _surahSlugs = {
    53: 'recitations/surah/basit_murattal',
    102: 'recitations/surah/maher_murattal',
  };

  static Future<OfflinePackSizes> load() async {
    Map<String, dynamic> bytesOf(String raw) =>
        (jsonDecode(raw) as Map<String, dynamic>)['bytes']
            as Map<String, dynamic>;
    final ayah = bytesOf(await rootBundle
        .loadString('assets/data/catalogs/ayah_recitation_sizes.json'));
    final packs = bytesOf(await rootBundle
        .loadString('assets/data/catalogs/offline_pack_sizes.json'));
    return OfflinePackSizes(
      ayahReciters: {
        for (final e in ayah.entries) e.key: (e.value as num).toInt(),
      },
      mushaf: (packs['mushaf/madinah_qc'] as num).toInt(),
      surahRecitations: {
        for (final e in _surahSlugs.entries)
          if (packs[e.value] != null) e.key: (packs[e.value] as num).toInt(),
      },
    );
  }
}

final offlinePackSizesProvider =
    FutureProvider<OfflinePackSizes>((ref) => OfflinePackSizes.load());

/// The reciter chosen on the page for the per-ayah download (null until the
/// recommendation is known), and the whole recitation chosen (moshaf id).
final onboardingAyahChoiceProvider = StateProvider<String?>((ref) => null);
final onboardingSurahChoiceProvider = StateProvider<int?>((ref) => null);
