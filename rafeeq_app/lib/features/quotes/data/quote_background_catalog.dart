import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One photographic background the quote card can use, and the licence that
/// lets it.
///
/// WHERE THESE CAME FROM, AND WHAT WAS REFUSED.
/// The owner asked for «صور من النت، كمية كبيرة وجودة عالية». CLAUDE.md trap
/// #18 says a free image is not automatically free to rehost, so the source
/// had to be one whose licence can be *read*, per file, not claimed
/// site-wide. Pixabay and Pexels answer 403 without an API key; Mixkit's
/// licence text is rendered by JavaScript and could not be read at all, and
/// an unreadable licence is a no. Wikimedia Commons states every file's
/// licence machine-readably, so `scripts/fetch_quote_backgrounds.py` checks
/// each candidate one at a time and keeps **only** public-domain and CC0
/// files — CC BY and CC BY-SA are excluded on purpose, because BY wants an
/// attribution beside the image and this is a full-bleed background, and SA's
/// reach over a composited derivative is not something to guess at.
///
/// Then somebody looked at them (§1.3). Seven of the eighteen licence-clean
/// files were not backgrounds at all: paintings and photographs of people, a
/// page of an illuminated **Qur'an manuscript**, a snapshot with a wall clock
/// and plastic bags in it, and a panel of calligraphy that would fight the
/// saying set over it. `scripts/curate_quote_backgrounds.py` records every
/// rejection with its reason.
class QuoteBackground {
  final String id;
  final String licence;
  final String author;

  /// The file's page on Commons — where the licence can be checked.
  final String page;

  /// The measured contrast between the card's ink and this image's
  /// **brightest** region seen through the scrim. Not a guess: trap #15 cost
  /// three mushaf themes a contrast failure because a pairing was judged by
  /// eye, so this is computed on the shipped file and asserted by
  /// `test/quote_background_test.dart`.
  final double contrast;

  const QuoteBackground({
    required this.id,
    required this.licence,
    required this.author,
    required this.page,
    required this.contrast,
  });

  String get asset => 'assets/quote_backgrounds/$id.jpg';
}

class QuoteBackgroundSet {
  final List<QuoteBackground> images;

  /// The near-opaque layer the saying is drawn on. Every image was measured
  /// through exactly this, so the app must draw exactly this.
  final int scrimArgb;

  const QuoteBackgroundSet({required this.images, required this.scrimArgb});
}

final quoteBackgroundsProvider =
    FutureProvider<QuoteBackgroundSet>((ref) async {
  final raw =
      await rootBundle.loadString('assets/data/quote_backgrounds.json');
  final doc = jsonDecode(raw) as Map<String, dynamic>;
  final scrim = (doc['scrim'] as Map<String, dynamic>)['argb'] as String;
  return QuoteBackgroundSet(
    scrimArgb: int.parse(scrim.substring(2), radix: 16),
    images: [
      for (final e in doc['images'] as List<dynamic>)
        QuoteBackground(
          id: (e as Map<String, dynamic>)['id'] as String,
          licence: e['licence'] as String? ?? '',
          author: e['author'] as String? ?? '',
          page: e['page'] as String? ?? '',
          contrast: (e['contrast'] as num?)?.toDouble() ?? 0,
        )
    ],
  );
});
