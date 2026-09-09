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

  /// The reciter's name as it should read in [locale].
  ///
  /// A person's name is **transliterated, not translated**, so there are only
  /// two forms and the choice is by script, not by language: Arabic script for
  /// the Arabic-script locales (ar and ur — Urdu writes these names with the
  /// same letters), and the catalogue's Latin transliteration for the rest.
  /// That transliteration is the form Spanish, French, Portuguese and Russian
  /// sources use for these names too, so nothing here is invented.
  ///
  /// P3‑57: before this, every locale saw `nameAr`, so a fresh English or
  /// Spanish install listed the reciters in Arabic script — the owner's «اول
  /// مرة بعد تسطيب التطبيق ترجم … اسم قارئ التلاوة للغة التطبيق المختارة».
  static const arabicScriptLocales = {'ar', 'ur'};

  String displayName(String locale) {
    if (arabicScriptLocales.contains(locale)) {
      return nameAr.isEmpty ? nameEn : nameAr;
    }
    return nameEn.isEmpty ? nameAr : nameEn;
  }
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
  // Sorted by the Latin form: it is the only field every entry really has,
  // and an Arabic-script sort of a list rendered in Latin looked arbitrary.
  out.sort((a, b) => a.nameEn.compareTo(b.nameEn));
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
