import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart' show MediaItem;
import 'package:path/path.dart' as p;

import '../../../../core/models/adhan_mode.dart';
import '../../../../core/models/adhan_option.dart';
import '../../../../core/services/adhan_alarm_service.dart';
import '../../../../core/services/adhan_catalog_service.dart';
import '../../../home/data/prayer_controller.dart';
import '../../data/adhan_catalog_provider.dart';
import '../../data/adhan_scheduler.dart';
import '../../data/adhan_settings_provider.dart';
import '../../data/prayer_status_enabled_provider.dart';

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

class _AdhanSettingsScreenState extends ConsumerState<AdhanSettingsScreen> {
  final AudioPlayer _preview = AudioPlayer();
  String? _playingId;
  bool? _batteryExempt;

  @override
  void initState() {
    super.initState();
    _preview.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed && mounted) {
        setState(() => _playingId = null);
      }
    });
    AdhanAlarmService.instance.isBatteryOptimizationExempt().then((v) {
      if (mounted) setState(() => _batteryExempt = v);
    });
  }

  @override
  void dispose() {
    _preview.dispose();
    super.dispose();
  }

  Future<void> _togglePreview(AdhanOption option) async {
    if (_playingId == option.id) {
      await _preview.stop();
      setState(() => _playingId = null);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      final tag = MediaItem(id: option.id, title: option.name, album: 'أذان');
      if (option.isCustom) {
        await _preview.setAudioSource(AudioSource.file(option.filePath!, tag: tag));
      } else {
        await _preview.setAudioSource(AudioSource.asset(option.assetPath!, tag: tag));
      }
      // just_audio's play() future only resolves when playback pauses or
      // completes, not when it starts (the same gotcha `ayah_audio_service`
      // already works around) — awaiting it here would leave the icon stuck
      // on "play" for the whole track instead of flipping immediately.
      unawaited(_preview.play());
      setState(() => _playingId = option.id);
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('errors.generic'.tr())));
      }
    }
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

  Future<void> _test(String prayerKey, AdhanMode mode) async {
    final messenger = ScaffoldMessenger.of(context);
    final settings = ref.read(adhanSettingsProvider);
    final catalog = ref.read(adhanCatalogProvider).value ?? const [];
    await fireAdhanTest(
      prayerKey: prayerKey,
      mode: mode,
      settings: settings,
      catalog: catalog,
    );
    if (mounted) {
      messenger.showSnackBar(SnackBar(content: Text('prayer.test_scheduled'.tr())));
    }
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
        error: (e, _) => Center(child: Text('errors.generic'.tr())),
        data: (catalog) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_batteryExempt == false) _BatteryCard(
              onExempt: () async {
                final messenger = ScaffoldMessenger.of(context);
                final granted =
                    await AdhanAlarmService.instance.requestBatteryOptimizationExemption();
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
            const SizedBox(height: 20),
            Text('prayer.default_adhan_label'.tr(),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: RadioGroup<String>(
                groupValue: settings.defaultAdhanId,
                onChanged: (id) {
                  if (id != null) _saveDefault(id);
                },
                child: Column(
                  children: [
                    for (final option in catalog)
                      _AdhanRow(
                        option: option,
                        playing: _playingId == option.id,
                        onPreview: () => _togglePreview(option),
                        onRemove: option.isCustom
                            ? () async {
                                await ref
                                    .read(adhanCatalogProvider.notifier)
                                    .removeCustom(option);
                              }
                            : null,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickCustomAdhan,
              icon: const Icon(Icons.upload_file),
              label: Text('prayer.pick_file'.tr()),
            ),
            const SizedBox(height: 28),
            Text('prayer.per_prayer'.tr(),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final key in adhanPrayerKeys)
              _PrayerModeCard(
                prayerKey: key,
                label: _prayerLabels[key]!.tr(),
                mode: settings.modeFor(key),
                adhanId: settings.adhanIdByPrayer[key],
                catalog: catalog,
                onModeChanged: (m) => _saveMode(key, m),
                onAdhanChanged: (id) => _saveChoice(key, id),
                onTest: () => _test(key, settings.modeFor(key)),
                accent: scheme.primary,
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

class _AdhanRow extends StatelessWidget {
  final AdhanOption option;
  final bool playing;
  final VoidCallback onPreview;
  final VoidCallback? onRemove;

  const _AdhanRow({
    required this.option,
    required this.playing,
    required this.onPreview,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    // groupValue/onChanged are supplied by the RadioGroup<String> ancestor
    // in AdhanSettingsScreen — this only declares its own value.
    return RadioListTile<String>(
      value: option.id,
      title: Text(option.name),
      subtitle: option.isCustom ? Text('prayer.imported'.tr()) : null,
      secondary: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(playing ? Icons.stop_circle : Icons.play_circle_outline),
            tooltip: 'prayer.test'.tr(),
            onPressed: onPreview,
          ),
          if (onRemove != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'prayer.remove_custom'.tr(),
              onPressed: onRemove,
            ),
        ],
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
