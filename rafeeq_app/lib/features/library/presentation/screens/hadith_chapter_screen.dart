import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/widgets/future_view.dart';

import '../../../../core/db/hadith_repository.dart';
import '../../../../core/utils/arabic_normalize.dart';
import '../../../../core/widgets/arabic_text.dart';
import 'hadith_detail_screen.dart';

/// All hadiths in one chapter — numbered exactly as they are in the book,
/// in real numeric order (see HadithItem's doc on the ordering bug this
/// replaces).
class HadithChapterScreen extends StatefulWidget {
  final HadithBook book;
  final HadithChapter chapter;
  final HadithRepository repo;

  const HadithChapterScreen({
    super.key,
    required this.book,
    required this.chapter,
    required this.repo,
  });

  @override
  State<HadithChapterScreen> createState() => _HadithChapterScreenState();
}

class _HadithChapterScreenState extends State<HadithChapterScreen> {
  late Future<List<HadithItem>> _future = _load();

  Future<List<HadithItem>> _load() =>
      widget.repo.hadithsOfChapter(widget.book.id, widget.chapter.chapterNo);

  void _retry() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.chapter.nameAr,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: FutureBuilder<List<HadithItem>>(
        future: _future,
        builder: (context, snapshot) => FutureView<List<HadithItem>>(
          snapshot: snapshot,
          onRetry: _retry,
          isEmpty: (items) => items.isEmpty,
          empty: Center(child: Text('errors.empty'.tr())),
          builder: (items) {
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final h = items[i];
              return ListTile(
                leading: CircleAvatar(
                  radius: 16,
                  child: Text('${h.numberInBook}',
                      style: const TextStyle(fontSize: 12)),
                ),
                // ArabicText: a preview cut to two lines still ends on a
                // neutral, and in an LTR locale a plain Text lays the
                // paragraph out LTR and moves it. See daily_hadith_card.
                title: ArabicText(
                  stripBidiControls(h.arabic),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'AmiriQuran', fontSize: 15),
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => HadithDetailScreen(
                      book: widget.book,
                      chapterHadiths: items,
                      initialIndex: i,
                    ),
                  ),
                ),
              );
            },
          );
          },
        ),
      ),
    );
  }
}
