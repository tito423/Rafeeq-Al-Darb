import 'package:easy_localization/easy_localization.dart';

import '../../../core/models/adhan_mode.dart';
import '../../../core/models/adhan_option.dart';
import '../../../core/models/prayer_times.dart';
import '../../../core/services/adhan_native.dart';
import '../../../core/services/prayer_times_service.dart';
import 'adhan_settings_provider.dart';

/// Deliberately takes plain [AdhanSettings]/catalog values rather than a
/// Riverpod `Ref` — `WidgetRef` (consumer widgets) and `Ref` (notifiers)
/// aren't interchangeable, and every call site already has both values on
/// hand, so a pure function is simpler than reconciling the two ref types.
AdhanOption _resolveOption(
  List<AdhanOption> catalog,
  AdhanSettings settings,
  String prayerKey,
) => resolveAdhanFor(catalog, settings, prayerKey);

/// The recording that sounds for [prayerKey].
///
/// «ممكن يضيف أي أذان مع الفجر اللي مختلف أصلاً في الصلاة خير من النوم».
/// It used to be whatever was chosen, so the default adhan — an ordinary one
/// — played at Fajr without its Fajr line while the screen printed it. Now:
///
/// * the choice is used when it fits the prayer (see [AdhanOption.fitsPrayer]);
/// * at Fajr an ordinary choice gives way to the same muezzin's Fajr adhan
///   ([AdhanOption.fajrPair]) and, failing that, the first Fajr recording;
/// * at the other four a Fajr choice gives way to the default, then to the
///   first ordinary recording.
AdhanOption resolveAdhanFor(
  List<AdhanOption> catalog,
  AdhanSettings settings,
  String prayerKey,
) {
  AdhanOption? byId(String? id) =>
      id == null ? null : catalog.where((o) => o.id == id).firstOrNull;
  final chosen = byId(settings.adhanIdFor(prayerKey)) ??
      byId(settings.defaultAdhanId);
  if (chosen != null && chosen.fitsPrayer(prayerKey)) return chosen;
  if (prayerKey == 'fajr') {
    final pair = byId(chosen?.fajrPair);
    if (pair != null) return pair;
  } else {
    final fallback = byId(settings.defaultAdhanId);
    if (fallback != null && fallback.fitsPrayer(prayerKey)) return fallback;
  }
  return catalog.where((o) => o.fitsPrayer(prayerKey)).firstOrNull ??
      chosen ??
      catalog.first;
}

AdhanSpec _specFor({
  required String prayerKey,
  required AdhanSettings settings,
  required List<AdhanOption> catalog,
  required int hour,
  required int minute,
}) {
  final mode = settings.modeFor(prayerKey);
  return AdhanNative.specFor(
    prayerKey: prayerKey,
    // Localised here because this label is what the *native* notification
    // prints; the Flutter alert screen resolves the name from `prayerKey`
    // at display time instead, so a language change before the alarm
    // fires cannot leave it stale.
    prayerLabel: 'prayer.$prayerKey'.tr(),
    mode: mode,
    option: _resolveOption(catalog, settings, prayerKey),
    // Only the full-screen mode ever shows a clip; carrying a video path for
    // the other modes would be a promise the alert never keeps.
    hour: hour,
    minute: minute,
  );
}

/// (Re)schedules the daily alarm for every one of the 5 prayers from real,
/// freshly-fetched [times], resolving each prayer's mode + chosen adhan from
/// the persisted [settings]/[catalog]. Called after every successful prayer
/// times fetch, and again whenever the Adhan settings screen changes
/// anything — both real triggers, never a timer-based guess.
///
/// The alarms themselves are armed natively (`AlarmManager.setAlarmClock`,
/// see `AdhanScheduler.kt`), which is what makes them survive Doze, an app
/// swipe-away and a reboot, and what earns the process the background
/// activity-start exemption the lock-screen alert depends on.
///
/// Returns false when the OS refused *exact* alarms and armed them
/// approximately instead — the settings screen turns that into the one
/// button that fixes it rather than silently drifting by minutes.
Future<bool> rescheduleAdhans(
  PrayerTimes times,
  AdhanSettings settings,
  List<AdhanOption> catalog,
) async {
  if (times.isEmpty || catalog.isEmpty) return true;

  final specs = <AdhanSpec>[];
  for (final key in adhanPrayerKeys) {
    final parsed = PrayerTimesService.parseHM(times.byName(key));
    if (parsed == null) continue;
    final (hour, minute) = parsed;
    specs.add(
      _specFor(
        prayerKey: key,
        settings: settings,
        catalog: catalog,
        hour: hour,
        minute: minute,
      ),
    );
  }
  if (specs.isEmpty) return true;
  return AdhanNative.scheduleDaily(specs);
}

/// Fires one prayer's Adhan a few seconds from now through the *identical*
/// alarm → receiver → foreground-service path a real prayer takes, so the
/// "تجربة" button proves the whole pipeline (exact alarm, lock-screen
/// takeover, Stop/Mute) rather than a lookalike of it.
Future<void> fireAdhanTest({
  required String prayerKey,
  required AdhanSettings settings,
  required List<AdhanOption> catalog,
  Duration from = const Duration(seconds: 8),
}) async {
  if (catalog.isEmpty) return;
  await AdhanNative.scheduleTest(
    _specFor(
      prayerKey: prayerKey,
      settings: settings,
      catalog: catalog,
      hour: 0,
      minute: 0,
    ),
    delay: from,
  );
}

/// The spec the settings screen's "معاينة الأذان" plays — the user's current
/// default sound and clip, always in full-screen mode, since a preview of a
/// silent mode would have nothing to show.
AdhanSpec previewSpec({
  required AdhanSettings settings,
  required List<AdhanOption> catalog,
  String prayerKey = 'dhuhr',
  required String prayerLabel,
}) {
  final option = resolveAdhanFor(catalog, settings, prayerKey);
  return AdhanNative.specFor(
    prayerKey: prayerKey,
    prayerLabel: prayerLabel,
    mode: AdhanMode.full,
    option: option,
  );
}
