import 'package:flutter/material.dart';

import '../../../app/navigation.dart';
import 'single_surah_screen.dart';

/// Pushes the locked single-surah reader from a reminder notification's
/// payload (the surah id as a plain string) — mirrors
/// `adhan_navigation.dart`'s `openAdhanFromPayload`, called from the same
/// kind of no-`BuildContext` native callback.
void openSunanSuwarFromPayload(String rawPayload) {
  final surahId = int.tryParse(rawPayload);
  if (surahId == null) return;
  final navigator = rootNavigatorKey.currentState;
  if (navigator == null) return;
  navigator.push(
    MaterialPageRoute<void>(
      builder: (_) => SingleSurahScreen(surahId: surahId),
    ),
  );
}
