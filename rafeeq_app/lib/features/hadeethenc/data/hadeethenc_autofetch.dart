import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/download_manager.dart';
import 'hadeethenc_providers.dart';

/// Fetches the Hadeeth Encyclopaedia pack once, by itself, after the app has
/// been opened.
///
/// «حمّل الموسوعة الحديثية دي جوّه التطبيق أوتوماتيك بعد أول مرة تشغيل للتطبيق».
///
/// It is a 2.4 MB download and it is what makes the Home card able to show an
/// explained hadith at all, so asking the reader to go and find it in the
/// Library was the wrong default. Three things keep that from being rude:
///
///  * **Once.** A flag per language records that the offer was made, so
///    declining is permanent and a deleted pack is not silently re-fetched.
///  * **It can be turned off** before it ever runs — see [setEnabled]. Someone
///    short of storage keeps the card, without an explanation, which is what
///    he asked for: «لو مش أختار تحميلهم … يظهرله الكارت من غير شرح».
///  * **It never runs while the pack is already there**, and it does nothing
///    at all if the download manager already has the job.
class HadeethEncAutoFetch {
  HadeethEncAutoFetch._();

  static const _enabledKey = 'hadeethenc_autofetch_v1';
  static const _doneKeyPrefix = 'hadeethenc_autofetch_done_v1_';

  /// Whether the app may fetch the pack on its own. Defaults to true — the
  /// pack is small and the feature is useless without it.
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? true;
  }

  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }

  /// Runs the one-time fetch for the app's current language.
  ///
  /// Safe to call on every launch: everything that would make it a bad idea
  /// is checked here rather than at the call site.
  static Future<void> maybeFetch(WidgetRef ref) async {
    try {
      if (!await isEnabled()) return;

      final pack = ref.read(hadeethEncPackProvider).valueOrNull;
      if (pack == null) return;

      final prefs = await SharedPreferences.getInstance();
      final doneKey = '$_doneKeyPrefix${pack.lang}';
      if (prefs.getBool(doneKey) ?? false) return;

      // Already on the device — mark it and leave.
      final repo = await ref.read(hadeethEncRepositoryProvider.future);
      if (repo != null) {
        await prefs.setBool(doneKey, true);
        return;
      }

      await prefs.setBool(doneKey, true);
      await DownloadManager.instance.enqueue(
        id: pack.downloadId,
        url: pack.url,
        category: 'hadeethenc',
        // Not '<lang>.zip' — see `HadeethEncPack.zipFileName` and trap #27.
        fileName: pack.zipFileName,
        unzipToDatabases: true,
        dbVersion: AppConfig.hadeethEncVersion,
        title: pack.name,
      );
    } catch (_) {
      // A background convenience must never be able to break a launch.
    }
  }
}
