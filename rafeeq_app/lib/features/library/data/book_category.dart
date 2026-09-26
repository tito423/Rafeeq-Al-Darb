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
  adab,

  /// طالب العلم — the graduated shelf: how to study, then the tools to study
  /// WITH (مصطلح الحديث، أصول الفقه، علوم القرآن، النحو), in the order they
  /// are traditionally taken.
  ///
  /// Asked for on 2026-09-17: «تزودلي في المكتبة قسم وتسميه طالب العلم …
  /// الكتب المتدرجة اللي تعلم طالب العلم الشرعي المنهج الوسطي المعتدل بتدرج».
  /// Every book on it is a classical one whose author died centuries ago —
  /// deliberately, because the modern manuals of «طلب العلم» are exactly the
  /// literature he asked to keep away from.
  talibIlm,

  /// Books the reader imported from al-Maktaba al-Shamela inside the app
  /// (GitHub build only; `ShamelaLibrary`).
  shamela;

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
        BookCategory.talibIlm => Icons.school_outlined,
        BookCategory.shamela => Icons.cloud_download_outlined,
      };
}
