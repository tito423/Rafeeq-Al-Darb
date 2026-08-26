import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/hadith_repository.dart';
import '../../domain/models/hadith_models.dart';

// ── Repository provider ──────────────────────────────────────────────────────

final hadithRepositoryProvider = Provider<HadithRepository>((_) => HadithRepository());

// ── Collections ──────────────────────────────────────────────────────────────

final hadithCollectionsProvider = FutureProvider<List<HadithCollection>>((ref) async {
  final repo = ref.watch(hadithRepositoryProvider);
  return repo.getCollections();
});

// ── Chapters ─────────────────────────────────────────────────────────────────

final hadithChaptersProvider = FutureProvider.family<List<HadithChapter>, String>((ref, collectionId) async {
  final repo = ref.watch(hadithRepositoryProvider);
  return repo.getChapters(collectionId);
});

// ── Hadiths by chapter ───────────────────────────────────────────────────────

class ChapterKey {
  final String collectionId;
  final String chapterId;
  const ChapterKey(this.collectionId, this.chapterId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChapterKey &&
          other.collectionId == collectionId &&
          other.chapterId == chapterId;

  @override
  int get hashCode => Object.hash(collectionId, chapterId);
}

final hadithsByChapterProvider = FutureProvider.family<List<Hadith>, ChapterKey>((ref, key) async {
  final repo = ref.watch(hadithRepositoryProvider);
  return repo.getHadithsByChapter(key.collectionId, key.chapterId);
});

// ── Search ───────────────────────────────────────────────────────────────────

final hadithSearchQueryProvider = StateProvider<String>((ref) => '');

final hadithSearchResultsProvider = FutureProvider<List<Hadith>>((ref) async {
  final query = ref.watch(hadithSearchQueryProvider);
  if (query.trim().length < 2) return [];
  final repo = ref.watch(hadithRepositoryProvider);
  return repo.searchHadiths(query.trim());
});
