import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../core/models/adhan_mode.dart';
import '../../../../core/models/adhan_option.dart';
import '../../../../core/services/alarm_permissions_service.dart';
import '../../../../core/services/adhan_catalog_service.dart';
import '../../../../core/services/adhan_native.dart';
import '../../../../core/services/adhan_uri_bridge.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/error_retry.dart';
import '../../../home/data/prayer_controller.dart';
import '../../data/adhan_catalog_provider.dart';
import '../../data/adhan_scheduler.dart';
import '../../data/adhan_settings_provider.dart';
import '../widgets/adhan_backgrounds_card.dart';
import '../widgets/adhan_preview_card.dart';
import '../widgets/alarm_volume_tile.dart';
import '../../data/prayer_status_enabled_provider.dart';
import 'azan_player_screen.dart';

const _prayerLabels = {
  'fajr': 'prayer.fajr',
  'dhuhr': 'prayer.dhuhr',
  'asr': 'prayer.asr',
  'maghrib': 'prayer.maghrib',
  'isha': 'prayer.isha',
};

/// Adhan settings — sound picker with real preview, custom import from
/// device, and per-prayer notification mode + sound override. Every value
/// shown here is either a bundled asset, a file the user actually picked, or
/// a persisted choice — nothing invented.
class AdhanSettingsScreen extends ConsumerStatefulWidget {
  const AdhanSettingsScreen({super.key});

  @override
  ConsumerState<AdhanSettingsScreen> createState() => _AdhanSettingsScreenState();
}

class _AdhanSettingsScreenState extends ConsumerState<AdhanSettingsScreen>
    with WidgetsBindingObserver {
  /// The adhan currently sounding from the list rows, if any. There is no
  /// Dart audio player here any more: previews go through the same native
  /// [AdhanNative] player a real alarm uses (see its doc for why), so this
  /// is just which row's button should read "stop".
  /// Which row is sounding. A `ValueNotifier` rather than a field with
  /// `setState`, because the picker lives in a **pushed route**: calling
  /// `setState` here rebuilds this screen, not the page on top of it, so
  /// the play/stop button on every row stayed frozen at whatever it was
  /// when the page was opened.
  final ValueNotifier<String?> _playingId = ValueNotifier<String?>(null);
  Timer? _previewWatch;

  bool? _batteryExempt;
  bool? _fullScreenIntentOk;
  bool? _exactAlarmOk;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AlarmPermissionsService.instance.isBatteryOptimizationExempt().then((v) {
      if (mounted) setState(() => _batteryExempt = v);
    });
    _checkFullScreenIntent();
    _checkExactAlarm();
  }

  Future<void> _checkFullScreenIntent() async {
    final v = await AdhanUriBridge.canUseFullScreenIntent();
    if (mounted) setState(() => _fullScreenIntentOk = v);
  }

  /// The Adhan is armed with `AlarmManager.setAlarmClock`, which needs the
  /// exact-alarm grant. Without it the alarms still arm, but only
  /// approximately — and the lock-screen takeover loses the OS exemption it
  /// depends on, so this is worth showing the user rather than degrading
  /// quietly.
  Future<void> _checkExactAlarm() async {
    final v = await AdhanNative.canScheduleExact();
    if (mounted) setState(() => _exactAlarmOk = v);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user grants the P3‑19 full-screen-intent toggle from a system
    // settings screen, not a dialog — re-check when they come back rather
    // than assuming it worked.
    if (state == AppLifecycleState.resumed) {
      _checkFullScreenIntent();
      _checkExactAlarm();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _previewWatch?.cancel();
    _playingId.dispose();
    // Leaving this screen must never leave an adhan sounding behind it.
    AdhanNative.stop();
    super.dispose();
  }

  /// Plays (or stops) one row's adhan through the native player.
  ///
  /// This used to be a second `just_audio` `AudioPlayer`. It could not work:
  /// `main()` initialises `just_audio_background`, whose platform throws
  /// *"supports only a single player instance"* for every player after the
  /// first, and the Quran recitation player already holds that slot — the
  /// failure was caught and swallowed, which is why previews were silent.
  Future<void> _togglePreview(AdhanOption option, {bool forcePlay = false}) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!forcePlay && _playingId.value == option.id) {
      _previewWatch?.cancel();
      await AdhanNative.stop();
      _playingId.value = null;
      return;
    }
    final started = await AdhanNative.preview(
      AdhanNative.specFor(
        prayerKey: 'dhuhr',
        prayerLabel: option.name,
        // `audio` rather than `full`: a row preview is just the sound, with
        // no screen takeover and no clip.
        mode: AdhanMode.audio,
        option: option,
      ),
    );
    if (!mounted) return;
    if (!started) {
      _playingId.value = null;
      messenger.showSnackBar(SnackBar(content: Text('errors.generic'.tr())));
      return;
    }
    _playingId.value = option.id;
    _watchPreview();
  }

  /// The native player has no completion callback into Dart, so the row's
  /// button is flipped back by watching the real playback state rather than
  /// by assuming a duration.
  void _watchPreview() {
    _previewWatch?.cancel();
    _previewWatch = Timer.periodic(const Duration(milliseconds: 500), (t) async {
      final state = await AdhanNative.state();
      if (!mounted) {
        t.cancel();
        return;
      }
      if (!state.playing) {
        t.cancel();
        _playingId.value = null;
      }
    });
  }

  Future<void> _pickCustomAdhan() async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    final name = p.basenameWithoutExtension(path);
    try {
      await ref.read(adhanCatalogProvider.notifier).addCustom(path, name);
      await ref.read(prayerControllerProvider.notifier).rescheduleFromCache();
    } on AdhanLimitReached {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('prayer.adhan_limit_reached'.tr())),
        );
      }
    }
  }

  Future<void> _saveDefault(String id) async {
    await ref.read(adhanSettingsProvider.notifier).setDefaultAdhan(id);
    await ref.read(prayerControllerProvider.notifier).rescheduleFromCache();
  }

  Future<void> _saveMode(String prayerKey, AdhanMode mode) async {
    await ref.read(adhanSettingsProvider.notifier).setModeFor(prayerKey, mode);
    await ref.read(prayerControllerProvider.notifier).rescheduleFromCache();
  }

  Future<void> _saveChoice(String prayerKey, String? adhanId) async {
    await ref.read(adhanSettingsProvider.notifier).setAdhanFor(prayerKey, adhanId);
    await ref.read(prayerControllerProvider.notifier).rescheduleFromCache();
  }

  /// "معاينة الأذان" — opens the real [AzanPlayerScreen] right now with
  /// the currently-chosen adhan and clip, using the same native player a real
  /// firing uses. It is the actual experience, not a mock-up of it.
  ///
  /// The screen is pushed in [AzanPlayerMode.preview], which is what fixes
  /// the old behaviour where its Stop button ran
  /// `popUntil((route) => route.isFirst)` and threw the user out to the
  /// prayer tab: a preview now pops exactly one route, straight back here.
  Future<void> _previewAzan() async {
    final settings = ref.read(adhanSettingsProvider);
    final catalog = ref.read(adhanCatalogProvider).value ?? const [];
    if (catalog.isEmpty) return;
    if (!mounted) return;

    // Stop any row preview first, so two adhans can never overlap.
    _previewWatch?.cancel();
    await AdhanNative.stop();
    if (!mounted) return;
    _playingId.value = null;

    final spec = previewSpec(
      settings: settings,
      catalog: catalog,
      // Dhuhr = a neutral (non-Fajr) adhan, so the synced text uses the
      // standard wording rather than the Fajr-only sunrise line.
      prayerLabel: _prayerLabels['dhuhr']!.tr(),
    );
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AzanPlayerScreen(
          spec: spec,
          playerMode: AzanPlayerMode.preview,
        ),
      ),
    );
    // Backing out of the preview (system back, a gesture) must not leave the
    // adhan sounding behind this screen.
    await AdhanNative.stop();
  }

  /// Fires this prayer's adhan a few seconds from now through the *real*
  /// alarm pipeline — exact alarm, broadcast receiver, foreground service,
  /// lock-screen takeover — so the button proves the whole chain works on
  /// this device rather than only the parts Dart can reach.
  Future<void> _test(String prayerKey) async {
    final messenger = ScaffoldMessenger.of(context);
    final settings = ref.read(adhanSettingsProvider);
    final catalog = ref.read(adhanCatalogProvider).value ?? const [];
    await fireAdhanTest(
      prayerKey: prayerKey,
      settings: settings,
      catalog: catalog,
    );
    if (mounted) {
      messenger.showSnackBar(SnackBar(content: Text('prayer.test_scheduled'.tr())));
    }
  }

  /// Opens one settings section as its own full-screen page.
  ///
  /// A `MaterialPageRoute` rather than a modal sheet: these are ordinary
  /// settings sub-pages with their own back affordance, and the adhan list in
  /// particular is long enough that a sheet would just reintroduce the nested
  /// scrolling this replaced.
  /// Pushes a sub-page that can **watch** the same providers this screen does.
  ///
  /// It used to take a plain `WidgetBuilder` and be handed a closure that had
  /// already captured `settings` and `catalog` by value. A pushed route is not
  /// rebuilt when the pushing screen rebuilds, so those values were frozen at
  /// the moment the page opened: choosing an adhan saved correctly and the tick
  /// never moved to it, which reads exactly like "the adhan cannot be changed".
  /// Building inside a [Consumer] gives the page its own `ref`.
  Future<void> _openFullScreen({
    required String title,
    required Widget Function(BuildContext context, WidgetRef ref) builder,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Consumer(
          builder: (context, ref, _) => Scaffold(
            appBar: AppBar(title: Text(title)),
            body: SafeArea(child: builder(context, ref)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final catalogAsync = ref.watch(adhanCatalogProvider);
    final settings = ref.watch(adhanSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: Text('prayer.adhan_settings'.tr())),
      body: catalogAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetry(onRetry: () => ref.invalidate(adhanCatalogProvider)),
        data: (catalog) {
          // Three adhans were removed from the catalogue at the owner's
          // request. If the stored default was one of them, the picker would
          // show no selection at all and the subtitle would be blank, while
          // the alarm quietly fell back to `catalog.first` anyway. Heal it
          // instead of leaving the screen disagreeing with what will play.
          if (catalog.isNotEmpty &&
              !catalog.any((o) => o.id == settings.defaultAdhanId)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _saveDefault(catalog.first.id);
            });
          }
          return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_exactAlarmOk == false)
              _PermissionCard(
                icon: Icons.alarm_on,
                message: 'prayer.exact_alarm'.tr(),
                action: 'prayer.exact_alarm_action'.tr(),
                onPressed: AdhanNative.openExactAlarmSettings,
              ),
            if (_fullScreenIntentOk == false)
              _PermissionCard(
                icon: Icons.fullscreen,
                message: 'prayer.full_screen_intent'.tr(),
                action: 'prayer.full_screen_intent_action'.tr(),
                onPressed: AdhanUriBridge.openFullScreenIntentSettings,
              ),
            if (_batteryExempt == false) _BatteryCard(
              onExempt: () async {
                final messenger = ScaffoldMessenger.of(context);
                final granted =
                    await AlarmPermissionsService.instance.requestBatteryOptimizationExemption();
                if (mounted) {
                  setState(() => _batteryExempt = granted);
                  if (granted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('prayer.battery_exempted'.tr())),
                    );
                  }
                }
              },
            ),
            Card(
              child: SwitchListTile(
                secondary: const Icon(Icons.push_pin_outlined),
                title: Text('prayer.status_notification'.tr()),
                subtitle: Text('prayer.status_notification_desc'.tr()),
                value: ref.watch(prayerStatusEnabledProvider),
                onChanged: (v) =>
                    ref.read(prayerStatusEnabledProvider.notifier).set(v),
              ),
            ),
            // Prayer times move with the device's position, so a traveller
            // can have the app re-acquire it on a timer instead of only at
            // launch. Off by default — a fix costs battery, and most users
            // pray in one place.
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.my_location_outlined),
                    title: Text('prayer.auto_location'.tr()),
                    subtitle: Text('prayer.auto_location_desc'.tr()),
                    value: settings.autoLocationUpdate,
                    onChanged: (v) => ref
                        .read(adhanSettingsProvider.notifier)
                        .setAutoLocationUpdate(v),
                  ),
                  if (settings.autoLocationUpdate)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: DropdownButtonFormField<int>(
                        decoration: InputDecoration(
                          labelText: 'prayer.location_interval'.tr(),
                          icon: const Icon(Icons.schedule_outlined),
                          border: InputBorder.none,
                        ),
                        initialValue: settings.locationUpdateMinutes,
                        items: [
                          for (final m in locationUpdateIntervals)
                            DropdownMenuItem(
                              value: m,
                              child: Text(
                                m < 60
                                    ? 'prayer.every_minutes'
                                        .tr(args: ['$m'])
                                    : 'prayer.every_hours'
                                        .tr(args: ['${m ~/ 60}']),
                              ),
                            ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            ref
                                .read(adhanSettingsProvider.notifier)
                                .setLocationUpdateMinutes(v);
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const SizedBox(height: 20),
            // The alarm-stream volume, right where the adhans are chosen: the
            // adhan plays on STREAM_ALARM by design, so the volume rocker
            // does nothing to it — see AlarmVolumeTile's doc.
            const AlarmVolumeTile(),
            // Preview the full Azan experience on demand — opens the real
            // full-screen player right now (video + audio + synced text) so
            // the owner can test it without waiting for an actual prayer.
            const AdhanBackgroundsCard(),
            const SizedBox(height: 12),
            AdhanPreviewCard(onTap: _previewAzan),
            const SizedBox(height: 20),
            // P3‑46: this screen used to have every section (the ~10-item
            // adhan list AND five per-prayer cards) expanded at once, an
            // overwhelming wall to scroll. They were collapsed behind
            // `ExpansionTile`s, but expanding a ten-item list inside an
            // already-scrolling page just moved the problem — the list opened
            // squeezed between other cards with its own scroll fighting the
            // page's. Each now opens as its own full screen instead, so the
            // list gets the whole viewport; the row still shows the current
            // pick so the common case needs no navigation at all.
            Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: const Icon(Icons.library_music_outlined),
                title: Text('prayer.default_adhan_label'.tr()),
                subtitle: Text(
                  catalog
                          .where((o) => o.id == settings.defaultAdhanId)
                          .firstOrNull
                          ?.name ??
                      '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openFullScreen(
                  title: 'prayer.default_adhan_label'.tr(),
                  // Read live inside the page, not captured from the screen
                  // underneath it - see _openFullScreen's doc.
                  builder: (context, pageRef) {
                    final live = pageRef.watch(adhanSettingsProvider);
                    final options =
                        pageRef.watch(adhanCatalogProvider).valueOrNull ??
                            const <AdhanOption>[];
                    return ValueListenableBuilder<String?>(
                      valueListenable: _playingId,
                      builder: (context, playingId, _) => ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    children: [
                      for (final option in options)
                        _AdhanCard(
                          option: option,
                          isSelected: live.defaultAdhanId == option.id,
                          isPlaying: playingId == option.id,
                          onTap: () {
                            _saveDefault(option.id);
                            _togglePreview(option, forcePlay: true);
                          },
                          onStop: () => _togglePreview(option),
                          onRemove: option.isCustom
                              ? () async {
                                  await ref
                                      .read(adhanCatalogProvider.notifier)
                                      .removeCustom(option);
                                }
                              : null,
                        ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: OutlinedButton.icon(
                          onPressed: _pickCustomAdhan,
                          icon: const Icon(Icons.upload_file),
                          label: Text('prayer.pick_file'.tr()),
                        ),
                      ),
                    ],
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: const Icon(Icons.tune),
                title: Text('prayer.per_prayer'.tr()),
                subtitle: Text(
                  'prayer.per_prayer_desc'.tr(),
                  maxLines: 2,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openFullScreen(
                  title: 'prayer.per_prayer'.tr(),
                  builder: (context, pageRef) {
                    final live = pageRef.watch(adhanSettingsProvider);
                    final options =
                        pageRef.watch(adhanCatalogProvider).valueOrNull ??
                            const <AdhanOption>[];
                    return ListView(
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
                    children: [
                      for (final key in adhanPrayerKeys)
                        _PrayerModeCard(
                          prayerKey: key,
                          label: _prayerLabels[key]!.tr(),
                          mode: live.modeFor(key),
                          adhanId: live.adhanIdByPrayer[key],
                          catalog: options,
                          onModeChanged: (m) => _saveMode(key, m),
                          onAdhanChanged: (id) => _saveChoice(key, id),
                          onTest: () => _test(key),
                          accent: scheme.primary,
                        ),
                    ],
                    );
                  },
                ),
              ),
            ),
          ],
          );
        },
      ),
    );
  }
}

/// One "this device needs a permission the Adhan really depends on" card —
/// a real gap, and the single button that closes it. Used for the Android
/// 12+ exact-alarm grant (without it the alarms are approximate and lose the
/// OS exemption the lock-screen takeover rides on) and the Android 14+
/// full-screen-intent grant (without it the OS silently downgrades the
/// adhan alert to an ordinary heads-up notification).
class _PermissionCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final String action;
  final VoidCallback onPressed;

  const _PermissionCard({
    required this.icon,
    required this.message,
    required this.action,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.secondaryContainer,
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: scheme.onSecondaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(color: scheme.onSecondaryContainer),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton(onPressed: onPressed, child: Text(action)),
            ),
          ],
        ),
      ),
    );
  }
}

class _BatteryCard extends StatelessWidget {
  final VoidCallback onExempt;
  const _BatteryCard({required this.onExempt});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.secondaryContainer,
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.battery_alert, color: scheme.onSecondaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'prayer.battery_optimization'.tr(),
                    style: TextStyle(color: scheme.onSecondaryContainer),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton(
                onPressed: onExempt,
                child: Text('prayer.battery_optimization_action'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Adhan selection card — tapping the entire card selects that adhan,
/// saves it immediately, and previews it. No separate "select" button.
class _AdhanCard extends StatelessWidget {
  final AdhanOption option;
  final bool isSelected;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onStop;
  final VoidCallback? onRemove;

  const _AdhanCard({
    required this.option,
    required this.isSelected,
    required this.isPlaying,
    required this.onTap,
    required this.onStop,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: isSelected
            ? AppColors.gold.withValues(alpha: 0.12)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? AppColors.gold.withValues(alpha: 0.6)
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                // Selection indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? AppColors.gold : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.gold
                          : scheme.onSurfaceVariant.withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : null,
                ),
                const SizedBox(width: 14),
                // Name and label
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.name,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? AppColors.gold
                              : scheme.onSurface,
                          fontSize: 15,
                        ),
                      ),
                      if (option.isCustom)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'prayer.imported'.tr(),
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Stop button (only visible when this adhan is playing)
                if (isPlaying)
                  IconButton(
                    icon: Icon(Icons.stop_circle,
                        color: AppColors.gold, size: 28),
                    tooltip: 'prayer.test'.tr(),
                    onPressed: onStop,
                  ),
                // Delete button for custom adhans
                if (onRemove != null)
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        color: scheme.error, size: 22),
                    tooltip: 'prayer.remove_custom'.tr(),
                    onPressed: onRemove,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrayerModeCard extends StatelessWidget {
  final String prayerKey;
  final String label;
  final AdhanMode mode;
  final String? adhanId;
  final List<AdhanOption> catalog;
  final ValueChanged<AdhanMode> onModeChanged;
  final ValueChanged<String?> onAdhanChanged;
  final VoidCallback onTest;
  final Color accent;

  const _PrayerModeCard({
    required this.prayerKey,
    required this.label,
    required this.mode,
    required this.adhanId,
    required this.catalog,
    required this.onModeChanged,
    required this.onAdhanChanged,
    required this.onTest,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(label,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: accent)),
                ),
                TextButton.icon(
                  onPressed: onTest,
                  icon: const Icon(Icons.notifications_active_outlined, size: 18),
                  label: Text('prayer.test'.tr()),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('prayer.notification_mode'.tr(),
                style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AdhanMode.values.map((m) {
                return ChoiceChip(
                  label: Text(m.trKey.tr()),
                  selected: mode == m,
                  onSelected: (_) => onModeChanged(m),
                );
              }).toList(),
            ),
            if (mode == AdhanMode.full || mode == AdhanMode.audio) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                initialValue: adhanId,
                decoration: InputDecoration(
                  labelText: 'prayer.choose_adhan'.tr(),
                  isDense: true,
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text('prayer.use_default'.tr()),
                  ),
                  for (final o in catalog)
                    DropdownMenuItem<String?>(value: o.id, child: Text(o.name)),
                ],
                onChanged: onAdhanChanged,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
