import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/ayah_audio_service.dart';
import '../../quran/data/mushaf_data_provider.dart';
import 'reciters_provider.dart';

/// Where a recitation is played from.
///
/// «وأنا أختار أشغّل من التلاوة المحملة ولا من الـ API عشان أقدر أستخدم
/// التطبيق مباشر مش أقعد لحد ما يحمّل التلاوة الأول».
///
/// The app used to decide this by itself — downloaded if present, network
/// otherwise — which is the right default and a bad rule to be stuck with.
/// A half-downloaded reciter would play its cached verses and stall on the
/// gaps; and someone who wants to hear a reciter *now* had no way to say so.
enum PlaybackSource {
  /// Downloaded when it is there, network when it is not. The old behaviour,
  /// and still the default.
  auto,

  /// Always the network, even when a copy is on disk — the answer to "let me
  /// listen while it downloads".
  stream,

  /// Only what is on disk. Nothing is fetched; a missing verse is silent
  /// rather than a surprise on a metered connection.
  downloaded,
}

const _kSourceKey = 'recitation.playback_source_v1';

class PlaybackSourceNotifier extends StateNotifier<PlaybackSource> {
  PlaybackSourceNotifier() : super(PlaybackSource.auto) {
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kSourceKey);
    final match = PlaybackSource.values.where((v) => v.name == saved);
    if (match.isNotEmpty) state = match.first;
  }

  Future<void> set(PlaybackSource value) async {
    if (value == state) return;
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSourceKey, value.name);
    // The service reads this synchronously while building audio sources, so
    // it is mirrored there rather than looked up through a container it does
    // not have.
    AyahAudioService.instance.playbackPrefersNetwork =
        value == PlaybackSource.stream;
    AyahAudioService.instance.playbackOfflineOnly =
        value == PlaybackSource.downloaded;
  }
}

final playbackSourceProvider =
    StateNotifierProvider<PlaybackSourceNotifier, PlaybackSource>(
  (ref) => PlaybackSourceNotifier(),
);

/// One downloaded reciter, and how much of him is actually on the device.
class DownloadedReciter {
  final String edition;
  final String nameAr;
  final String nameEn;

  /// Surahs whose every ayah is on disk.
  final int completeSurahs;
  final int totalSurahs;

  const DownloadedReciter({
    required this.edition,
    required this.nameAr,
    required this.nameEn,
    required this.completeSurahs,
    required this.totalSurahs,
  });

  bool get isWhole => totalSurahs > 0 && completeSurahs >= totalSurahs;
}

/// Every reciter with files on the device, with how complete each one is.
///
/// «ولو أكتر من قارئ يقوللي فلان وفلان ويحطهم في قايمة». The storage screen
/// could already say how many megabytes recitations occupy; it could not say
/// **whose** they were, or how much of each was actually usable.
///
/// Counted from the files themselves rather than from a record of what was
/// asked for — a download that was interrupted is exactly the case worth
/// seeing, and only the disk knows about it.
final downloadedRecitersProvider =
    FutureProvider<List<DownloadedReciter>>((ref) async {
  final all = await ref.watch(recitersProvider.future);
  final data = await ref.watch(mushafDataProvider.future);
  final editions = await AyahAudioService.instance.editionsWithFiles();

  final out = <DownloadedReciter>[];
  for (final edition in editions) {
    var complete = 0;
    for (final s in data.surahs) {
      final p = await AyahAudioService.instance.surahProgress(
        s.id,
        s.ayahsCount,
        data.repo,
        edition: edition,
      );
      if (p.isComplete) complete++;
    }
    if (complete == 0) continue;
    final match = all.where((r) => r.identifier == edition);
    out.add(DownloadedReciter(
      edition: edition,
      nameAr: match.isEmpty ? edition : match.first.nameAr,
      nameEn: match.isEmpty ? edition : match.first.nameEn,
      completeSurahs: complete,
      totalSurahs: data.surahs.length,
    ));
  }
  // Whole recitations first, then by how much is there.
  out.sort((a, b) => b.completeSurahs.compareTo(a.completeSurahs));
  return out;
});
