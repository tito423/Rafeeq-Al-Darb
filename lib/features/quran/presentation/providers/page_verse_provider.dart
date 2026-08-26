import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

// ── Verse Info Model ──────────────────────────────────────────────────────────

class VerseInfo {
  final String verseKey;       // e.g. "2:255"
  final int surahNumber;
  final int verseNumber;
  final String textUthmani;    // Arabic text
  final int lineNumber;        // which line on the page (1-based)
  final String translation;    // English translation

  const VerseInfo({
    required this.verseKey,
    required this.surahNumber,
    required this.verseNumber,
    required this.textUthmani,
    required this.lineNumber,
    required this.translation,
  });
}

/// Maps each line number on a mushaf page to its verse info.
/// Returned from the provider below.
class PageVerseMap {
  /// lineNumber → VerseInfo
  final Map<int, VerseInfo> lineToVerse;

  /// All distinct verses on this page, in order
  final List<VerseInfo> verses;

  const PageVerseMap({required this.lineToVerse, required this.verses});
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// Fetches verse-line mapping for a given [pageNumber] from quran.com API.
/// Returns a [PageVerseMap] so the UI can highlight a line when tapped.
final pageVerseMapProvider =
    FutureProvider.family<PageVerseMap, int>((ref, pageNumber) async {
  // Standard Mushaf: 15 lines per page (lines 1 & 15 are Surah headers / decoration on some pages)
  final url = Uri.parse(
    'https://api.quran.com/api/v4/verses/by_page/$pageNumber'
    '?words=true'
    '&word_fields=text_uthmani,line_number,page_number'
    '&fields=text_uthmani,verse_number,hizb_number'
    '&translations=131'  // 131 = Sahih International (English)
    '&per_page=50',
  );

  try {
    final response = await http.get(url, headers: {
      'Accept': 'application/json',
    });

    if (response.statusCode != 200) {
      return const PageVerseMap(lineToVerse: {}, verses: []);
    }

    final Map<String, dynamic> json = jsonDecode(response.body);
    final List<dynamic> versesJson = json['verses'] as List<dynamic>? ?? [];

    final Map<int, VerseInfo> lineToVerse = {};
    final List<VerseInfo> verses = [];

    for (final vJson in versesJson) {
      final verseKey = vJson['verse_key'] as String? ?? '';
      final parts = verseKey.split(':');
      final surahNum = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
      final verseNum = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
      final textUthmani = vJson['text_uthmani'] as String? ?? '';

      // Get translation
      String translation = '';
      final translations = vJson['translations'] as List<dynamic>?;
      if (translations != null && translations.isNotEmpty) {
        final rawTrans = translations[0]['text'] as String? ?? '';
        // Strip HTML tags if present
        translation = rawTrans.replaceAll(RegExp(r'<[^>]*>'), '');
      }

      // Find the first line_number from words
      int firstLine = 0;
      final Set<int> verseLinesOnPage = {};
      final words = vJson['words'] as List<dynamic>? ?? [];
      for (final word in words) {
        final wordPage = word['page_number'] as int? ?? 0;
        if (wordPage == pageNumber) {
          final lineNum = word['line_number'] as int? ?? 0;
          if (lineNum > 0) {
            verseLinesOnPage.add(lineNum);
            if (firstLine == 0) firstLine = lineNum;
          }
        }
      }

      if (firstLine == 0) continue; // verse not on this page

      final verseInfo = VerseInfo(
        verseKey: verseKey,
        surahNumber: surahNum,
        verseNumber: verseNum,
        textUthmani: textUthmani,
        lineNumber: firstLine,
        translation: translation,
      );

      verses.add(verseInfo);

      // Map all lines occupied by this verse to its info
      for (final line in verseLinesOnPage) {
        lineToVerse[line] = verseInfo;
      }
    }

    return PageVerseMap(lineToVerse: lineToVerse, verses: verses);
  } catch (_) {
    return const PageVerseMap(lineToVerse: {}, verses: []);
  }
});
