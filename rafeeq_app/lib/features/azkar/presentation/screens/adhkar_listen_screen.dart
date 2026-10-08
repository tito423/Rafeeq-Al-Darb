import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/services/download_manager.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/byte_formatter.dart';
import '../../../../core/utils/digits.dart';
import '../../../../core/widgets/islamic_pattern.dart';
import '../../../quran_audio/data/quran_audio_player.dart';
import '../../../quran_audio/presentation/player_screen.dart';
import '../../../quran_audio/presentation/widgets/mini_player.dart';
import '../../data/adhkar_recitations.dart';

/// «الاستماع لأذكار الصباح» / «… المساء»: the reciters who have a complete
/// recording of it, each to play or to download.
///
/// They play in the Qur'an player, the ruqyah's way: it owns the app's one
/// audio player and its notification, opens full screen over a calm ground,
/// and keeps playing when it is closed (the mini player then, and the
/// notification) - the «شاشة كاملة أو الذهاب إلى الخلفية» the owner asked for.
class AdhkarListenScreen extends StatefulWidget {
  final AdhkarTime time;

  /// A recitation id to start playing as soon as the screen opens - a
  /// reminder set to a reciter lands here.
  final String? autoplay;
  const AdhkarListenScreen({super.key, required this.time, this.autoplay});

  @override
  State<AdhkarListenScreen> createState() => _AdhkarListenScreenState();
}

class _AdhkarListenScreenState extends State<AdhkarListenScreen> {
  final Map<String, String> _paths = {};
  StreamSubscription<List<DownloadTask>>? _downloads;

  List<AdhkarRecitation> get _list => [
    for (final r in adhkarRecitations)
      if (r.fits(widget.time)) r,
  ];

  static String _trackId(AdhkarRecitation r) => 'adhkar_${r.id}';

  @override
  void initState() {
    super.initState();
    _loadPaths().then((_) {
      final id = widget.autoplay;
      if (id == null || !mounted) return;
      final r = _list.where((x) => x.id == id).firstOrNull;
      if (r != null) _play(r);
    });
    _downloads = DownloadManager.instance.stream.listen((_) => _loadPaths());
  }

  @override
  void dispose() {
    _downloads?.cancel();
    super.dispose();
  }

  Future<void> _loadPaths() async {
    for (final r in _list) {
      final p = await DownloadManager.instance.registeredPath(r.downloadId);
      if (p != null && File(p).existsSync()) {
        _paths[r.id] = p;
      } else {
        _paths.remove(r.id);
      }
    }
    if (mounted) setState(() {});
  }

  String _name(AdhkarRecitation r) =>
      context.locale.languageCode == 'ar' || context.locale.languageCode == 'ur'
      ? r.reciterAr
      : r.reciterEn;

  String get _title => widget.time == AdhkarTime.evening
      ? 'azkar.listen_evening'.tr()
      : 'azkar.listen_morning'.tr();

  Future<void> _play(AdhkarRecitation r) async {
    final player = QuranAudioPlayer.instance;
    if (player.active && player.current?.id == _trackId(r)) {
      await player.togglePlay();
      if (mounted) unawaited(QuranAudioPlayerScreen.open(context));
      return;
    }
    final ok = await player.playQueue([
      PlayerTrack(
        id: _trackId(r),
        title:
            (widget.time == AdhkarTime.evening
                    ? 'azkar.track_evening'
                    : 'azkar.track_morning')
                .tr(),
        artist: _name(r),
        url: r.url,
        filePath: _paths[r.id],
      ),
    ]);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('errors.offline'.tr())));
      return;
    }
    unawaited(QuranAudioPlayerScreen.open(context));
  }

  Future<void> _download(AdhkarRecitation r) =>
      DownloadManager.instance.enqueue(
        id: r.downloadId,
        url: r.url,
        category: 'adhkar_audio',
        fileName: r.fileName,
        title: '$_title — ${_name(r)}',
      );

  Future<void> _delete(AdhkarRecitation r) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text('azkar.listen_delete_ask'.tr(args: [_name(r)])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('azkar.listen_delete'.tr()),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await DownloadManager.instance.remove(r.downloadId);
    await _loadPaths();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lang = context.locale.languageCode;
    // «حط خلفية حلوة اسلامية للشاشة بتاعة كل واحد فيهم» (owner,
    // 2026-10-08): the morning screen on its sunrise, the evening on its
    // sunset, darkened enough that the cards and the white title read.
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(_title),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        // The theme's own title style carries a dark colour that wins over
        // foregroundColor - seen dark-on-photo on emulator-5554.
        titleTextStyle: Theme.of(context).appBarTheme.titleTextStyle?.copyWith(
          color: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      bottomNavigationBar: const MiniPlayer(),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(adhkarListenBackground(widget.time), fit: BoxFit.cover),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.35),
                  Colors.black.withValues(alpha: 0.75),
                ],
              ),
            ),
          ),
          SafeArea(
            child: ListenableBuilder(
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
                          Icon(
                            widget.time == AdhkarTime.evening
                                ? Icons.nights_stay_rounded
                                : Icons.wb_sunny_rounded,
                            color: goldOn(scheme),
                            size: 30,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              (widget.time == AdhkarTime.evening
                                      ? 'azkar.listen_intro_evening'
                                      : 'azkar.listen_intro_morning')
                                  .tr(),
                              style: TextStyle(
                                color: scheme.onSurface,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (final r in _list)
                      _ReciterCard(
                        name: _name(r),
                        details: [
                          trn(
                            'azkar.listen_minutes',
                            namedArgs: {
                              'n': localizeDigits(
                                '${(r.seconds / 60).round()}',
                                lang,
                              ),
                            },
                          ),
                          if (_paths[r.id] != null)
                            'downloads.offline_ready'.tr()
                          else
                            formatBytes(r.bytes),
                        ].join(' · '),
                        // On their own lines: a Latin source name inside an Arabic
                        // line wrapped the words around it out of order.
                        both: r.time == AdhkarTime.both,
                        source: r.sourceName,
                        task: DownloadManager.instance.taskById(r.downloadId),
                        downloaded: _paths[r.id] != null,
                        isCurrent: currentId == _trackId(r),
                        isPlaying: currentId == _trackId(r) && player.playing,
                        onPlay: () => _play(r),
                        onDownload: () => _download(r),
                        onPause: () =>
                            DownloadManager.instance.pause(r.downloadId),
                        onResume: () =>
                            DownloadManager.instance.resume(r.downloadId),
                        onCancel: () =>
                            DownloadManager.instance.cancel(r.downloadId),
                        onDelete: () => _delete(r),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReciterCard extends StatelessWidget {
  final String name;
  final String details;
  final bool both;
  final String source;
  final DownloadTask? task;
  final bool downloaded;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback onPlay;
  final VoidCallback onDownload;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  const _ReciterCard({
    required this.name,
    required this.details,
    required this.both,
    required this.source,
    required this.task,
    required this.downloaded,
    required this.isCurrent,
    required this.isPlaying,
    required this.onPlay,
    required this.onDownload,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = goldOn(scheme);
    final status = task?.status;
    final busy =
        status == DownloadStatus.downloading || status == DownloadStatus.queued;
    final paused = status == DownloadStatus.paused;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Color.alphaBlend(
          scheme.primary.withValues(alpha: isCurrent ? 0.22 : 0.08),
          scheme.surfaceContainerHighest,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isCurrent ? scheme.primary : accent.withValues(alpha: 0.3),
            width: isCurrent ? 1.6 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPlay,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
            child: Row(
              children: [
                Icon(
                  isPlaying
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_fill_rounded,
                  size: 44,
                  color: isCurrent ? accent : scheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        details,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      if (both)
                        Text(
                          'azkar.listen_both'.tr(),
                          style: TextStyle(color: accent, fontSize: 12),
                        ),
                      Text(
                        source,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
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
                if (downloaded)
                  IconButton(
                    tooltip: 'azkar.listen_delete'.tr(),
                    onPressed: onDelete,
                    icon: const Icon(
                      Icons.offline_pin_rounded,
                      color: AppColors.success,
                    ),
                  )
                else if (busy) ...[
                  IconButton(
                    tooltip: 'downloads.pause'.tr(),
                    onPressed: onPause,
                    icon: Icon(
                      Icons.pause_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  IconButton(
                    tooltip: 'downloads.cancel'.tr(),
                    onPressed: onCancel,
                    icon: Icon(
                      Icons.close_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ] else if (paused)
                  IconButton(
                    tooltip: 'downloads.resume'.tr(),
                    onPressed: onResume,
                    icon: Icon(Icons.play_arrow_rounded, color: accent),
                  )
                else
                  IconButton(
                    tooltip: 'downloads.title'.tr(),
                    onPressed: onDownload,
                    icon: Icon(
                      Icons.download_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
