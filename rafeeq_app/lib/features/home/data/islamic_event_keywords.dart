/// Which of a day's events touch Islam and the Muslims.
///
/// «ويعرض اهم الاحداث اللي حصلت فيه قبل كدة من التاريخ خاصة اللي يخص الاسلام
/// والمسلمين» — so the Gregorian day sheet leads with those and puts the rest
/// under «أحداث أخرى».
///
/// **This orders a sourced list; it does not write one.** Every line still
/// comes from Wikipedia verbatim and nothing is dropped — a line that matches
/// nothing here simply reads further down the sheet.
///
/// The match runs on the language the rows are actually IN, which is not
/// always the reader's: the Gregorian feed ships in Arabic and English only, so
/// a French reader is served the English rows and it is the English list that
/// has to match them. `OnThisDay.lang` carries that.
library;

/// Arabic markers.
///
/// «الحرم» and «الجامع» are deliberately absent. A substring match on them
/// files «البابا ليون العاشر ينزل **الحرمان** الكنسي بحق مارتن لوثر» under
/// «ما يخصّ الإسلام والمسلمين», and every **جامعة** in the world with it —
/// seen in the real dataset, not imagined. The three unambiguous forms are
/// listed instead.
const islamicWordsAr = <String>[
  'إسلام', 'الإسلام', 'مسلم', 'المسلم', 'مسلمين', 'المسلمون', 'القرآن',
  'النبي', 'الرسول', 'محمد', 'الصحاب', 'خليفة', 'الخليفة', 'خلافة', 'الخلافة',
  'مكة', 'المدينة المنورة', 'القدس', 'الأقصى', 'الكعبة', 'مسجد',
  'المسجد الحرام', 'الحرم المكي', 'الحرم النبوي',
  'غزوة', 'الفتح الإسلامي', 'الأندلس', 'العثماني', 'العثمانية',
  'الأموي', 'العباسي', 'الفاطمي', 'الأيوبي', 'المملوكي', 'السلجوقي',
  'صلاح الدين', 'العرب', 'عربي', 'الحج', 'رمضان', 'الشريعة', 'الأزهر',
];

/// English markers, matched against a lower-cased line.
const islamicWordsEn = <String>[
  'islam', 'muslim', 'quran', "qur'an", 'koran', 'caliph', 'caliphate',
  'ottoman', 'umayyad', 'abbasid', 'fatimid', 'ayyubid', 'mamluk', 'seljuk',
  'mecca', 'makkah', 'medina', 'jerusalem', 'al-aqsa', 'kaaba', 'mosque',
  'saladin', 'arab', 'ramadan', 'hajj', 'sharia', 'sultan', 'moorish',
  'al-andalus', 'andalusia', 'prophet muhammad', 'muhammad',
];

/// True when [text], written in [lang], names something Islamic.
bool concernsIslam(String text, String lang) {
  final words = lang == 'ar' ? islamicWordsAr : islamicWordsEn;
  final hay = lang == 'ar' ? text : text.toLowerCase();
  for (final w in words) {
    if (hay.contains(w)) return true;
  }
  return false;
}
