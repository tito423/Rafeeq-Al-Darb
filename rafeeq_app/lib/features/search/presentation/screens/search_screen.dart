import 'dart:async';

// easy_localization re-exports package:intl, whose TextDirection collides
// with dart:ui's — and the ayah highlighter below needs dart:ui's.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/models.dart';
import '../../../../core/db/quran_repository.dart';
import '../../../../core/services/ayah_audio_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/arabic_text.dart';
import '../../../../core/utils/quran_search_match.dart';
import '../../data/topic_tree.dart';

/// Thematic + keyword Quran search. Returns the tapped ayah's page number via
/// `Navigator.pop`, so the Quran screen can jump straight there.
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

  /// «ادي خيار في البحث بالكلمة بحث بجزء من الكلمة أو كلمة متطابقة، بتشكيل
  /// أو بغير تشكيل». All derivatives by default — it is the one mode that
  /// finds «الصلاة» at all (see `quran_search_match.dart`).
  QuranSearchMode _mode = QuranSearchMode.derivatives;
  bool _diacritics = false;

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
    _debounce = Timer(const Duration(milliseconds: 300), _runKeywordSearch);
  }

  Future<void> _runKeywordSearch() async {
    final q = _controller.text;
    if (q.trim().isEmpty) return;
    final results = await widget.repo
        .searchQuran(q, mode: _mode, matchDiacritics: _diacritics);
    if (mounted && q == _controller.text) {
      setState(() => _keywordResults = results);
    }
  }

  void _setMode(QuranSearchMode m) {
    setState(() => _mode = m);
    _runKeywordSearch();
  }

  void _setDiacritics(bool on) {
    setState(() {
      _diacritics = on;
      // A vowel-tolerant pattern and exact harakat contradict each other.
      if (on && _mode == QuranSearchMode.derivatives) {
        _mode = QuranSearchMode.partial;
      }
    });
    _runKeywordSearch();
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
              mode: _mode,
              diacritics: _diacritics,
              onChanged: _onKeywordChanged,
              onMode: _setMode,
              onDiacritics: _setDiacritics,
              onOpen: _openAyah,
            ),
          ],
        ),
      ),
    );
  }
}

/// A word test that also works for a phrase: any word of the phrase.
bool Function(QuranWord)? _highlightTest(
  String query,
  QuranSearchMode mode,
  bool diacritics,
) {
  final parts = query.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  final tests = [
    for (final p in parts)
      ?quranWordTest(p,
          mode: parts.length > 1 ? QuranSearchMode.partial : mode,
          matchDiacritics: diacritics),
  ];
  if (tests.isEmpty) return null;
  return (w) => tests.any((t) => t(w));
}

class _KeywordTab extends StatelessWidget {
  final TextEditingController controller;
  final List<Ayah>? results;
  final QuranSearchMode mode;
  final bool diacritics;
  final ValueChanged<String> onChanged;
  final ValueChanged<QuranSearchMode> onMode;
  final ValueChanged<bool> onDiacritics;
  final ValueChanged<Ayah> onOpen;

  const _KeywordTab({
    required this.controller,
    required this.results,
    required this.mode,
    required this.diacritics,
    required this.onChanged,
    required this.onMode,
    required this.onDiacritics,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final test = _highlightTest(controller.text, mode, diacritics);
    Widget modeChip(QuranSearchMode m, String key) => ChoiceChip(
          label: Text(key.tr()),
          selected: mode == m,
          onSelected: (m == QuranSearchMode.derivatives && diacritics)
              ? null
              : (_) => onMode(m),
        );
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              modeChip(QuranSearchMode.derivatives, 'search.mode_derivatives'),
              modeChip(QuranSearchMode.partial, 'search.mode_partial'),
              modeChip(QuranSearchMode.wholeWord, 'search.mode_whole'),
              FilterChip(
                label: Text('search.match_diacritics'.tr()),
                selected: diacritics,
                onSelected: onDiacritics,
              ),
            ],
          ),
        ),
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
                    'search.results_count'.plural(results!.length),
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
                            test: test,
                            maxLines: 3,
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

/// The ayah with every word the search matched set in gold. Word by word, so
/// the highlight is the same test the search itself ran — a derivative, a
/// part of a word or the whole word, with or without harakat.
class _HighlightedAyahText extends StatelessWidget {
  final String text;
  final bool Function(QuranWord)? test;
  final int? maxLines;
  const _HighlightedAyahText({required this.text, this.test, this.maxLines});

  @override
  Widget build(BuildContext context) {
    const base = TextStyle(fontFamily: 'AmiriQuran', fontSize: 17, height: 1.6);
    final t = test;
    if (t == null) {
      // ArabicText / an RTL Directionality below: an ayah is Arabic, and the
      // search screen inherits the app's direction, which is LTR in six of
      // the seven locales.
      return ArabicText(
        text,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
        style: base,
      );
    }
    final words = text.split(' ');
    final spans = <TextSpan>[
      for (var i = 0; i < words.length; i++) ...[
        TextSpan(
          text: words[i],
          style: t(QuranWord.of(words[i]))
              ? TextStyle(
                  backgroundColor: AppColors.gold.withValues(alpha: 0.28),
                  color: AppColors.gold,
                  fontWeight: FontWeight.w700,
                )
              : null,
        ),
        if (i < words.length - 1) const TextSpan(text: ' '),
      ],
    ];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: RichText(
        maxLines: maxLines,
        overflow: maxLines == null ? TextOverflow.clip : TextOverflow.ellipsis,
        text: TextSpan(
          style: base.copyWith(color: Theme.of(context).colorScheme.onSurface),
          children: spans,
        ),
      ),
    );
  }
}

class _TopicsTab extends StatefulWidget {
  final QuranRepository repo;
  final ValueChanged<Ayah> onOpen;
  const _TopicsTab({required this.repo, required this.onOpen});

  @override
  State<_TopicsTab> createState() => _TopicsTabState();
}

class _TopicResult {
  final List<Ayah> curated;

  /// Every verse the topic's own words find, minus the curated ones.
  final List<Ayah> all;
  const _TopicResult(this.curated, this.all);
}

class _TopicsTabState extends State<_TopicsTab> {
  Topic? _openTopic;
  Future<_TopicResult>? _future;

  /// True while this topic's ayahs are being played back-to-back via
  /// `playQueue`.
  bool _playingAll = false;

  Future<_TopicResult> _loadTopic(Topic topic) async {
    final curated = <Ayah>[];
    for (final ref in topic.refs) {
      curated.addAll(
          await widget.repo.ayahRange(ref.surah, ref.fromAyah, ref.toAyah));
    }
    final seen = {for (final a in curated) '${a.surahId}:${a.ayahNumber}'};
    final found = await widget.repo.searchTopic(topic.pattern);
    return _TopicResult(curated, [
      for (final a in found)
        if (!seen.contains('${a.surahId}:${a.ayahNumber}')) a,
    ]);
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
    final result = await future;
    if (!mounted) return;
    await AyahAudioService.instance.playQueue(
      [...result.curated, ...result.all],
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

  Widget _header(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Text(
          text,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(color: AppColors.gold, fontWeight: FontWeight.w700),
        ),
      );

  Widget _tile(Ayah a, String label, bool Function(QuranWord)? test) => ListTile(
        leading: IconButton(
          icon: const Icon(Icons.play_circle_outline),
          onPressed: () => AyahAudioService.instance.play(
            a,
            widget.repo,
            title: '$label • ${a.surahId}:${a.ayahNumber}',
          ),
        ),
        title: _HighlightedAyahText(text: a.textUthmani, test: test),
        subtitle: Text('${a.surahId}:${a.ayahNumber}'),
        onTap: () => widget.onOpen(a),
      );

  @override
  Widget build(BuildContext context) {
    if (_openTopic != null) {
      final topic = _openTopic!;
      final label = topic.labelKey.tr();
      final test = topic.pattern.wordTest;
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
            child: FutureBuilder<_TopicResult>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('errors.generic'.tr()));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final r = snapshot.data!;
                return ListView(
                  children: [
                    _header(context,
                        'search.topic_selected'.tr(args: ['${r.curated.length}'])),
                    for (final a in r.curated) ...[
                      _tile(a, label, null),
                      const Divider(height: 1),
                    ],
                    _header(context,
                        'search.topic_all'.tr(args: ['${r.all.length}'])),
                    for (final a in r.all) ...[
                      _tile(a, label, test),
                      const Divider(height: 1),
                    ],
                  ],
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
