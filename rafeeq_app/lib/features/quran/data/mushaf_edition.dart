import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';

/// One printed mushaf the reader can choose.
///
/// Every edition ships its own ayah polygons, so tapping and highlighting work
/// the same in all of them. What differs is verse numbering: the bundled
/// sciences database (tafsir, i'rab, translations) is keyed to Hafs, which
/// Shu'bah matches exactly, while Warsh, Qalun and Duri split verses
/// differently in many surahs. [sciencesAvailableFor] is what keeps the app
/// from confidently showing the wrong commentary in those surahs.
class MushafEdition {
  final String id;

  /// Upstream folder, e.g. 'hafs/kfqc'.
  final String sourcePath;

  final String nameAr;
  final String nameEn;
  final String riwayahAr;
  final String riwayahEn;
  final String polygonsAsset;
  final int pages;
  final int ayahs;

  /// True when this edition's verse numbering matches the sciences database
  /// for the whole mushaf.
  final bool sciencesAligned;

  /// Surahs whose numbering differs from the sciences database.
  final Set<int> divergingSurahs;

  final bool isDefault;

  const MushafEdition({
    required this.id,
    required this.sourcePath,
    required this.nameAr,
    required this.nameEn,
    required this.riwayahAr,
    required this.riwayahEn,
    required this.polygonsAsset,
    required this.pages,
    required this.ayahs,
    required this.sciencesAligned,
    required this.divergingSurahs,
    required this.isDefault,
  });

  factory MushafEdition.fromJson(Map<String, dynamic> j) => MushafEdition(
        id: j['id'] as String,
        sourcePath: j['source_path'] as String,
        nameAr: j['name_ar'] as String,
        nameEn: j['name_en'] as String,
        riwayahAr: j['riwayah_ar'] as String? ?? '',
        riwayahEn: j['riwayah_en'] as String? ?? '',
        polygonsAsset: j['polygons_asset'] as String,
        pages: j['pages'] as int,
        ayahs: j['ayahs'] as int,
        sciencesAligned: j['sciences_aligned'] as bool? ?? false,
        divergingSurahs: {
          for (final s in (j['diverging_surahs'] as List<dynamic>? ?? const []))
            s as int
        },
        isDefault: j['is_default'] as bool? ?? false,
      );

  /// Whether tafsir / translation / i'rab can be trusted for this surah.
  bool sciencesAvailableFor(int surah) =>
      sciencesAligned || !divergingSurahs.contains(surah);

  String pageUrl(int page) => AppConfig.mushafPageUrl(sourcePath, page);
}

/// The editions bundled with the app, newest catalog wins.
final mushafEditionsProvider =
    FutureProvider<List<MushafEdition>>((ref) async {
  final raw = await rootBundle.loadString('assets/data/mushaf/editions.json');
  final doc = jsonDecode(raw) as Map<String, dynamic>;
  return [
    for (final e in doc['editions'] as List<dynamic>)
      MushafEdition.fromJson(e as Map<String, dynamic>)
  ];
});

const _kSelectedEditionKey = 'mushaf.selected_edition';

/// The edition currently being read, persisted across launches.
class SelectedMushafEdition extends StateNotifier<String> {
  SelectedMushafEdition() : super(AppConfig.defaultMushafEdition) {
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kSelectedEditionKey);
    if (saved != null && saved.isNotEmpty) state = saved;
  }

  Future<void> select(String editionId) async {
    if (editionId == state) return;
    state = editionId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSelectedEditionKey, editionId);
  }
}

final selectedMushafEditionProvider =
    StateNotifierProvider<SelectedMushafEdition, String>(
        (ref) => SelectedMushafEdition());

/// The resolved edition object, falling back to the default if the stored id
/// no longer exists (an edition can disappear between app versions).
final currentMushafEditionProvider =
    FutureProvider<MushafEdition>((ref) async {
  final editions = await ref.watch(mushafEditionsProvider.future);
  final id = ref.watch(selectedMushafEditionProvider);
  return editions.firstWhere(
    (e) => e.id == id,
    orElse: () => editions.firstWhere(
      (e) => e.isDefault,
      orElse: () => editions.first,
    ),
  );
});
