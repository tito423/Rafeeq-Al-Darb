import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/models.dart';
import '../../../../core/db/quran_repository.dart';
import '../../../../core/services/ayah_audio_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/topic_tree.dart';

/// Thematic + keyword Quran search (WORK_QUEUE Stage 6). Returns the tapped
/// ayah's page number via `Navigator.pop`, so the Quran screen can jump
/// straight there.
class SearchScreen extends ConsumerStatefulWidget {
  final QuranRepository repo;
  const SearchScreen({super.key, required this.repo});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  List<Ayah>? _keywordResults;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onKeywordChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() => _keywordResults = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _runKeywordSearch(q));
  }

  Future<void> _runKeywordSearch(String q) async {
    final results = await widget.repo.search(q);
    if (mounted) setState(() => _keywordResults = results);
  }

  void _openAyah(Ayah ayah) => Navigator.of(context).pop(ayah.pageNumber);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('search.title'.tr()),
          bottom: TabBar(
            indicatorColor: AppColors.gold,
            labelColor: AppColors.gold,
            tabs: [
              Tab(text: 'search.tab_topics'.tr()),
              Tab(text: 'search.tab_keyword'.tr()),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _TopicsTab(repo: widget.repo, onOpen: _openAyah),
            _KeywordTab(
              controller: _controller,
              results: _keywordResults,
              onChanged: _onKeywordChanged,
              onOpen: _openAyah,
            ),
          ],
        ),
      ),
    );
  }
}

class _KeywordTab extends StatelessWidget {
  final TextEditingController controller;
  final List<Ayah>? results;
  final ValueChanged<String> onChanged;
  final ValueChanged<Ayah> onOpen;

  const _KeywordTab({
    required this.controller,
    required this.results,
    required this.onChanged,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'search.search_hint'.tr(),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (_, value, _) {
                  if (value.text.isEmpty) return const SizedBox.shrink();
                  return IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  );
                },
              ),
              isDense: true,
            ),
            onChanged: onChanged,
          ),
        ),
        // Results count badge
        if (results != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${results!.length} ${'search.results_count'.tr()}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.gold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: results == null
              ? Center(child: Text('search.theme_hint'.tr()))
              : results!.isEmpty
                  ? Center(child: Text('search.no_results'.tr()))
                  : ListView.separated(
                      itemCount: results!.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final a = results![i];
                        return ListTile(
                          title: _HighlightedAyahText(
                            text: a.textUthmani,
                            query: controller.text.trim(),
                          ),
                          subtitle: Text(
                            '${a.surahId}:${a.ayahNumber}',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                          onTap: () => onOpen(a),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

/// Highlights the matching portion of the ayah text using RichText.
/// Uses the same normalization logic as the search itself so the highlight
/// aligns with what actually matched.
class _HighlightedAyahText extends StatelessWidget {
  final String text;
  final String query;
  const _HighlightedAyahText({required this.text, required this.query});

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontFamily: 'AmiriQuran', fontSize: 16),
      );
    }

    // Simple case-insensitive highlight (works well for Arabic since the
    // visual rendering matches even if diacritics differ slightly).
    // We search for the query characters in the original text, ignoring
    // diacritics for the match position but highlighting the original text.
    final spans = <TextSpan>[];
    final lowerText = _stripDiacritics(text);
    final lowerQuery = _stripDiacritics(query);

    int start = 0;
    int idx = lowerText.indexOf(lowerQuery);
    while (idx != -1 && start < text.length) {
      // Map positions from stripped text back to original text
      final origStart = _mapToOriginal(text, lowerText, idx);
      final origEnd = _mapToOriginal(text, lowerText, idx + lowerQuery.length);

      if (origStart > start) {
        spans.add(TextSpan(text: text.substring(start, origStart)));
      }
      spans.add(TextSpan(
        text: text.substring(origStart, origEnd),
        style: TextStyle(
          backgroundColor: AppColors.gold.withValues(alpha: 0.3),
          color: AppColors.gold,
          fontWeight: FontWeight.w700,
        ),
      ));
      start = origEnd;
      idx = lowerText.indexOf(lowerQuery, idx + lowerQuery.length);
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: TextStyle(
          fontFamily: 'AmiriQuran',
          fontSize: 16,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        children: spans,
      ),
    );
  }

  /// Strip Arabic diacritics for matching purposes.
  static final _diacritics = RegExp('[\u0610-\u061A\u064B-\u065F\u06D6-\u06ED\u0640]');
  static final _alefs = RegExp('[\u0622\u0623\u0625\u0671\u0670]');

  static String _stripDiacritics(String s) {
    return s
        .replaceAll(_diacritics, '')
        .replaceAll(_alefs, '\u0627')
        .replaceAll('\u0649', '\u064A');
  }

  /// Maps an index in the stripped string back to the original string.
  static int _mapToOriginal(String original, String stripped, int strippedIdx) {
    if (strippedIdx >= stripped.length) return original.length;
    int si = 0;
    for (int oi = 0; oi < original.length; oi++) {
      if (si == strippedIdx) return oi;
      // If this character in original maps to something in stripped, advance si
      final strippedChar = _stripDiacritics(original[oi]);
      if (strippedChar.isNotEmpty) {
        si += strippedChar.length;
      }
    }
    return original.length;
  }
}

class _TopicsTab extends StatefulWidget {
  final QuranRepository repo;
  final ValueChanged<Ayah> onOpen;
  const _TopicsTab({required this.repo, required this.onOpen});

  @override
  State<_TopicsTab> createState() => _TopicsTabState();
}

class _TopicsTabState extends State<_TopicsTab> {
  Topic? _openTopic;
  Future<List<Ayah>>? _future;

  /// P2‑8 #4 (Sakinah-style topical audio playlist) — true while this
  /// topic's ayahs are being played back-to-back via `playQueue`. Reuses the
  /// exact same curated `TopicRef`s the reading list already shows — no new
  /// content, just a way to listen to them in order instead of reading.
  bool _playingAll = false;

  Future<List<Ayah>> _loadTopic(Topic topic) async {
    final all = <Ayah>[];
    for (final ref in topic.refs) {
      all.addAll(await widget.repo.ayahRange(ref.surah, ref.fromAyah, ref.toAyah));
    }
    return all;
  }

  void _selectTopic(Topic topic) {
    setState(() {
      _openTopic = topic;
      _future = _loadTopic(topic);
    });
  }

  void _closeTopic() {
    AyahAudioService.instance.stopQueue();
    setState(() {
      _openTopic = null;
      _future = null;
      _playingAll = false;
    });
  }

  Future<void> _togglePlayAll(String label) async {
    if (_playingAll) {
      await AyahAudioService.instance.stopQueue();
      if (mounted) setState(() => _playingAll = false);
      return;
    }
    final future = _future;
    if (future == null) return;
    setState(() => _playingAll = true);
    final ayahs = await future;
    if (!mounted) return;
    await AyahAudioService.instance.playQueue(
      ayahs,
      widget.repo,
      titleFor: (a, i) => '$label • ${a.surahId}:${a.ayahNumber}',
    );
    if (mounted) setState(() => _playingAll = false);
  }

  @override
  void dispose() {
    AyahAudioService.instance.stopQueue();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_openTopic != null) {
      final label = _openTopic!.labelKey.tr();
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: _closeTopic,
                ),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  tooltip: _playingAll
                      ? 'search.stop_playing'.tr()
                      : 'search.play_topic'.tr(),
                  icon: Icon(_playingAll
                      ? Icons.stop_circle_outlined
                      : Icons.playlist_play_rounded),
                  color: _playingAll ? AppColors.gold : null,
                  onPressed: () => _togglePlayAll(label),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Ayah>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('errors.generic'.tr()));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final ayahs = snapshot.data!;
                return ListView.separated(
                  itemCount: ayahs.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final a = ayahs[i];
                    return ListTile(
                      leading: IconButton(
                        icon: const Icon(Icons.play_circle_outline),
                        onPressed: () => AyahAudioService.instance.play(
                          a,
                          widget.repo,
                          title: '$label • ${a.surahId}:${a.ayahNumber}',
                        ),
                      ),
                      title: Text(
                        a.textUthmani,
                        style: const TextStyle(
                            fontFamily: 'AmiriQuran', fontSize: 17, height: 1.6),
                      ),
                      subtitle: Text('${a.surahId}:${a.ayahNumber}'),
                      onTap: () => widget.onOpen(a),
                    );
                  },
                );
              },
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        for (final category in topicTree) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 6),
            child: Text(
              category.labelKey.tr(),
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: AppColors.gold),
            ),
          ),
          ...category.topics.map(
            (topic) => Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                title: Text(topic.labelKey.tr()),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _selectTopic(topic),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
