import 'package:flutter/material.dart';

/// Classification for a library book. The label is a translation key so the
/// "التصنيفات" tab and the per-book category line work in every locale.
enum BookCategory {
  hadith,
  fiqh,
  aqidah,
  tafsir,
  seerah,

  /// التاريخ — the history of the Muslims and of their lands, as
  /// distinct from السيرة, which is the Prophet's own life. البداية والنهاية
  /// spans both, and it is filed here because thirteen of its fourteen volumes
  /// are what happened after him.
  tarikh,

  tazkiyah,
  adab;

  String get labelKey => 'library.cat_$name';

  IconData get icon => switch (this) {
        BookCategory.hadith => Icons.menu_book_outlined,
        BookCategory.fiqh => Icons.balance_outlined,
        BookCategory.aqidah => Icons.brightness_7_outlined,
        BookCategory.tafsir => Icons.auto_stories_outlined,
        BookCategory.seerah => Icons.history_edu_outlined,
        BookCategory.tarikh => Icons.account_balance_outlined,
        BookCategory.tazkiyah => Icons.spa_outlined,
        BookCategory.adab => Icons.favorite_outline,
      };
}
