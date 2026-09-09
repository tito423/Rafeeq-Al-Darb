import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/services/ayah_audio_service.dart';
import '../../../../core/services/download_manager.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/islamic_pattern.dart';
import '../../data/ruqyah_catalog.dart';
import '../../../../core/utils/byte_formatter.dart';

/// Five recorded ruqyahs, listenable and downloadable.
///
/// Playback goes through [AyahAudioService.playTrack] — the app's one and only
/// player — rather than a second `AudioPlayer`, which `just_audio_background`
/// refuses to allow. That is also what the reader wants here: a 40-minute
/// ruqyah is something you start and then put the phone down on, so it needs
/// the media notification, and only the one player has it.
class RuqyahAudioScreen extends StatefulWidget {
  const RuqyahAudioScreen({super.key});

  @override
  State<RuqyahAudioScreen> createState() => _RuqyahAudioScreenState();
}

class _RuqyahAudioScreenState extends State<RuqyahAudioScreen> {
  /// id -> local file, for the ones already downloaded.
  final Map<String, String> _paths = {};
  StreamSubscription<List<DownloadTask>>? _downloads;
  StreamSubscription<bool>? _playing;

  String? _current;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _loadPaths();
    _downloads = DownloadManager.instance.stream.listen((_) {
      _loadPaths();
      if (mounted) setState(() {});
    });
    _playing = AyahAudioService.instance.isPlayingStream.listen((p) {
      if (!mounted) return;
      // The player is shared, so "something is playing" is not the same as
      // "this screen's track is playing" — ask which track it is on.
      final mine = _current != null && AyahAudioService.instance.isTrack(_current!);
      setState(() => _isPlaying = p && mine);
    });
  }

  @override
  void dispose() {
    _downloads?.cancel();
    _playing?.cancel();
    super.dispose();
  }

  Future<void> _loadPaths() async {
    for (final r in ruqyahRecordings) {
      final p = await DownloadManager.instance.registeredPath(r.downloadId);
      if (p != null && File(p).existsSync()) {
        _paths[r.id] = p;
      } else {
        _paths.remove(r.id);
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggle(RuqyahRecording r) async {
    if (_current == r.id && _isPlaying) {
      await AyahAudioService.instance.pauseResumeTrack();
      return;
    }
    final local = _paths[r.id];
    final ok = await AyahAudioService.instance.playTrack(
      id: r.id,
      url: r.url,
      title: 'ruqyah.audio_title'.tr(),
      artist: context.locale.languageCode == 'ar'
          ? r.headingAr()
          : r.headingEn(),
      localFile: local == null ? null : File(local),
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('errors.offline'.tr())));
      return;
    }
    setState(() {
      _current = r.id;
      _isPlaying = true;
    });
  }

  Future<void> _download(RuqyahRecording r) => DownloadManager.instance.enqueue(
        id: r.downloadId,
        url: r.url,
        category: 'ruqyah',
        fileName: r.fileName,
        title: context.locale.languageCode == 'ar'
            ? r.headingAr()
            : r.headingEn(),
      );

  @override
  Widget build(BuildContext context) {
    final arabic = context.locale.languageCode == 'ar';
    return Scaffold(
      appBar: AppBar(title: Text('ruqyah.audio_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          IslamicPatternPanel(
            child: Row(
              children: [
                const Icon(Icons.healing_outlined,
                    color: AppColors.goldSoft, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'ruqyah.audio_intro'.tr(),
                    style: const TextStyle(
                        color: AppColors.textHigh, fontSize: 13, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final r in ruqyahRecordings) ...[
            _RecordingCard(
              recording: r,
              arabic: arabic,
              downloadedPath: _paths[r.id],
              task: DownloadManager.instance.taskById(r.downloadId),
              isCurrent: _current == r.id,
              isPlaying: _current == r.id && _isPlaying,
              onToggle: () => _toggle(r),
              onDownload: () => _download(r),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
          Text(
            ruqyahAudioSourceLabel,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textLow, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _RecordingCard extends StatelessWidget {
  final RuqyahRecording recording;
  final bool arabic;
  final String? downloadedPath;
  final DownloadTask? task;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback onToggle;
  final VoidCallback onDownload;

  const _RecordingCard({
    required this.recording,
    required this.arabic,
    required this.downloadedPath,
    required this.task,
    required this.isCurrent,
    required this.isPlaying,
    required this.onToggle,
    required this.onDownload,
  });

  String get _duration {
    final m = recording.seconds ~/ 60;
    return 'ruqyah.minutes'.tr(namedArgs: {'n': '$m'});
  }

  String get _size => formatBytes(recording.bytes);

  @override
  Widget build(BuildContext context) {
    final busy = task != null &&
        (task!.status == DownloadStatus.downloading ||
            task!.status == DownloadStatus.queued);
    final offline = downloadedPath != null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: isCurrent
                ? const [Color(0xFF12513F), AppColors.nightElevated]
                : const [AppColors.nightSurface, AppColors.nightElevated],
          ),
          border: Border.all(
            color: isCurrent
                ? AppColors.primarySoft
                : AppColors.gold.withValues(alpha: 0.22),
            width: isCurrent ? 1.6 : 1,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: IslamicPatternPainter(
                    tile: 48,
                    color: AppColors.gold.withValues(alpha: 0.07),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: onToggle,
                    iconSize: 42,
                    icon: Icon(
                      isPlaying
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_fill_rounded,
                      color: isCurrent
                          ? AppColors.goldSoft
                          : AppColors.primarySoft,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          arabic
                              ? recording.headingAr()
                              : recording.headingEn(),
                          style: const TextStyle(
                            color: AppColors.textHigh,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          // Real duration and real byte size, both read from
                          // the source item's metadata and confirmed against
                          // the mirrored file — not "about an hour".
                          [
                            _duration,
                            if (offline)
                              'downloads.offline_ready'.tr()
                            else
                              _size,
                            // Said plainly rather than left blank: this
                            // recording's source names no reciter.
                            if (recording.reciterUnknown)
                              'ruqyah.reciter_unnamed'.tr(),
                          ].join(' · '),
                          maxLines: 2,
                          style: const TextStyle(
                              color: AppColors.textLow, fontSize: 12),
                        ),
                        if (busy)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: GoldProgressBar(
                              value: task!.total == null
                                  ? null
                                  : task!.progress,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!offline && !busy)
                    IconButton(
                      tooltip: 'downloads.title'.tr(),
                      onPressed: onDownload,
                      icon: const Icon(Icons.download_rounded,
                          color: AppColors.textMedium),
                    )
                  else if (offline)
                    const Padding(
                      padding: EdgeInsets.only(left: 8, right: 8),
                      child: Icon(Icons.offline_pin_rounded,
                          size: 20, color: AppColors.success),
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
