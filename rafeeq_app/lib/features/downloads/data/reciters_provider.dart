import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/ayah_audio_service.dart';
import '../../../core/services/recitation_source.dart';
import '../../quran_audio/data/ayah_download_notice.dart';

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

/// Arabic ayah-by-ayah reciters from the bundled editions catalog — **only
/// the ones an ayah can actually be fetched for.**
///
/// The catalogue names 175 Arabic audio editions and the app listed all of
/// them. Measured on 2026-09-23, 157 of those answer **403** on the audio CDN
/// and exist on no other host the app knows, so choosing one produced silence
/// with no error anywhere — «التلاوة مش شغالة بعد ما اختار القارئ». A reciter
/// with no file is a catalogue entry with nothing behind it (§1.1), so the
/// list is now exactly `RecitationSource`'s verified mirrors, every folder of
/// which was range-checked at its first and last ayah.
final recitersProvider = FutureProvider<List<Reciter>>((ref) async {
  final raw =
      await rootBundle.loadString('assets/data/catalogs/audio_editions.json');
  final list = jsonDecode(raw) as List<dynamic>;
  final out = <Reciter>[];
  for (final e in list) {
    final m = e as Map<String, dynamic>;
    if (m['language'] != 'ar' || m['format'] != 'audio') continue;
    // An entry whose "name" is its own identifier has no name at all: the
    // upstream editions API returned the id in every field. One of the 176
    // is like that, and it listed «ar.oimaoqataris» in the reciter picker as
    // though it were a shaykh - which is what the owner photographed, asking
    // «فيه اسم غريب مش اسم شيخ … إيه الحوار ده». §1.1: an entry the app
    // cannot honestly label is not an entry.
    final id = m['identifier'] as String;
    final nameAr = (m['name'] as String?) ?? '';
    final nameEn = (m['englishName'] as String?) ?? '';
    if (nameAr == id || nameEn == id) continue;
    // The one gate that matters: no verified source, no entry.
    if (!RecitationSource.hasVerifiedMirror(id)) continue;
    final r = Reciter(
      identifier: id,
      nameAr: nameAr,
      nameEn: nameEn,
    );
    out.add(r);
    // The per-ayah download notification names the reciter from here.
    AyahDownloadNotice.reciters[id] = r;
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
    if (saved == null || saved.isEmpty) return;
    // A phone that already chose one of the 157 reciters with no reachable
    // file has that choice on disk, and restoring it would keep that phone
    // silent for ever however the list is fixed. This is the half of the
    // 2026-09-23 fix that reaches an install that already has the problem.
    if (!RecitationSource.hasVerifiedMirror(saved)) {
      await prefs.setString(_kReciterKey, AyahAudioService.defaultEdition);
      return;
    }
    state = saved;
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
