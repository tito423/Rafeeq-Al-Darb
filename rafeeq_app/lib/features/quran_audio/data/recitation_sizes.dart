import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The download size of a whole recitation, as measured on the servers
/// (owner, 2026-10-02: «حط تحت التلاوات … مساحة كل قارئ»). Nothing here is
/// estimated: both files are written by scripts that read the servers -
///  * ayah by ayah: `ayah_recitation_sizes.json`, everyayah's folder listings,
///    the sum of the 6,236 files, keyed by edition id;
///  * whole surahs: `full_recitation_sizes.json`
///    (scripts/measure_full_recitation_sizes.py), one range request per surah
///    file on mp3quran, summed over the surahs the moshaf has, keyed by the
///    moshaf's server folder.
/// A recitation with no measured size shows none.
class RecitationSizes {
  final Map<String, int> ayahByEdition;
  final Map<String, int> surahByServer;
  const RecitationSizes(this.ayahByEdition, this.surahByServer);

  static Future<RecitationSizes> load() async {
    // each file on its own: one that is missing or unreadable costs only
    // its own sizes, never the other list's
    Future<Map<String, int>> read(String name) async {
      try {
        final j = jsonDecode(await rootBundle.loadString('assets/data/catalogs/$name'))
            as Map<String, dynamic>;
        return {
          for (final e in (j['bytes'] as Map<String, dynamic>).entries)
            e.key: (e.value as num).toInt(),
        };
      } catch (_) {
        return const {};
      }
    }

    return RecitationSizes(
      await read('ayah_recitation_sizes.json'),
      await read('full_recitation_sizes.json'),
    );
  }
}

final recitationSizesProvider =
    FutureProvider<RecitationSizes>((ref) => RecitationSizes.load());
