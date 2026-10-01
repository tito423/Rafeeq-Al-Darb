import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/config/content_mirrors.dart';
import '../../../core/db/models.dart';
import '../../../core/db/quran_repository.dart';
import '../../../core/services/download_manager.dart';
import '../../../core/utils/digits.dart';
import '../data/kids_stories.dart';

/// Plays one story with a player the child can see and control (owner's
/// rule: every media the app plays has visible controls): play/pause, a seek
/// bar with times, ten-second skips, captions on/off, full screen.
///
/// Sources in order: the offline copy if it was downloaded, then every
/// mirror of the R2 file (ContentMirrors). A source that fails - at open or
/// mid-play - hands over to the next at the same position.
///
/// Captions are the narrator's exact words; during a recitation the ayah is
/// shown from the app's own mushaf text (AmiriQuran), never from the
/// catalogue.
class KidsStoryPlayerScreen extends ConsumerStatefulWidget {
  final KidsStory story;
  const KidsStoryPlayerScreen({super.key, required this.story});

  @override
  ConsumerState<KidsStoryPlayerScreen> createState() => _KidsStoryPlayerScreenState();
}

class _KidsStoryPlayerScreenState extends ConsumerState<KidsStoryPlayerScreen> {
  VideoPlayerController? _c;
  List<String> _sources = const [];
  int _src = 0;
  bool _failed = false;
  bool _opening = true;
  bool _controls = true;
  bool _captions = true;
  bool _full = false;
  bool _immersive = false;
  Timer? _hide;
  final Map<String, (Ayah, String)> _ayahs = {};
  final _focus = FocusNode();

  KidsStory get story => widget.story;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    final local = await DownloadManager.instance.registeredPath(story.downloadId);
    _sources = [
      if (local != null && File(local).existsSync()) 'file://$local',
      ...ContentMirrors.of(story.videoUrl),
    ];
    await _open(Duration.zero);
  }

  Future<void> _open(Duration at) async {
    if (!mounted) return;
    setState(() => _opening = true);
    final s = _sources[_src];
    final c = s.startsWith('file://')
        ? VideoPlayerController.file(File(s.substring(7)))
        : VideoPlayerController.networkUrl(Uri.parse(s));
    try {
      await c.initialize();
    } catch (e) {
      debugPrint('story ${story.id}: source $s failed: $e');
      await c.dispose();
      return _next(at);
    }
    if (!mounted) {
      await c.dispose();
      return;
    }
    c.addListener(_tick);
    if (at > Duration.zero) await c.seekTo(at);
    await c.play();
    unawaited(WakelockPlus.enable());
    setState(() {
      _c = c;
      _opening = false;
    });
    _scheduleHide();
  }

  Future<void> _next(Duration at) async {
    _src++;
    if (_src >= _sources.length) {
      if (mounted) {
        setState(() {
          _failed = true;
          _opening = false;
        });
      }
      return;
    }
    await _open(at);
  }

  Duration _lastPos = Duration.zero;
  bool _endShown = false;
  static bool _ended(VideoPlayerValue v) =>
      v.duration > Duration.zero && v.position >= v.duration - const Duration(milliseconds: 250);

  void _tick() {
    final c = _c;
    if (c == null) return;
    final v = c.value;
    if (v.hasError) {
      final at = v.position;
      c.removeListener(_tick);
      _c = null;
      unawaited(c.dispose());
      unawaited(_next(at));
      return;
    }
    // video_player keeps isPlaying true at the end of the file (seen on
    // the emulator: 1:49 / 1:49 with the pause icon), so the end is read
    // from the position.
    if (_ended(v) && !_endShown) {
      _endShown = true;
      unawaited(WakelockPlus.disable());
      _show();
    } else if (!_ended(v)) {
      _endShown = false;
    }
    // repaint for captions / the seek bar about 5 times a second
    if ((v.position - _lastPos).inMilliseconds.abs() >= 200 || !v.isPlaying) {
      _lastPos = v.position;
      if (mounted) setState(() {});
    }
  }

  void _scheduleHide() {
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 3), () {
      final v = _c?.value;
      if (mounted && v != null && v.isPlaying && !_ended(v)) setState(() => _controls = false);
    });
  }

  void _show() {
    if (mounted) setState(() => _controls = true);
    _scheduleHide();
  }

  void _toggle() {
    final c = _c;
    if (c == null) return;
    if (_ended(c.value)) {
      // replay from the start
      c.seekTo(Duration.zero);
      c.play();
      unawaited(WakelockPlus.enable());
    } else if (c.value.isPlaying) {
      c.pause();
      unawaited(WakelockPlus.disable());
    } else {
      c.play();
      unawaited(WakelockPlus.enable());
    }
    _show();
  }

  void _skip(int seconds) {
    final c = _c;
    if (c == null) return;
    var to = c.value.position + Duration(seconds: seconds);
    if (to < Duration.zero) to = Duration.zero;
    if (to > c.value.duration) to = c.value.duration;
    c.seekTo(to);
    _show();
  }

  Future<void> _setFull(bool full) async {
    setState(() => _full = full);
    if (full) {
      await SystemChrome.setPreferredOrientations(
          [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      await _restoreSystemUi();
    }
    _show();
  }

  // SystemChrome is process-wide (CLAUDE.md trap 43): whatever this screen
  // changed is put back when it closes, whichever way it closes.
  static Future<void> _restoreSystemUi() async {
    await SystemChrome.setPreferredOrientations(const []);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    _hide?.cancel();
    _c?.removeListener(_tick);
    _c?.dispose();
    _focus.dispose();
    unawaited(WakelockPlus.disable());
    if (_full) unawaited(_restoreSystemUi());
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.select || k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.space || k == LogicalKeyboardKey.mediaPlayPause) {
      _toggle();
      return KeyEventResult.handled;
    }
    // The seek bar runs with the layout's direction (mirrored in RTL), so a
    // D-pad arrow moves time the way the bar's thumb moves.
    if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.mediaRewind) {
      _skip(Directionality.of(context) == TextDirection.rtl ? 10 : -10);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowRight || k == LogicalKeyboardKey.mediaFastForward) {
      _skip(Directionality.of(context) == TextDirection.rtl ? -10 : 10);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  String _fmt(Duration d) {
    final m = d.inMinutes, s = d.inSeconds % 60;
    return localizeDigits('$m:${s.toString().padLeft(2, '0')}', context.locale.languageCode);
  }

  Future<(Ayah, String)?> _ayah(int surah, int ayah) async {
    final key = '$surah:$ayah';
    if (_ayahs.containsKey(key)) return _ayahs[key];
    final repo = await ref.read(quranRepositoryProvider.future);
    final a = await repo.ayah(surah, ayah);
    if (a == null) return null;
    final names = await repo.surahs();
    final r = (a, names[surah - 1].nameAr);
    _ayahs[key] = r;
    return r;
  }

  Widget _captionView(bool overlay) {
    final c = _c;
    if (!_captions || c == null) return const SizedBox.shrink();
    final cap = story.captionAt(c.value.position.inMilliseconds / 1000);
    if (cap == null) return SizedBox(height: overlay ? 0 : 96);
    final style = TextStyle(
      fontSize: overlay ? 20 : 21,
      height: 1.7,
      fontWeight: FontWeight.w700,
      color: overlay ? Colors.white : Theme.of(context).colorScheme.onSurface,
      shadows: overlay ? const [Shadow(blurRadius: 6)] : null,
    );
    Widget child;
    if (cap.isAyah) {
      final key = '${cap.surah}:${cap.ayah}';
      final cached = _ayahs[key];
      child = cached != null
          ? _ayahText(cached, overlay)
          : FutureBuilder<(Ayah, String)?>(
              future: _ayah(cap.surah!, cap.ayah!),
              builder: (_, snap) => snap.data == null ? const SizedBox.shrink() : _ayahText(snap.data!, overlay),
            );
    } else {
      child = Text(cap.text!, textAlign: TextAlign.center, textDirection: TextDirection.rtl, style: style);
    }
    final box = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: overlay
          ? BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(14))
          : null,
      child: child,
    );
    return overlay ? box : ConstrainedBox(constraints: const BoxConstraints(minHeight: 96), child: Center(child: box));
  }

  Widget _ayahText((Ayah, String) a, bool overlay) {
    final lang = context.locale.languageCode;
    final col = overlay ? Colors.white : Theme.of(context).colorScheme.onSurface;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('﴿${a.$1.textUthmani}﴾',
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: TextStyle(fontFamily: 'AmiriQuran', fontSize: overlay ? 22 : 23, height: 2.0, color: col,
                shadows: overlay ? const [Shadow(blurRadius: 6)] : null)),
        Text('${a.$2} · ${localizeDigits('${a.$1.ayahNumber}', lang)}',
            style: TextStyle(fontSize: 13, color: col.withValues(alpha: 0.75))),
      ],
    );
  }

  Widget _video() {
    final c = _c;
    final cs = Theme.of(context).colorScheme;
    if (_failed) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.white70, size: 40),
          const SizedBox(height: 8),
          Text('kids.story_error'.tr(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () {
              setState(() {
                _failed = false;
                _src = 0;
              });
              unawaited(_start());
            },
            icon: const Icon(Icons.refresh_rounded),
            label: Text('common.retry'.tr()),
          ),
        ]),
      );
    }
    if (c == null || _opening) {
      return const ColoredBox(color: Colors.black, child: Center(child: CircularProgressIndicator()));
    }
    final v = c.value;
    final pos = v.position, dur = v.duration;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _controls ? setState(() => _controls = false) : _show(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: Colors.black, child: Center(child: AspectRatio(aspectRatio: v.aspectRatio, child: VideoPlayer(c)))),
          if (_immersive)
            Positioned(left: 24, right: 24, bottom: _controls ? 92 : 22, child: _captionView(true)),
          AnimatedOpacity(
            opacity: _controls ? 1 : 0,
            duration: const Duration(milliseconds: 220),
            child: IgnorePointer(
              ignoring: !_controls,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x66000000), Color(0x00000000), Color(0x99000000)],
                  ),
                ),
                child: Stack(children: [
                  if (_immersive)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: IconButton(
                        tooltip: 'kids.story_exit_full'.tr(),
                        onPressed: () => _full ? _setFull(false) : Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      ),
                    ),
                  Center(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        tooltip: 'kids.story_back10'.tr(),
                        iconSize: 38,
                        onPressed: () => _skip(-10),
                        icon: const Icon(Icons.replay_10_rounded, color: Colors.white),
                      ),
                      const SizedBox(width: 18),
                      IconButton.filled(
                        tooltip: _ended(v)
                            ? 'kids.story_replay'.tr()
                            : v.isPlaying ? 'kids.story_pause'.tr() : 'kids.story_play'.tr(),
                        iconSize: 52,
                        style: IconButton.styleFrom(backgroundColor: cs.primary.withValues(alpha: 0.85)),
                        onPressed: _toggle,
                        icon: Icon(
                            _ended(v)
                                ? Icons.replay_rounded
                                : v.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.white),
                      ),
                      const SizedBox(width: 18),
                      IconButton(
                        tooltip: 'kids.story_fwd10'.tr(),
                        iconSize: 38,
                        onPressed: () => _skip(10),
                        icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
                      ),
                    ]),
                  ),
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 4,
                    child: Row(children: [
                      Text(_fmt(pos), style: const TextStyle(color: Colors.white, fontSize: 13)),
                      Expanded(
                        child: Slider(
                          value: dur.inMilliseconds == 0 ? 0 : (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0),
                          onChanged: (x) {
                            c.seekTo(Duration(milliseconds: (x * dur.inMilliseconds).round()));
                            _show();
                          },
                        ),
                      ),
                      Text(_fmt(dur), style: const TextStyle(color: Colors.white, fontSize: 13)),
                      IconButton(
                        tooltip: 'kids.story_captions'.tr(),
                        onPressed: () => setState(() => _captions = !_captions),
                        icon: Icon(_captions ? Icons.closed_caption_rounded : Icons.closed_caption_off_rounded,
                            color: Colors.white),
                      ),
                      IconButton(
                        tooltip: _full ? 'kids.story_exit_full'.tr() : 'kids.story_full'.tr(),
                        onPressed: () => _setFull(!_full),
                        icon: Icon(_full ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded, color: Colors.white),
                      ),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    // Full screen - asked for, or the phone simply turned sideways: the video
    // fills the screen and the captions ride on it. Back leaves a full screen
    // that was asked for; on a phone that was only turned, it closes the story.
    _immersive = _full || landscape;
    final player = Focus(focusNode: _focus, autofocus: true, onKeyEvent: _onKey, child: _video());
    if (_immersive) {
      return PopScope(
        canPop: !_full,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(_setFull(false));
        },
        child: Scaffold(backgroundColor: Colors.black, body: SafeArea(child: player)),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(story.titleKey.tr())),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          AspectRatio(aspectRatio: 16 / 9, child: player),
          Padding(padding: const EdgeInsets.fromLTRB(12, 14, 12, 4), child: _captionView(false)),
          const Divider(height: 24),
          _DownloadRow(story: story),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Text('kids.story_about'.tr(),
                style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }

}

/// Download for offline viewing, with its real state from DownloadManager.
class _DownloadRow extends StatefulWidget {
  final KidsStory story;
  const _DownloadRow({required this.story});

  @override
  State<_DownloadRow> createState() => _DownloadRowState();
}

class _DownloadRowState extends State<_DownloadRow> {
  String? _path;
  StreamSubscription<List<DownloadTask>>? _sub;

  @override
  void initState() {
    super.initState();
    _refresh();
    _sub = DownloadManager.instance.stream.listen((_) => _refresh());
  }

  Future<void> _refresh() async {
    final p = await DownloadManager.instance.registeredPath(widget.story.downloadId);
    if (mounted) setState(() => _path = p != null && File(p).existsSync() ? p : null);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.story;
    final lang = context.locale.languageCode;
    final mb = localizeDigits((s.bytes / 1048576).toStringAsFixed(1), lang);
    final task = DownloadManager.instance.taskById(s.downloadId);
    final running = task != null &&
        (task.status == DownloadStatus.downloading || task.status == DownloadStatus.queued);
    if (_path != null) {
      return ListTile(
        leading: const Icon(Icons.offline_pin_rounded, color: Colors.green),
        title: Text('kids.story_downloaded'.tr()),
        subtitle: Text('kids.story_size'.tr(args: [mb])),
        trailing: IconButton(
          tooltip: 'kids.story_delete'.tr(),
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: () async {
            await DownloadManager.instance.remove(s.downloadId);
            await _refresh();
          },
        ),
      );
    }
    if (running) {
      return ListTile(
        leading: const Icon(Icons.downloading_rounded),
        title: Text('kids.story_downloading'.tr(args: [localizeDigits('${(task.progress * 100).round()}', lang)])),
        subtitle: LinearProgressIndicator(value: task.progress == 0 ? null : task.progress),
        trailing: IconButton(
          tooltip: 'common.cancel'.tr(),
          icon: const Icon(Icons.close_rounded),
          onPressed: () => DownloadManager.instance.cancel(s.downloadId),
        ),
      );
    }
    return ListTile(
      leading: const Icon(Icons.download_rounded),
      title: Text('kids.story_download'.tr()),
      subtitle: Text(task?.error ?? 'kids.story_size'.tr(args: [mb])),
      onTap: () => DownloadManager.instance.enqueue(
        id: s.downloadId,
        url: s.videoUrl,
        category: 'kids_story',
        fileName: s.fileName,
        title: s.titleKey.tr(),
      ),
    );
  }
}
