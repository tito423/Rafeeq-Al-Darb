import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/models.dart';
import '../../../../core/db/quran_repository.dart';
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _runKeywordSearch(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _keywordResults = null);
      return;
    }
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
              onChanged: _runKeywordSearch,
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'search.search_hint'.tr(),
              prefixIcon: const Icon(Icons.search),
              isDense: true,
            ),
            onChanged: onChanged,
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
                          title: Text(
                            a.textUthmani,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontFamily: 'AmiriQuran', fontSize: 16),
                          ),
                          subtitle: Text('${a.surahId}:${a.ayahNumber}'),
                          onTap: () => onOpen(a),
                        );
                      },
                    ),
        ),
      ],
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

class _TopicsTabState extends State<_TopicsTab> {
  Topic? _openTopic;
  Future<List<Ayah>>? _future;

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

  @override
  Widget build(BuildContext context) {
    if (_openTopic != null) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () => setState(() {
                    _openTopic = null;
                    _future = null;
                  }),
                ),
                Expanded(
                  child: Text(
                    _openTopic!.labelKey.tr(),
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 48),
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
                trailing: const Icon(Icons.chevron_left),
                onTap: () => _selectTopic(topic),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
