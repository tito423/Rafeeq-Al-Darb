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
    return Scaffold(
      appBar: AppBar(title: Text(widget.book.nameAr)),
      body: Column(
        children: [
          // The imam's name and the chapter/hadith counts used to repeat
          // here under the book title. They already appear in full on the
          // collection's own card in the library list, which is where a
          // reader chooses the book — repeating them above every chapter
          // list was just a second header competing with the AppBar title.
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
                      // P3‑54: an Arabic-reading user doesn't need the English
                      // chapter name ("The Book of Revelation") shown under the
                      // real Arabic باب title — hide it entirely in Arabic, same
                      // rule the hadith detail screen already applies to the
                      // book name and English gloss.
                      subtitle: (context.locale.languageCode != 'ar' &&
                              c.nameEn.isNotEmpty)
                          ? Text(c.nameEn)
                          : null,
                      trailing: const Icon(Icons.chevron_right),
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
