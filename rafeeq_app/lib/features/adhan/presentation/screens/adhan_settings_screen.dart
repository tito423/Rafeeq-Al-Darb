import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:video_player/video_player.dart';

import '../../../../core/models/adhan_mode.dart';
import '../../../../core/models/adhan_option.dart';
import '../../../../core/services/alarm_permissions_service.dart';
import '../../../../core/services/adhan_catalog_service.dart';
import '../../../../core/services/adhan_native.dart';
import '../../../../core/services/adhan_uri_bridge.dart';
import '../../../../core/services/download_manager.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/error_retry.dart';
import '../../../home/data/prayer_controller.dart';
import '../../data/adhan_catalog_provider.dart';
import '../../data/adhan_presentation_provider.dart';
import '../../data/adhan_scheduler.dart';
import '../../data/adhan_settings_provider.dart';
import '../../data/adhan_video_catalog.dart';
import '../../data/prayer_status_enabled_provider.dart';
import 'azan_player_screen.dart';
import '../../../../core/utils/byte_formatter.dart';

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
  String? _playingId;
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
    if (!forcePlay && _playingId == option.id) {
      _previewWatch?.cancel();
      await AdhanNative.stop();
      if (mounted) setState(() => _playingId = null);
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
      setState(() => _playingId = null);
      messenger.showSnackBar(SnackBar(content: Text('errors.generic'.tr())));
      return;
    }
    setState(() => _playingId = option.id);
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
        setState(() => _playingId = null);
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
    final videoPath =
        await resolveAdhanVideoPath(ref.read(adhanPresentationProvider));
    if (!mounted) return;

    // Stop any row preview first, so two adhans can never overlap.
    _previewWatch?.cancel();
    await AdhanNative.stop();
    if (!mounted) return;
    setState(() => _playingId = null);

    final spec = previewSpec(
      settings: settings,
      catalog: catalog,
      adhanVideoPath: videoPath,
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
    final videoPath =
        await resolveAdhanVideoPath(ref.read(adhanPresentationProvider));
    await fireAdhanTest(
      prayerKey: prayerKey,
      settings: settings,
      catalog: catalog,
      adhanVideoPath: videoPath,
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
  Future<void> _openFullScreen({
    required String title,
    required WidgetBuilder builder,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: SafeArea(child: builder(context)),
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
        data: (catalog) => ListView(
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
            const _PresentationCard(),
            const SizedBox(height: 20),
            // Preview the full Azan experience on demand — opens the real
            // full-screen player right now (video + audio + synced text) so
            // the owner can test it without waiting for an actual prayer.
            Card(
              color: scheme.primaryContainer,
              child: ListTile(
                leading: Icon(Icons.play_circle_fill,
                    color: scheme.onPrimaryContainer, size: 32),
                title: Text(
                  'prayer.preview_azan'.tr(),
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  'prayer.preview_azan_desc'.tr(),
                  style: TextStyle(color: scheme.onPrimaryContainer),
                ),
                trailing:
                    Icon(Icons.chevron_right, color: scheme.onPrimaryContainer),
                onTap: _previewAzan,
              ),
            ),
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
                  builder: (context) => ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    children: [
                      for (final option in catalog)
                        _AdhanCard(
                          option: option,
                          isSelected: settings.defaultAdhanId == option.id,
                          isPlaying: _playingId == option.id,
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
                  builder: (context) => ListView(
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
                    children: [
                      for (final key in adhanPrayerKeys)
                        _PrayerModeCard(
                          prayerKey: key,
                          label: _prayerLabels[key]!.tr(),
                          mode: settings.modeFor(key),
                          adhanId: settings.adhanIdByPrayer[key],
                          catalog: catalog,
                          onModeChanged: (m) => _saveMode(key, m),
                          onAdhanChanged: (id) => _saveChoice(key, id),
                          onTest: () => _test(key),
                          accent: scheme.primary,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
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

// ── P2‑7: صوت | فيديو presentation + the background-clip picker ──────────────

class _PresentationCard extends ConsumerStatefulWidget {
  const _PresentationCard();

  @override
  ConsumerState<_PresentationCard> createState() => _PresentationCardState();
}

class _PresentationCardState extends ConsumerState<_PresentationCard> {
  StreamSubscription<List<DownloadTask>>? _sub;

  /// video id -> local file path (once downloaded).
  final Map<String, String> _paths = {};

  @override
  void initState() {
    super.initState();
    _loadPaths();
    _sub = DownloadManager.instance.stream.listen((_) => _loadPaths());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // P3‑44: real-device feedback — there was no way to actually see a video
  // clip before selecting it, only a name and a download button. Plays it
  // exactly as it'll really appear in the full-screen Adhan (muted,
  // looped, behind a dark scrim) so the preview is honest about what
  // picking it actually does, not a different, sound-on experience.
  Future<void> _showVideoPreview(String path) async {
    final controller = VideoPlayerController.file(File(path));
    try {
      await controller.initialize();
      await controller.setVolume(0);
      await controller.setLooping(true);
      await controller.play();
    } catch (_) {
      await controller.dispose();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('errors.generic'.tr())));
      }
      return;
    }
    if (!mounted) {
      await controller.dispose();
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.black,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            AspectRatio(
              aspectRatio: controller.value.aspectRatio == 0
                  ? 16 / 9
                  : controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        ),
      ),
    );
    await controller.dispose();
  }

  Future<void> _loadPaths() async {
    final paths = <String, String>{};
    for (final v in adhanVideoCatalog) {
      final p = await DownloadManager.instance.registeredPath(v.downloadId);
      if (p != null) paths[v.id] = p;
    }
    if (mounted) {
      setState(() => _paths
        ..clear()
        ..addAll(paths));
    }
  }

  Future<void> _download(AdhanVideoOption v) => DownloadManager.instance.enqueue(
        id: v.downloadId,
        url: v.url,
        category: 'adhan_video',
        fileName: v.fileName,
        title: 'prayer.adhan_video'.tr(),
      );

  Future<void> _reschedule() =>
      ref.read(prayerControllerProvider.notifier).rescheduleFromCache();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(adhanPresentationProvider);
    final isVideo = state.mode == AdhanPresentation.video;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('prayer.presentation'.tr(),
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<AdhanPresentation>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: AdhanPresentation.audioOnly,
                  icon: const Icon(Icons.graphic_eq, size: 16),
                  label: Text('prayer.presentation_audio'.tr()),
                ),
                ButtonSegment(
                  value: AdhanPresentation.video,
                  icon: const Icon(Icons.movie_outlined, size: 16),
                  label: Text('prayer.presentation_video'.tr()),
                ),
              ],
              selected: {state.mode},
              onSelectionChanged: (s) async {
                await ref
                    .read(adhanPresentationProvider.notifier)
                    .setMode(s.first);
                await _reschedule();
              },
            ),
            if (isVideo) ...[
              const SizedBox(height: 12),
              for (final v in adhanVideoCatalog)
                _VideoRow(
                  option: v,
                  selected: state.videoId == v.id,
                  downloadedPath: _paths[v.id],
                  task: DownloadManager.instance.taskById(v.downloadId),
                  onSelect: () async {
                    await ref
                        .read(adhanPresentationProvider.notifier)
                        .setVideo(v.id);
                    await _reschedule();
                  },
                  onDownload: () => _download(v),
                  onPreview: _paths[v.id] == null
                      ? null
                      : () => _showVideoPreview(_paths[v.id]!),
                ),
              const SizedBox(height: 8),
              Text(adhanVideoSourceLabelKey.tr(),
                  style: TextStyle(
                      color: scheme.onSurfaceVariant, fontSize: 11)),
            ],
          ],
        ),
      ),
    );
  }
}

class _VideoRow extends StatelessWidget {
  final AdhanVideoOption option;
  final bool selected;
  final String? downloadedPath;
  final DownloadTask? task;
  final VoidCallback onSelect;
  final VoidCallback onDownload;
  final VoidCallback? onPreview;

  const _VideoRow({
    required this.option,
    required this.selected,
    required this.downloadedPath,
    required this.task,
    required this.onSelect,
    required this.onDownload,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final busy = task != null &&
        (task!.status == DownloadStatus.downloading ||
            task!.status == DownloadStatus.queued);
    final downloaded = downloadedPath != null;

    // Selecting a clip is a tap on the row, not a button labelled
    // «اختر»/«مختار» beside it. The owner asked for that word gone: the
    // radio glyph already says which one is chosen, and a word that changes
    // between "select" and "selected" made the row read like a form field
    // rather than a list you pick from.
    return InkWell(
      onTap: downloaded ? onSelect : null,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(
              downloaded
                  ? (selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked)
                  : Icons.movie_outlined,
              size: 20,
              color: selected ? AppColors.gold : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(option.labelKey.tr(),
                  style: TextStyle(
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w400)),
            ),
            if (busy)
              SizedBox(
                width: 90,
                child: LinearProgressIndicator(
                  value: task!.total == null ? null : task!.progress,
                  color: AppColors.gold,
                ),
              )
            else if (downloaded)
              IconButton(
                tooltip: 'prayer.video_preview'.tr(),
                icon: const Icon(Icons.play_circle_outline),
                onPressed: onPreview,
              )
            else
              OutlinedButton.icon(
                onPressed: onDownload,
                icon: const Icon(Icons.download_rounded, size: 16),
                label: Text(formatBytes(option.approxSizeBytes)),
              ),
          ],
        ),
      ),
    );
  }
}
