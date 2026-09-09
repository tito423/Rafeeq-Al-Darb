import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../../app/navigation.dart';
import '../data/quote_repository.dart';
import 'quote_card_screen.dart';

/// Opens the quote card from a notification payload (`bookIndex:quoteIndex`).
///
/// Mirrors `openSunanSuwarFromPayload`: called from a notification callback
/// with no `BuildContext` and no `WidgetRef`, so it reads the bundled asset
/// directly rather than going through `quoteLibraryProvider`. That is also
/// why it must not throw — a malformed or stale payload closes quietly rather
/// than crashing the app on a tap.
///
/// The payload is what makes the card show **the saying the notification
/// showed**. Picking a fresh random one on open would mean the sentence a
/// reader tapped is gone the moment they act on it.
Future<void> openQuoteFromPayload(String rawPayload) async {
  final navigator = rootNavigatorKey.currentState;
  if (navigator == null) return;
  try {
    final raw = await rootBundle.loadString('assets/data/quotes.json');
    final doc = jsonDecode(raw) as Map<String, dynamic>;
    final library = QuoteLibrary([
      for (final b in doc['books'] as List<dynamic>)
        QuoteBook(
          id: (b as Map<String, dynamic>)['id'] as String,
          titleAr: b['titleAr'] as String? ?? '',
          authorAr: b['authorAr'] as String? ?? '',
          sourceLabel: b['sourceLabel'] as String? ?? '',
          quotes: [
            for (final q in b['quotes'] as List<dynamic>)
              (
                text: (q as Map<String, dynamic>)['t'] as String,
                page: q['p'] as int? ?? 0,
              )
          ],
        )
    ]);
    final quote = library.byKey(rawPayload);
    if (quote == null) return;
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => QuoteCardScreen(quote: quote),
      ),
    );
  } catch (_) {
    // A tap that cannot find its quote does nothing. It does not crash.
  }
}
