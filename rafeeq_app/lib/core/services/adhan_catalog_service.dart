import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/adhan_option.dart';

/// The 10 bundled adhan recordings plus whatever the user has imported from
/// their own device. Custom entries are persisted as JSON in
/// SharedPreferences (their audio files live under the app's own documents
/// directory, copied there by [addCustom] so they survive the picker's
/// temporary file being cleaned up).
///
/// **On the muezzin names.** `assets/data/catalogs/adhans.json` now carries
/// the ten muezzin names the owner asked for, in his order, mapped onto the
/// ten bundled recordings in file order (`azan1.mp3` -> the first name, and
/// so on). Those recordings came from islamcan.com as an unattributed set:
/// no per-file record of *which* muezzin each one actually is has ever
/// existed in this project. Each entry's `source` field says so explicitly.
/// The names are therefore a labelling the owner supplied, not a verified
/// attribution — swapping in correctly-attributed MP3s later is a pure asset
/// change (drop the file into `assets/audio/adhan/` and
/// `android/app/src/main/res/raw/` under the same `azanN` name), with no
/// code or id change, because the ids stay `azan1`..`azan10` precisely so
/// existing users keep the adhan they already chose.
class AdhanCatalogService {
  AdhanCatalogService._();
  static final AdhanCatalogService instance = AdhanCatalogService._();

  static const _catalogAsset = 'assets/data/catalogs/adhans.json';
  static const _customPrefsKey = 'adhan_custom_v1';

  /// The hard ceiling on selectable adhans — bundled + custom (P2‑7). At 30
  /// the import is refused with a clear message rather than growing unbounded.
  static const maxTotalAdhans = 30;

  Future<List<AdhanOption>> loadAll() async {
    final bundled = await _loadBundled();
    final custom = await _loadCustom();
    return [...bundled, ...custom];
  }

  Future<List<AdhanOption>> _loadBundled() async {
    final raw = await rootBundle.loadString(_catalogAsset);
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => AdhanOption.bundled(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<AdhanOption>> _loadCustom() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_customPrefsKey) ?? const [];
    final options = <AdhanOption>[];
    for (final entry in raw) {
      try {
        final m = jsonDecode(entry) as Map<String, dynamic>;
        final path = m['filePath'] as String;
        // A custom file the user later deleted from storage — drop it
        // silently rather than offering a sound that can't actually play.
        if (!File(path).existsSync()) continue;
        options.add(AdhanOption.custom(
          id: m['id'] as String,
          name: m['name'] as String,
          filePath: path,
        ));
      } catch (_) {
        // corrupt entry — skip it
      }
    }
    return options;
  }

  /// Copies [sourcePath] (from the file picker's cache) into the app's own
  /// documents directory and registers it as a selectable adhan.
  Future<AdhanOption> addCustom(String sourcePath, String displayName) async {
    if ((await loadAll()).length >= maxTotalAdhans) {
      throw const AdhanLimitReached();
    }
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'custom_adhans'));
    if (!dir.existsSync()) await dir.create(recursive: true);

    final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final destPath = p.join(dir.path, '$id.mp3');
    await File(sourcePath).copy(destPath);

    final option = AdhanOption.custom(
      id: id,
      name: displayName,
      filePath: destPath,
    );

    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_customPrefsKey) ?? <String>[];
    existing.add(jsonEncode(option.toCustomJson()));
    await prefs.setStringList(_customPrefsKey, existing);

    return option;
  }

  Future<void> removeCustom(AdhanOption option) async {
    if (!option.isCustom) return;
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_customPrefsKey) ?? <String>[];
    existing.removeWhere((entry) {
      try {
        return (jsonDecode(entry) as Map<String, dynamic>)['id'] == option.id;
      } catch (_) {
        return false;
      }
    });
    await prefs.setStringList(_customPrefsKey, existing);
    final path = option.filePath;
    if (path != null && File(path).existsSync()) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
  }
}

/// Thrown by [AdhanCatalogService.addCustom] when the 30-adhan ceiling
/// ([AdhanCatalogService.maxTotalAdhans]) is already reached.
class AdhanLimitReached implements Exception {
  const AdhanLimitReached();
  @override
  String toString() => 'adhan limit reached';
}
