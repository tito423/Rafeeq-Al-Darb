import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';

/// Pushes the strings **Android itself** renders into native storage, in the
/// language the user picked inside the app.
///
/// `i18n_audit.py` reads Dart only, so nothing here was ever on its list — and
/// every one of these was hardcoded Arabic in Kotlin. On a French UI the adhan
/// alert read «أذان الظهر / الله أكبر، حان وقت الصلاة» with «إيقاف» and «كتم»
/// buttons, the three adhan channels showed Arabic names in the system's own
/// notification settings, and the download service's notification was Arabic
/// too.
///
/// Android's own `values-<lang>/` resources cannot do this: they follow the
/// *device* locale, and this app's language is its own setting. So Dart is the
/// source of truth and Kotlin reads what Dart last wrote — see
/// `NativeStrings.kt`, which also holds the Arabic fallbacks for the window
/// before Dart has ever run.
///
/// Called from `main()` after localization is ready, and from every place that
/// calls `setLocale`.
class NativeStrings {
  static const _channel =
      MethodChannel('com.tito.rafeeq_aldarb/native_strings');

  /// The `%s` in `adhan_title` is the prayer's own name: `prayer.azan_of` is
  /// «أذان صلاة {}» in Arabic and "Adhan — {} prayer" in English, and the
  /// placeholder has to survive into Kotlin so each language keeps its own
  /// word order instead of having the name stapled to the front.
  static Map<String, String> current() => {
        'adhan_channel': 'prayer.adhan'.tr(),
        'adhan_channel_desc': 'notif.adhan_channel_desc'.tr(),
        'adhan_channel_vibrate':
            '${'prayer.adhan'.tr()} — ${'prayer.mode_vibrate'.tr()}',
        'adhan_channel_vibrate_desc': 'notif.adhan_channel_vibrate_desc'.tr(),
        'adhan_channel_silent':
            '${'prayer.adhan'.tr()} — ${'prayer.mode_silent'.tr()}',
        'adhan_channel_silent_desc': 'notif.adhan_channel_silent_desc'.tr(),
        'adhan_title': 'prayer.azan_of'.tr(args: const ['%s']),
        'adhan_body': 'notif.adhan_body'.tr(),
        'adhan_body_muted': 'notif.adhan_body_muted'.tr(),
        'adhan_stop': 'prayer.stop'.tr(),
        'adhan_mute': 'prayer.mute'.tr(),
        'dl_channel': 'notif.dl_service_channel'.tr(),
        'dl_channel_desc': 'notif.dl_service_channel_desc'.tr(),
        'dl_title': 'notif.dl_files_running_title'.tr(),
        'dl_body': 'notif.dl_service_body'.tr(),
        'prayer_channel': 'notif.prayer_channel'.tr(),
        'prayer_channel_desc': 'notif.prayer_channel_desc'.tr(),
      };

  /// Best-effort: a phone with no method channel attached (the Adhan alert's
  /// own engine, a unit test) must not take the app down over a notification
  /// label.
  static Future<void> sync() async {
    try {
      await _channel.invokeMethod<bool>('sync', current());
    } catch (_) {
      // Nothing to recover: Kotlin keeps whatever it last stored.
    }
  }
}
