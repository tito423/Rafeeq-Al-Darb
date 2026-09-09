import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/db/hadeethenc_repository.dart';
import '../../../../core/utils/arabic_normalize.dart';
import '../../../../core/widgets/arabic_text.dart';
import 'hadeethenc_detail_screen.dart';

/// One section of the encyclopedia, read a page at a time.
///
/// Paged rather than loaded whole — the largest section is 1,690 records, and
/// CLAUDE.md trap #4 is what happens when a hadith table is asked for in one
/// query. The list fetches 50 at a time as the reader reaches the end.
class HadeethEncCategoryScreen extends StatefulWidget {
  final HadeethEncRepository repo;
  final HadeethCategory category;
  final String sourceName;
  final String sourceUrl;
  final bool rtl;

  const HadeethEncCategoryScreen({
    super.key,
    required this.repo,
    required this.category,
    required this.sourceName,
    required this.sourceUrl,
    required this.rtl,
  });

  @override
  State<HadeethEncCategoryScreen> createState() =>
      _HadeethEncCategoryScreenState();
}

class _HadeethEncCategoryScreenState extends State<HadeethEncCategoryScreen> {
  static const _pageSize = 50;

  final _items = <HadeethItem>[];
  final _scroll = ScrollController();
  bool _loading = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _loadMore();
    _scroll.addListener(() {
      if (_scroll.position.pixels >=
          _scroll.position.maxScrollExtent - 600) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadMore() async {
    if (_loading || _done) return;
    setState(() => _loading = true);
    final page = await widget.repo.ofCategory(
      widget.category.id,
      limit: _pageSize,
      offset: _items.length,
    );
    if (!mounted) return;
    setState(() {
      _items.addAll(page);
      _loading = false;
      _done = page.length < _pageSize;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.category.title)),
      body: _items.isEmpty && _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _items.length + (_done ? 0 : 1),
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                if (i >= _items.length) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return HadeethEncTile(
                  item: _items[i],
                  sourceName: widget.sourceName,
                  sourceUrl: widget.sourceUrl,
                  rtl: widget.rtl,
                );
              },
            ),
    );
  }
}

/// One row: the record's own title, and its grading — the thing that makes
/// this collection worth having, so it is on the list and not only inside.
class HadeethEncTile extends StatelessWidget {
  final HadeethItem item;
  final String sourceName;
  final String sourceUrl;
  final bool rtl;

  const HadeethEncTile({
    super.key,
    required this.item,
    required this.sourceName,
    required this.sourceUrl,
    required this.rtl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = stripBidiControls(
        item.title.isNotEmpty ? item.title : item.hadeeth);

    return ListTile(
      title: rtl
          ? ArabicText(title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium)
          : Text(title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium),
      subtitle: item.grade.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'hadeethenc.grade_inline'
                    .tr(namedArgs: {'grade': item.grade}),
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => HadeethEncDetailScreen(
            item: item,
            sourceName: sourceName,
            sourceUrl: sourceUrl,
            rtl: rtl,
          ),
        ),
      ),
    );
  }
}
