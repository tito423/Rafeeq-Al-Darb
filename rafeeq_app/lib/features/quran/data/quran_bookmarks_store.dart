import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/rafeeq_app.dart';

/// One mark the reader can come back to: an ayah, or a whole page.
///
/// «مفيش خيار علامات عشان اقدر ارجع للاية او الصفحة في اي وقت» (owner,
/// 2026-10-20). A bookmark only marks a place; a note (ayah_notes_store) is
/// text he wrote. Kept on the device: the sync server accepts a fixed list of
/// keys (sync_backend SYNC_STATE_KEYS), and adding one is a Worker deploy
/// that is the owner's to approve.
class QuranBookmark {
  const QuranBookmark.ayah({
    required int this.surah,
    required int this.ayah,
    required this.page,
    required this.at,
    this.kind = BookmarkKind.reading,
  });

  const QuranBookmark.page({
    required this.page,
    required this.at,
    this.kind = BookmarkKind.reading,
  })  : surah = null,
        ayah = null;

  /// Null for a page bookmark.
  final int? surah;
  final int? ayah;

  /// The Madani page; for an ayah bookmark, the page the ayah is on.
  final int page;

  /// When it was made, ms since epoch - the list is newest first.
  final int at;

  /// What the mark is for - its colour in the bookmarks card.
  final BookmarkKind kind;

  bool get isAyah => surah != null && ayah != null;

  String get key => isAyah ? 'a:$surah:$ayah' : 'p:$page';

  Map<String, Object> toJson() => {
        if (isAyah) 's': surah!,
        if (isAyah) 'a': ayah!,
        'p': page,
        't': at,
        if (kind != BookmarkKind.reading) 'k': kind.name,
      };

  static QuranBookmark? fromJson(Object? j) {
    if (j is! Map) return null;
    final p = j['p'], t = j['t'], s = j['s'], a = j['a'];
    final kind = BookmarkKind.values
            .where((k) => k.name == j['k'])
            .firstOrNull ??
        BookmarkKind.reading;
    if (p is! int || p < 1 || p > 604 || t is! int) return null;
    if (s is int && a is int) {
      if (s < 1 || s > 114 || a < 1) return null;
      return QuranBookmark.ayah(
          surah: s, ayah: a, page: p, at: t, kind: kind);
    }
    return QuranBookmark.page(page: p, at: t, kind: kind);
  }
}

/// The four kinds of mark readers keep in a mushaf: where they are reading,
/// what they are memorising, what they are revising, and an ayah to ponder.
enum BookmarkKind { reading, hifz, review, tadabbur }

class QuranBookmarksNotifier extends StateNotifier<List<QuranBookmark>> {
  QuranBookmarksNotifier(this._prefs) : super(_restore(_prefs));

  final SharedPreferences _prefs;
  static const prefsKey = 'quran_bookmarks_v1';

  static List<QuranBookmark> _restore(SharedPreferences prefs) {
    final raw = prefs.getString(prefsKey);
    if (raw == null) return const [];
    try {
      final list = [
        for (final e in jsonDecode(raw) as List) ?QuranBookmark.fromJson(e),
      ]..sort((x, y) => y.at.compareTo(x.at));
      return List.unmodifiable(list);
    } catch (_) {
      return const [];
    }
  }

  bool hasAyah(int surah, int ayah) =>
      state.any((b) => b.surah == surah && b.ayah == ayah);

  bool hasPage(int page) => state.any((b) => !b.isAyah && b.page == page);

  Future<void> _save(List<QuranBookmark> next) async {
    next.sort((x, y) => y.at.compareTo(x.at));
    state = List.unmodifiable(next);
    await _prefs.setString(
        prefsKey, jsonEncode([for (final b in state) b.toJson()]));
  }

  /// Adds the mark, or removes it if it is there. Returns true when added.
  Future<bool> toggleAyah(int surah, int ayah, int page) async {
    final key = 'a:$surah:$ayah';
    if (state.any((b) => b.key == key)) {
      await _save([for (final b in state) if (b.key != key) b]);
      return false;
    }
    await _save([
      ...state,
      QuranBookmark.ayah(
        surah: surah,
        ayah: ayah,
        page: page,
        at: DateTime.now().millisecondsSinceEpoch,
      ),
    ]);
    return true;
  }

  Future<bool> togglePage(int page) async {
    final key = 'p:$page';
    if (state.any((b) => b.key == key)) {
      await _save([for (final b in state) if (b.key != key) b]);
      return false;
    }
    await _save([
      ...state,
      QuranBookmark.page(page: page, at: DateTime.now().millisecondsSinceEpoch),
    ]);
    return true;
  }

  Future<void> remove(QuranBookmark mark) =>
      _save([for (final b in state) if (b.key != mark.key) b]);

  /// The page's own mark, if it has one.
  QuranBookmark? pageMark(int page) =>
      state.where((b) => !b.isAyah && b.page == page).firstOrNull;

  /// Marks the page as [kind]; the same kind again removes the mark, another
  /// kind re-colours it. Returns the page's kind afterwards, or null.
  Future<BookmarkKind?> setPageKind(int page, BookmarkKind kind) async {
    final old = pageMark(page);
    final rest = [for (final b in state) if (b.key != 'p:$page') b];
    if (old != null && old.kind == kind) {
      await _save(rest);
      return null;
    }
    await _save([
      ...rest,
      QuranBookmark.page(
        page: page,
        at: old?.at ?? DateTime.now().millisecondsSinceEpoch,
        kind: kind,
      ),
    ]);
    return kind;
  }

  Future<void> clearAll() => _save([]);
}

final quranBookmarksProvider =
    StateNotifierProvider<QuranBookmarksNotifier, List<QuranBookmark>>(
  (ref) => QuranBookmarksNotifier(ref.watch(sharedPrefsProvider)),
);
