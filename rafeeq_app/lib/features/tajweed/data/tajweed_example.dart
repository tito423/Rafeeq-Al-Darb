/// Where a tajweed rule can actually be heard in the Qur'an.
///
/// Lifted out of `tajweed_course.dart` so it can outlive it. That file carries
/// the lesson ranges of «تيسير أحكام التجويد» — a book by a living author
/// published by a commercial house — and it is being retired for that reason.
/// These twelve pointers are not from it and never were: a surah and an ayah
/// number are facts, the phrase is the Qur'an, and the one-line «what to listen
/// for» is the app's own wording. Nothing here belongs to anyone but the
/// Revelation and us.
library;

/// The place in the Qur'an where a rule occurs.
class TajweedExample {
  final int surah;
  final int ayah;

  /// The words inside that ayah the rule happens in — shown beside the button
  /// so the eye lands on it while the ear hears it.
  final String phrase;

  /// What to listen for, in one line. A pointer, not a ruling: the ruling is
  /// the matn's, and the matn is printed above it.
  final String listenKey;

  const TajweedExample({
    required this.surah,
    required this.ayah,
    required this.phrase,
    required this.listenKey,
  });
}
