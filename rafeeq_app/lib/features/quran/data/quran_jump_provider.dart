import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `QuranScreen` and `HomeScreen` are siblings kept alive together in
/// `AppShell`'s `IndexedStack` — there's no push/pop relationship between
/// them for a "jump to page X then switch tabs" request (e.g. a khatma
/// card's "اقرأ اليوم") to ride on the way `SearchScreen`'s `Navigator.pop`
/// does. This is that seam instead: whoever wants the reader open on a
/// specific page sets this, then switches to the Quran tab; `QuranScreen`
/// consumes it via `ref.listen` and resets it to null so it only fires once.
final quranJumpRequestProvider = StateProvider<int?>((ref) => null);
