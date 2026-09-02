import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/db/hadith_repository.dart';
import 'hadith_chapter_screen.dart';

/// A book's chapters (abwab). Tapping one opens its hadiths.
class HadithBookScreen extends StatefulWidget {
  final HadithBook book;
  final HadithRepository repo;

  const HadithBookScreen({super.key, required this.book, required this.repo});

  @override
  State<HadithBookScreen> createState() => _HadithBookScreenState();
}

class _HadithBookScreenState extends State<HadithBookScreen> {
  late final Future<List<HadithChapter>> _future =
      widget.repo.chaptersOfBook(widget.book.id);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.book.nameAr)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Text(widget.book.authorAr,
                    style: TextStyle(color: scheme.onSurfaceVariant)),
                const Spacer(),
                Text(
                  '${widget.book.chapterCount} ${'library.chapters'.tr()} · '
                  '${widget.book.hadithCount} ${'library.hadiths_count'.tr()}',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<HadithChapter>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final chapters = snapshot.data!;
                return ListView.separated(
                  itemCount: chapters.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final c = chapters[i];
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 14,
                        child: Text('${c.chapterNo}',
                            style: const TextStyle(fontSize: 11)),
                      ),
                      title: Text(c.nameAr),
                      subtitle: c.nameEn.isNotEmpty ? Text(c.nameEn) : null,
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => HadithChapterScreen(
                            book: widget.book,
                            chapter: c,
                            repo: widget.repo,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
