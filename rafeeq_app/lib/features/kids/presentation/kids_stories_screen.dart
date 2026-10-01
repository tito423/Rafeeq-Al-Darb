import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/config/content_mirrors.dart';
import '../../../core/services/download_manager.dart';
import '../../../core/utils/digits.dart';
import '../../../core/widgets/readable_insets.dart';
import '../data/kids_stories.dart';
import 'kids_story_player_screen.dart';

/// «قصص الأنبياء والصالحين والصحابة» - the story shelves of the kids corner.
/// One shelf per category that has stories; a category with none is not
/// shown at all (no empty «coming soon» shelf).
class KidsStoriesScreen extends StatelessWidget {
  const KidsStoriesScreen({super.key});

  static const _shelfColor = {
    StoryCategory.prophets: Color(0xFF2E86DE),
    StoryCategory.righteous: Color(0xFF10AC84),
    StoryCategory.companions: Color(0xFF8854D0),
  };

  @override
  Widget build(BuildContext context) {
    final shelves = [
      for (final cat in StoryCategory.values)
        if (kidsStories.any((s) => s.category == cat)) cat,
    ];
    return Scaffold(
      appBar: AppBar(title: Text('kids.stories'.tr())),
      body: ListView(
        padding: readableInsets(context, const EdgeInsets.fromLTRB(16, 8, 16, 32)),
        children: [
          Text('kids.stories_intro'.tr(),
              style: TextStyle(fontSize: 13.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          for (final cat in shelves) ...[
            const SizedBox(height: 18),
            Row(children: [
              Icon(Icons.auto_stories_rounded, color: _shelfColor[cat]),
              const SizedBox(width: 8),
              Text('kids.story_cat_${cat.name}'.tr(),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            ]),
            const SizedBox(height: 10),
            LayoutBuilder(builder: (context, box) {
              // two cards a row on a phone held upright, more on wider screens
              final cols = (box.maxWidth / 300).floor().clamp(1, 4);
              final w = (box.maxWidth - (cols - 1) * 12) / cols;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final s in kidsStories.where((s) => s.category == cat))
                    SizedBox(width: w, child: _StoryCard(story: s, color: _shelfColor[cat]!)),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _StoryCard extends StatefulWidget {
  final KidsStory story;
  final Color color;
  const _StoryCard({required this.story, required this.color});

  @override
  State<_StoryCard> createState() => _StoryCardState();
}

class _StoryCardState extends State<_StoryCard> {
  bool _offline = false;
  StreamSubscription<List<DownloadTask>>? _sub;

  @override
  void initState() {
    super.initState();
    _check();
    _sub = DownloadManager.instance.stream.listen((_) => _check());
  }

  Future<void> _check() async {
    final p = await DownloadManager.instance.registeredPath(widget.story.downloadId);
    final off = p != null && File(p).existsSync();
    if (mounted && off != _offline) setState(() => _offline = off);
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
    final mins = s.seconds ~/ 60, secs = (s.seconds % 60).round();
    final dur = localizeDigits('$mins:${secs.toString().padLeft(2, '0')}', lang);
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => KidsStoryPlayerScreen(story: s)));
          unawaited(_check());
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(fit: StackFit.expand, children: [
                _MirrorPoster(url: s.posterUrl, color: widget.color),
                const Center(
                  child: CircleAvatar(
                    radius: 26,
                    backgroundColor: Color(0x99000000),
                    child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 34),
                  ),
                ),
                PositionedDirectional(
                  end: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xAA000000), borderRadius: BorderRadius.circular(8)),
                    child: Text(dur, style: const TextStyle(color: Colors.white, fontSize: 12.5)),
                  ),
                ),
                if (_offline)
                  const PositionedDirectional(
                    start: 8,
                    top: 8,
                    child: Icon(Icons.offline_pin_rounded, color: Colors.white, size: 22),
                  ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Text(s.titleKey.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}

/// The poster, tried on each mirror in turn; a coloured panel if none answers.
class _MirrorPoster extends StatefulWidget {
  final String url;
  final Color color;
  const _MirrorPoster({required this.url, required this.color});

  @override
  State<_MirrorPoster> createState() => _MirrorPosterState();
}

class _MirrorPosterState extends State<_MirrorPoster> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final urls = ContentMirrors.of(widget.url);
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [widget.color, Color.lerp(widget.color, Colors.black, 0.35)!]),
      ),
    );
    if (_i >= urls.length) return fallback;
    return CachedNetworkImage(
      imageUrl: urls[_i],
      fit: BoxFit.cover,
      placeholder: (_, _) => fallback,
      errorWidget: (_, _, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _i++);
        });
        return fallback;
      },
    );
  }
}
