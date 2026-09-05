import '../../../core/models/adhan_mode.dart';
import '../../../core/models/adhan_option.dart';
import '../../../core/models/prayer_times.dart';
import '../../../core/services/adhan_alarm_service.dart';
import '../../../core/services/adhan_uri_bridge.dart';
import '../../../core/services/prayer_times_service.dart';
import 'adhan_settings_provider.dart';

const _prayerLabelsAr = {
  'fajr': 'الفجر',
  'dhuhr': 'الظهر',
  'asr': 'العصر',
  'maghrib': 'المغرب',
  'isha': 'العشاء',
};

/// Deliberately takes plain [AdhanSettings]/catalog values rather than a
/// Riverpod `Ref` — `WidgetRef` (consumer widgets) and `Ref` (notifiers)
/// aren't interchangeable, and every call site already has both values on
/// hand, so a pure function is simpler than reconciling the two ref types.
AdhanOption _resolveOption(
  List<AdhanOption> catalog,
  AdhanSettings settings,
  String prayerKey,
) {
  final id = settings.adhanIdFor(prayerKey);
  final match = catalog.where((o) => o.id == id);
  return match.isNotEmpty ? match.first : catalog.first;
}

Future<(String?, String?)> _resolveSound(AdhanMode mode, AdhanOption option) async {
  if (mode != AdhanMode.full && mode != AdhanMode.audio) return (null, null);
  if (option.isCustom) {
    return (null, await AdhanUriBridge.contentUriForFile(option.filePath!));
  }
  return (option.rawResource, null);
}

/// (Re)schedules the daily exact alarm for every one of the 5 prayers from
/// real, freshly-fetched [times], resolving each prayer's mode + chosen
/// adhan from the persisted [settings]/[catalog]. Called after every
/// successful prayer times fetch, and again whenever the Adhan settings
/// screen changes anything — both real triggers, never a timer-based guess.
Future<void> rescheduleAdhans(
  PrayerTimes times,
  AdhanSettings settings,
  List<AdhanOption> catalog, {
  String? adhanVideoPath,
}) async {
  if (times.isEmpty || catalog.isEmpty) return;

  for (final key in adhanPrayerKeys) {
    final parsed = PrayerTimesService.parseHM(times.byName(key));
    if (parsed == null) continue;
    final (hour, minute) = parsed;

    final mode = settings.modeFor(key);
    final option = _resolveOption(catalog, settings, key);
    final (rawResource, customUri) = await _resolveSound(mode, option);

    try {
      await AdhanAlarmService.instance.scheduleDaily(
        prayerKey: key,
        hour: hour,
        minute: minute,
        mode: mode,
        rawResource: rawResource,
        customUri: customUri,
        title: 'الصلاة — ${_prayerLabelsAr[key]}',
        payload: buildAdhanPayload(
          prayerKey: key,
          prayerLabel: _prayerLabelsAr[key]!,
          notificationId: AdhanAlarmService.instance.idFor(key),
          previewAssetPath: option.assetPath,
          videoPath: adhanVideoPath,
        ),
      );
    } catch (_) {
      // P3‑45: real-device testing found `flutter_local_notifications`
      // throwing ("Missing type parameter") from its own persisted
      // scheduled-notification storage on some devices/emulators with
      // notification history from earlier plugin versions — this call is
      // inside `PrayerController._load()`, awaited with no guard of its
      // own, so it was taking the *entire* Home prayer-times card down
      // with it (real times hidden behind "something went wrong") even
      // though the times themselves fetched fine and had nothing to do
      // with alarm scheduling. One prayer's alarm failing to arm is a
      // real problem worth fixing at its root (a plugin-version issue,
      // tracked separately), but it must never hide working prayer times
      // — same "optional, app is fine without it" rule already applied to
      // `PrayerStatusNotification`.
    }
  }
}

/// Fires one prayer's Adhan a few seconds from now, exactly as scheduled —
/// a real QA tool so the whole pipeline (channel, sound, full-screen intent,
/// Stop/Mute) can be verified without waiting for an actual prayer time.
Future<void> fireAdhanTest({
  required String prayerKey,
  required AdhanMode mode,
  required AdhanSettings settings,
  required List<AdhanOption> catalog,
  Duration from = const Duration(seconds: 8),
  String? adhanVideoPath,
}) async {
  if (catalog.isEmpty) return;

  final option = _resolveOption(catalog, settings, prayerKey);
  final (rawResource, customUri) = await _resolveSound(mode, option);

  await AdhanAlarmService.instance.scheduleTest(
    prayerKey: prayerKey,
    from: from,
    mode: mode,
    rawResource: rawResource,
    customUri: customUri,
    title: 'الصلاة — ${_prayerLabelsAr[prayerKey]} (تجربة)',
    payload: buildAdhanPayload(
      prayerKey: prayerKey,
      prayerLabel: _prayerLabelsAr[prayerKey]!,
      notificationId: AdhanAlarmService.instance.testIdFor(prayerKey),
      previewAssetPath: option.assetPath,
      videoPath: adhanVideoPath,
    ),
  );
}
