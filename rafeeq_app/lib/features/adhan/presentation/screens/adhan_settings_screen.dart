import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart' show MediaItem;
import 'package:path/path.dart' as p;
import 'package:video_player/video_player.dart';

import '../../../../core/models/adhan_mode.dart';
import '../../../../core/models/adhan_option.dart';
import '../../../../core/services/adhan_alarm_service.dart';
import '../../../../core/services/adhan_catalog_service.dart';
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
  final AudioPlayer _preview = AudioPlayer();
  String? _playingId;
  bool? _batteryExempt;
  bool? _fullScreenIntentOk;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _preview.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed && mounted) {
        setState(() => _playingId = null);
      }
    });
    AdhanAlarmService.instance.isBatteryOptimizationExempt().then((v) {
      if (mounted) setState(() => _batteryExempt = v);
    });
    _checkFullScreenIntent();
  }

  Future<void> _checkFullScreenIntent() async {
    final v = await AdhanUriBridge.canUseFullScreenIntent();
    if (mounted) setState(() => _fullScreenIntentOk = v);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user grants the P3‑19 full-screen-intent toggle from a system
    // settings screen, not a dialog — re-check when they come back rather
    // than assuming it worked.
    if (state == AppLifecycleState.resumed) _checkFullScreenIntent();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _preview.dispose();
    super.dispose();
  }

  Future<void> _togglePreview(AdhanOption option, {bool forcePlay = false}) async {
    if (!forcePlay && _playingId == option.id) {
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
    final videoPath =
        await resolveAdhanVideoPath(ref.read(adhanPresentationProvider));
    await fireAdhanTest(
      prayerKey: prayerKey,
      mode: mode,
      settings: settings,
      catalog: catalog,
      adhanVideoPath: videoPath,
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
        error: (e, _) => ErrorRetry(onRetry: () => ref.invalidate(adhanCatalogProvider)),
        data: (catalog) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_fullScreenIntentOk == false)
              _FullScreenIntentCard(
                onGrant: AdhanUriBridge.openFullScreenIntentSettings,
              ),
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
            const _PresentationCard(),
            const SizedBox(height: 20),
            // P3‑46: real-device feedback — this screen had every section
            // (the ~10-item adhan list AND five per-prayer cards) expanded
            // at once, an overwhelming wall to scroll. The two long ones are
            // now collapsed by default behind `ExpansionTile`s; the default
            // adhan's header shows the current pick so the common case (just
            // seeing/changing which adhan plays) needs no expand at all.
            Card(
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
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
                childrenPadding: const EdgeInsets.only(bottom: 8),
                children: [
                  RadioGroup<String>(
                    groupValue: settings.defaultAdhanId,
                    onChanged: (id) {
                      if (id == null) return;
                      _saveDefault(id);
                      // P3‑7 (J4): picking an adhan previews it immediately —
                      // the owner asked not to also require a separate tap on
                      // the play icon. Reuses the exact same preview player as
                      // that icon (_togglePreview), so a still-playing preview
                      // of a *different* adhan is correctly stopped first.
                      final picked =
                          catalog.where((o) => o.id == id).firstOrNull;
                      if (picked != null) {
                        _togglePreview(picked, forcePlay: true);
                      }
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
            const SizedBox(height: 20),
            Card(
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                leading: const Icon(Icons.tune),
                title: Text('prayer.per_prayer'.tr()),
                subtitle: Text(
                  'prayer.per_prayer_desc'.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
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
                      onTest: () => _test(key, settings.modeFor(key)),
                      accent: scheme.primary,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// P3‑19: on Android 14+, shown when the OS reports the app doesn't yet
/// have the separate full-screen-intent grant — mirrors [_BatteryCard]'s
/// look exactly, same "here's a real gap, here's the one button that fixes
/// it" pattern.
class _FullScreenIntentCard extends StatelessWidget {
  final VoidCallback onGrant;
  const _FullScreenIntentCard({required this.onGrant});

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
                Icon(Icons.fullscreen, color: scheme.onSecondaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'prayer.full_screen_intent'.tr(),
                    style: TextStyle(color: scheme.onSecondaryContainer),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton(
                onPressed: onGrant,
                child: Text('prayer.full_screen_intent_action'.tr()),
              ),
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
              Text(adhanVideoSourceLabel,
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
    final sizeMb = (option.approxSizeBytes / 1000000).toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
            child: GestureDetector(
              onTap: downloaded ? onSelect : null,
              child: Text(option.nameAr,
                  style: TextStyle(
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w400)),
            ),
          ),
          if (busy)
            SizedBox(
              width: 90,
              child: LinearProgressIndicator(
                value: task!.total == null ? null : task!.progress,
                color: AppColors.gold,
              ),
            )
          else if (downloaded) ...[
            IconButton(
              tooltip: 'prayer.video_preview'.tr(),
              icon: const Icon(Icons.play_circle_outline),
              onPressed: onPreview,
            ),
            TextButton(
              onPressed: onSelect,
              child: Text(selected
                  ? 'prayer.video_selected'.tr()
                  : 'prayer.video_select'.tr()),
            ),
          ] else
            OutlinedButton.icon(
              onPressed: onDownload,
              icon: const Icon(Icons.download_rounded, size: 16),
              label: Text('$sizeMb MB'),
            ),
        ],
      ),
    );
  }
}
