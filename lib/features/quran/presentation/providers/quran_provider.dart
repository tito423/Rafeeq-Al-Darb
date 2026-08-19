import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/datasources/quran_db_helper.dart';
import '../../domain/models/ayah.dart';
import '../../domain/models/surah.dart';

final _db = QuranDbHelper();

// ── Surah list ────────────────────────────────────────────────────────────────

final surahsProvider = FutureProvider<List<Surah>>((ref) => _db.getSurahs());

final surahSearchQueryProvider = StateProvider<String>((ref) => '');

final filteredSurahsProvider = FutureProvider<List<Surah>>((ref) async {
  final query = ref.watch(surahSearchQueryProvider);
  if (query.isEmpty) return ref.watch(surahsProvider.future);
  return _db.searchSurahs(query);
});

// ── Ayahs for a surah ────────────────────────────────────────────────────────

final ayahsProvider = FutureProvider.family<List<Ayah>, int>(
  (ref, surahId) => _db.getAyahsForSurah(surahId),
);

// ── Ayahs for a page (Mushaaf mode) ─────────────────────────────────────────

final ayahsForPageProvider = FutureProvider.family<List<Ayah>, int>(
  (ref, pageNumber) => _db.getAyahsByPage(pageNumber),
);

// ── Reading mode ─────────────────────────────────────────────────────────────

enum QuranReadingMode { text, mushaaf }

final readingModeProvider = StateProvider<QuranReadingMode>(
  (ref) => QuranReadingMode.text,
);

// ── Last read bookmark ────────────────────────────────────────────────────────

class LastRead {
  final int surahId;
  final String surahNameAr;
  final String surahNameEn;
  final int ayahNumber;
  final int pageNumber;

  const LastRead({
    required this.surahId,
    required this.surahNameAr,
    required this.surahNameEn,
    required this.ayahNumber,
    required this.pageNumber,
  });

  static const empty = LastRead(
    surahId: 1,
    surahNameAr: 'الفاتحة',
    surahNameEn: 'Al-Fatihah',
    ayahNumber: 1,
    pageNumber: 1,
  );
}

class LastReadNotifier extends StateNotifier<LastRead> {
  LastReadNotifier() : super(LastRead.empty) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final surahId = prefs.getInt('last_surah_id') ?? 1;
    final surahNameAr = prefs.getString('last_surah_ar') ?? 'الفاتحة';
    final surahNameEn = prefs.getString('last_surah_en') ?? 'Al-Fatihah';
    final ayahNumber = prefs.getInt('last_ayah') ?? 1;
    final pageNumber = prefs.getInt('last_page') ?? 1;
    state = LastRead(
      surahId: surahId,
      surahNameAr: surahNameAr,
      surahNameEn: surahNameEn,
      ayahNumber: ayahNumber,
      pageNumber: pageNumber,
    );
  }

  Future<void> save({
    required int surahId,
    required String surahNameAr,
    required String surahNameEn,
    required int ayahNumber,
    required int pageNumber,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_surah_id', surahId);
    await prefs.setString('last_surah_ar', surahNameAr);
    await prefs.setString('last_surah_en', surahNameEn);
    await prefs.setInt('last_ayah', ayahNumber);
    await prefs.setInt('last_page', pageNumber);
    state = LastRead(
      surahId: surahId,
      surahNameAr: surahNameAr,
      surahNameEn: surahNameEn,
      ayahNumber: ayahNumber,
      pageNumber: pageNumber,
    );
  }
}

final lastReadProvider = StateNotifierProvider<LastReadNotifier, LastRead>(
  (ref) => LastReadNotifier(),
);

// ── Current Mushaaf page ──────────────────────────────────────────────────────

final currentMushaafPageProvider = StateProvider<int>((ref) => 1);
