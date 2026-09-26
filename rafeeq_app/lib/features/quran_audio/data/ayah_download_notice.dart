import 'package:easy_localization/easy_localization.dart';

import '../../../core/services/download_notifications.dart';
import '../../../core/utils/digits.dart';
import '../../downloads/data/reciters_provider.dart';
import 'ayah_recitation_library.dart';

/// The status-bar entry for per-ayah recitation downloads.
///
/// The owner, 2026-09-26, with a photo of the old one («جارٍ التنزيل / التقدم
/// الدقيق داخل التطبيق في «التنزيلات»»): «مش عاوزه بصراحة بالشكل ده
/// اخترعله حاجة احلى تظهر التقدم من غير ما تخنق التحميل». The plugin's own
/// notification could not show progress - it counts only the dozen tasks it
/// holds (`DownloadEngine.groupAyah`) - so this one is drawn from the
/// library's own count: the reciter's name, «ayahs of total», and a bar.
///
/// It costs the download nothing: it reads the library's in-memory set, is
/// driven by the library's already-throttled change notification, and
/// `DownloadNotifications.showProgress` posts at most about once a second.
/// A tap opens «تنزيل تلاوات آية بآية» (`dl:ayah`).
class AyahDownloadNotice {
  AyahDownloadNotice._();
  static final AyahDownloadNotice instance = AyahDownloadNotice._();

  /// The reciters by edition id, filled where the list is loaded
  /// (`recitersProvider`) - the library itself only knows ids.
  static final Map<String, Reciter> reciters = {};

  static const _id = 'ayah_recitations';
  static const _payload = 'dl:ayah';

  /// The editions shown in the last progress post, so the end of the run can
  /// say which reciter finished.
  Set<String> _shown = {};

  void refresh() {
    final lib = AyahRecitationLibrary.instance;
    final active = [
      for (final e in lib.entries)
        if (lib.isActive(e.edition)) e.edition,
    ];
    if (active.isEmpty) {
      if (_shown.isEmpty) return;
      final finished = [
        for (final e in _shown)
          if (lib.remainingCount(e) == 0) e,
      ];
      _shown = {};
      if (finished.isEmpty) {
        // Paused, deleted or failed: nothing to announce.
        DownloadNotifications.instance.clear(_id);
      } else {
        DownloadNotifications.instance.showComplete(
          id: _id,
          title: 'notif.dl_ayah_done_title'.tr(args: [_label(finished)]),
          payload: _payload,
        );
      }
      return;
    }
    var done = 0, total = 0;
    for (final e in active) {
      final have = lib.downloadedCount(e);
      done += have;
      total += have + lib.remainingCount(e);
    }
    _shown = active.toSet();
    final lang = uiLanguageCode;
    // Rounded like the bar (`showProgress`), so the two never disagree.
    final pct = total == 0 ? 0 : (done * 100 / total).round();
    DownloadNotifications.instance.ensureInitialized().then((_) {
      DownloadNotifications.instance.showProgress(
        id: _id,
        title: 'notif.dl_ayah_title'.tr(args: [_label(active)]),
        done: done,
        total: total,
        detail: localizeDigits(
          'notif.dl_ayah_body'.tr(args: ['$done', '$total', '$pct']),
          lang,
        ),
        payload: _payload,
      );
    });
  }

  /// One name, or «n reciters» when several run at once.
  String _label(List<String> editions) => editions.length == 1
      ? (reciters[editions.first]?.displayName(uiLanguageCode) ??
          'notif.dl_ayah_reciter'.tr())
      : 'notif.dl_ayah_reciters'.tr(
          args: [localizeDigits('${editions.length}', uiLanguageCode)]);
}
