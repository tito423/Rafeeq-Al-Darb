import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/ayah_audio_service.dart';

/// A reciter whose recitation is available ayah by ayah.
class Reciter {
  /// Edition identifier used by the audio CDN, e.g. 'ar.alafasy'.
  final String identifier;
  final String nameAr;
  final String nameEn;

  const Reciter({
    required this.identifier,
    required this.nameAr,
    required this.nameEn,
  });
}

/// Arabic ayah-by-ayah reciters from the bundled editions catalog.
final recitersProvider = FutureProvider<List<Reciter>>((ref) async {
  final raw =
      await rootBundle.loadString('assets/data/catalogs/audio_editions.json');
  final list = jsonDecode(raw) as List<dynamic>;
  final out = <Reciter>[];
  for (final e in list) {
    final m = e as Map<String, dynamic>;
    if (m['language'] != 'ar' || m['format'] != 'audio') continue;
    out.add(Reciter(
      identifier: m['identifier'] as String,
      nameAr: (m['name'] as String?) ?? '',
      nameEn: (m['englishName'] as String?) ?? '',
    ));
  }
  out.sort((a, b) => a.nameAr.compareTo(b.nameAr));
  return out;
});

const _kReciterKey = 'recitation.selected_edition';

class SelectedReciter extends StateNotifier<String> {
  SelectedReciter() : super(AyahAudioService.defaultEdition) {
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kReciterKey);
    if (saved != null && saved.isNotEmpty) state = saved;
  }

  Future<void> select(String identifier) async {
    if (identifier == state) return;
    state = identifier;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kReciterKey, identifier);
  }
}

final selectedReciterProvider =
    StateNotifierProvider<SelectedReciter, String>((ref) => SelectedReciter());
