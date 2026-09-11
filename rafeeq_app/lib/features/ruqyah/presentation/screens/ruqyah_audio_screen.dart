import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/services/download_manager.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/byte_formatter.dart';
import '../../../../core/widgets/islamic_pattern.dart';
import '../../../quran_audio/data/quran_audio_player.dart';
import '../../../quran_audio/presentation/player_screen.dart';
import '../../../quran_audio/presentation/widgets/mini_player.dart';
import '../../data/ruqyah_catalog.dart';

/// Five recorded ruqyahs, listenable and downloadable.
///
/// They play in the Qur'an player — «خلي الرقية الشرعية لما أجي أشغلها تشتغل
/// في مشغل التلاوة لأنه بجد شكله جميل جدًا». That player already drives the
/// app's one `AudioPlayer` with its media notification, and it brings the seek
/// bar, the ten-second jumps, the sleep timer and the queue, so this screen no
/// longer carries a transport of its own. The five recordings are queued in
/// order starting from the one tapped.
///
/// A download can be paused, resumed and cancelled from its card — «اديني
/// إمكانية إيقاف التحميل أو إلغاء أو استئناف التحميل للرقية».
class RuqyahAudioScreen extends StatefulWidget {
  const RuqyahAudioScreen({super.key});

  @override
  State<RuqyahAudioScreen> createState() => _RuqyahAudioScreenState();
}

class _RuqyahAudioScreenState extends State<RuqyahAudioScreen> {
  /// id -> local file, for the ones already downloaded.
  final Map<String, String> _paths = {};
  StreamSubscription<List<DownloadTask>>? _downloads;

  static String _trackId(RuqyahRecording r) => 'ruqyah_${r.id}';

  @override
  void initState() {
    super.initState();
    _loadPaths();
    _downloads = DownloadManager.instance.stream.listen((_) {
      _loadPaths();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _downloads?.cancel();
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

  List<PlayerTrack> _tracks() => [
        for (final r in ruqyahRecordings)
          PlayerTrack(
            id: _trackId(r),
            title: r.heading(),
            artist: 'ruqyah.audio_title'.tr(),
            url: r.url,
            filePath: _paths[r.id],
          ),
      ];

  Future<void> _play(RuqyahRecording r) async {
    final player = QuranAudioPlayer.instance;
    if (player.active && player.current?.id == _trackId(r)) {
      await player.togglePlay();
      return;
    }
    final ok = await player.playQueue(
      _tracks(),
      start: ruqyahRecordings.indexOf(r),
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('errors.offline'.tr())));
      return;
    }
    unawaited(QuranAudioPlayerScreen.open(context));
  }

  Future<void> _download(RuqyahRecording r) => DownloadManager.instance.enqueue(
        id: r.downloadId,
        url: r.url,
        category: 'ruqyah',
        fileName: r.fileName,
        title: r.heading(),
      );

  @override
  Widget build(BuildContext context) {
    final arabic = context.locale.languageCode == 'ar';
    return Scaffold(
      appBar: AppBar(title: Text('ruqyah.audio_title'.tr())),
      bottomNavigationBar: const MiniPlayer(),
      body: ListenableBuilder(
        listenable: QuranAudioPlayer.instance,
        builder: (context, _) {
          final player = QuranAudioPlayer.instance;
          final currentId = player.active ? player.current?.id : null;
          return ListView(
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
                  isCurrent: currentId == _trackId(r),
                  isPlaying: currentId == _trackId(r) && player.playing,
                  onToggle: () => _play(r),
                  onDownload: () => _download(r),
                  onPause: () => DownloadManager.instance.pause(r.downloadId),
                  onResume: () => DownloadManager.instance.resume(r.downloadId),
                  onCancel: () => DownloadManager.instance.cancel(r.downloadId),
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 8),
              Text(
                ruqyahAudioSourceLabelKey.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textLow, fontSize: 11),
              ),
            ],
          );
        },
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
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;

  const _RecordingCard({
    required this.recording,
    required this.arabic,
    required this.downloadedPath,
    required this.task,
    required this.isCurrent,
    required this.isPlaying,
    required this.onToggle,
    required this.onDownload,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
  });

  String get _duration {
    final m = recording.seconds ~/ 60;
    return 'ruqyah.minutes'.tr(namedArgs: {'n': '$m'});
  }

  String get _size => formatBytes(recording.bytes);

  @override
  Widget build(BuildContext context) {
    final status = task?.status;
    final busy = status == DownloadStatus.downloading ||
        status == DownloadStatus.queued;
    final paused = status == DownloadStatus.paused;
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
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
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
                          recording.heading(),
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
                        if (busy || paused)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: GoldProgressBar(
                              value: task!.total == null
                                  ? (paused ? 0 : null)
                                  : task!.progress,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (offline)
                    const Padding(
                      padding: EdgeInsets.only(left: 8, right: 8),
                      child: Icon(Icons.offline_pin_rounded,
                          size: 20, color: AppColors.success),
                    )
                  else if (busy) ...[
                    IconButton(
                      tooltip: 'downloads.pause'.tr(),
                      onPressed: onPause,
                      icon: const Icon(Icons.pause_rounded,
                          color: AppColors.textMedium),
                    ),
                    IconButton(
                      tooltip: 'downloads.cancel'.tr(),
                      onPressed: onCancel,
                      icon: const Icon(Icons.close_rounded,
                          color: AppColors.textMedium),
                    ),
                  ] else if (paused) ...[
                    IconButton(
                      tooltip: 'downloads.resume'.tr(),
                      onPressed: onResume,
                      icon: const Icon(Icons.play_arrow_rounded,
                          color: AppColors.goldSoft),
                    ),
                    IconButton(
                      tooltip: 'downloads.cancel'.tr(),
                      onPressed: onCancel,
                      icon: const Icon(Icons.close_rounded,
                          color: AppColors.textMedium),
                    ),
                  ] else
                    IconButton(
                      tooltip: 'downloads.title'.tr(),
                      onPressed: onDownload,
                      icon: const Icon(Icons.download_rounded,
                          color: AppColors.textMedium),
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
