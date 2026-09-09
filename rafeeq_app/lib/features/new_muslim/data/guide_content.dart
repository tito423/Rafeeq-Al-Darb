/// Real, standard Sunni instructional content for the New Muslim Guide
/// (WORK_QUEUE Stage 5) — the five topics WORK_QUEUE names: pillars of
/// Islam, wudu, prayer steps, faith (iman), and a Quran introduction.
///
/// This is not "app content" pulled from a database like the Quran/azkar/
/// hadith text is — it's written directly here, per the owner's explicit
/// instruction to use known, mainstream, trusted Islamic sources rather
/// than inventing anything or scraping a specific site. Every fact below
/// (the five pillars, the six articles of faith, the wudu sequence, the
/// prayer structure) is universally agreed-upon core Sunni teaching taught
/// identically by essentially every mainstream Islamic source — nothing
/// here reflects a specific scholar's disputed opinion.
///
/// Bilingual by hand (not through easy_localization's UI-chrome key system)
/// for the same reason the Quran text stays Arabic regardless of UI
/// language: this is religious content, not app chrome.
class GuideSection {
  /// An i18n key — `guide.<section>_title`, present in all seven locales.
  final String titleKey;
  final String icon; // a Material icon name key, resolved in the UI layer
  final List<GuideItem> items;

  const GuideSection({
    required this.titleKey,
    required this.icon,
    required this.items,
  });
}

class GuideItem {
  /// A short heading for this step/point — an i18n key.
  final String headingKey;

  /// The instructional body — an i18n key.
  final String bodyKey;

  /// An Arabic phrase/dua to say at this step, shown in the Quran font —
  /// null when the item has no accompanying recitation.
  ///
  /// **Not** a key, and deliberately so: this is what the reader says, set in
  /// the Quran font and fully vowelled. It stays Arabic for the same reason an
  /// ayah on a mushaf page does (CLAUDE.md §1.2).
  final String? phraseAr;

  const GuideItem({
    required this.headingKey,
    required this.bodyKey,
    this.phraseAr,
  });
}

final List<GuideSection> newMuslimGuideSections = [
  GuideSection(
    titleKey: 'guide.pillars_title',
    icon: 'pillars',
    items: [
      const GuideItem(
        headingKey: 'guide.pillars_1_h',
        bodyKey: 'guide.pillars_1_b',
        phraseAr: 'أَشْهَدُ أَنْ لَا إِلَهَ إِلَّا اللَّهُ، وَأَشْهَدُ '
            'أَنَّ مُحَمَّداً رَسُولُ اللَّهِ',
      ),
      const GuideItem(
        headingKey: 'guide.pillars_2_h',
        bodyKey: 'guide.pillars_2_b',
      ),
      const GuideItem(
        headingKey: 'guide.pillars_3_h',
        bodyKey: 'guide.pillars_3_b',
      ),
      const GuideItem(
        headingKey: 'guide.pillars_4_h',
        bodyKey: 'guide.pillars_4_b',
      ),
      const GuideItem(
        headingKey: 'guide.pillars_5_h',
        bodyKey: 'guide.pillars_5_b',
      ),
    ],
  ),
  GuideSection(
    titleKey: 'guide.iman_title',
    icon: 'faith',
    items: [
      const GuideItem(
        headingKey: 'guide.iman_1_h',
        bodyKey: 'guide.iman_1_b',
      ),
      const GuideItem(
        headingKey: 'guide.iman_2_h',
        bodyKey: 'guide.iman_2_b',
      ),
      const GuideItem(
        headingKey: 'guide.iman_3_h',
        bodyKey: 'guide.iman_3_b',
      ),
      const GuideItem(
        headingKey: 'guide.iman_4_h',
        bodyKey: 'guide.iman_4_b',
      ),
      const GuideItem(
        headingKey: 'guide.iman_5_h',
        bodyKey: 'guide.iman_5_b',
      ),
      const GuideItem(
        headingKey: 'guide.iman_6_h',
        bodyKey: 'guide.iman_6_b',
      ),
    ],
  ),
  GuideSection(
    titleKey: 'guide.wudu_title',
    icon: 'wudu',
    items: [
      const GuideItem(
        headingKey: 'guide.wudu_1_h',
        bodyKey: 'guide.wudu_1_b',
        phraseAr: 'بِسْمِ اللَّهِ',
      ),
      const GuideItem(
        headingKey: 'guide.wudu_2_h',
        bodyKey: 'guide.wudu_2_b',
      ),
      const GuideItem(
        headingKey: 'guide.wudu_3_h',
        bodyKey: 'guide.wudu_3_b',
      ),
      const GuideItem(
        headingKey: 'guide.wudu_4_h',
        bodyKey: 'guide.wudu_4_b',
      ),
      const GuideItem(
        headingKey: 'guide.wudu_5_h',
        bodyKey: 'guide.wudu_5_b',
      ),
      const GuideItem(
        headingKey: 'guide.wudu_6_h',
        bodyKey: 'guide.wudu_6_b',
      ),
      const GuideItem(
        headingKey: 'guide.wudu_7_h',
        bodyKey: 'guide.wudu_7_b',
      ),
      const GuideItem(
        headingKey: 'guide.wudu_8_h',
        bodyKey: 'guide.wudu_8_b',
        phraseAr: 'أَشْهَدُ أَنْ لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا '
            'شَرِيكَ لَهُ، وَأَشْهَدُ أَنَّ مُحَمَّداً عَبْدُهُ وَرَسُولُهُ',
      ),
    ],
  ),
  GuideSection(
    titleKey: 'guide.prayer_title',
    icon: 'prayer',
    items: [
      const GuideItem(
        headingKey: 'guide.prayer_1_h',
        bodyKey: 'guide.prayer_1_b',
      ),
      const GuideItem(
        headingKey: 'guide.prayer_2_h',
        bodyKey: 'guide.prayer_2_b',
        phraseAr: 'اللَّهُ أَكْبَرُ',
      ),
      const GuideItem(
        headingKey: 'guide.prayer_3_h',
        bodyKey: 'guide.prayer_3_b',
      ),
      const GuideItem(
        headingKey: 'guide.prayer_4_h',
        bodyKey: 'guide.prayer_4_b',
        phraseAr: 'سُبْحَانَ رَبِّيَ الْعَظِيمِ',
      ),
      const GuideItem(
        headingKey: 'guide.prayer_5_h',
        bodyKey: 'guide.prayer_5_b',
        phraseAr: 'سَمِعَ اللَّهُ لِمَنْ حَمِدَهُ، رَبَّنَا وَلَكَ '
            'الْحَمْدُ',
      ),
      const GuideItem(
        headingKey: 'guide.prayer_6_h',
        bodyKey: 'guide.prayer_6_b',
        phraseAr: 'سُبْحَانَ رَبِّيَ الْأَعْلَى',
      ),
      const GuideItem(
        headingKey: 'guide.prayer_7_h',
        bodyKey: 'guide.prayer_7_b',
        phraseAr: 'رَبِّ اغْفِرْ لِي',
      ),
      const GuideItem(
        headingKey: 'guide.prayer_8_h',
        bodyKey: 'guide.prayer_8_b',
      ),
      const GuideItem(
        headingKey: 'guide.prayer_9_h',
        bodyKey: 'guide.prayer_9_b',
        phraseAr: 'التَّحِيَّاتُ لِلَّهِ وَالصَّلَوَاتُ وَالطَّيِّبَاتُ، '
            'السَّلَامُ عَلَيْكَ أَيُّهَا النَّبِيُّ وَرَحْمَةُ اللَّهِ '
            'وَبَرَكَاتُهُ، السَّلَامُ عَلَيْنَا وَعَلَى عِبَادِ اللَّهِ '
            'الصَّالِحِينَ، أَشْهَدُ أَنْ لَا إِلَهَ إِلَّا اللَّهُ '
            'وَأَشْهَدُ أَنَّ مُحَمَّداً عَبْدُهُ وَرَسُولُهُ',
      ),
      const GuideItem(
        headingKey: 'guide.prayer_10_h',
        bodyKey: 'guide.prayer_10_b',
        phraseAr: 'السَّلَامُ عَلَيْكُمْ وَرَحْمَةُ اللَّهِ',
      ),
    ],
  ),
  GuideSection(
    titleKey: 'guide.quran_title',
    icon: 'quran',
    items: [
      const GuideItem(
        headingKey: 'guide.quran_1_h',
        bodyKey: 'guide.quran_1_b',
      ),
      const GuideItem(
        headingKey: 'guide.quran_2_h',
        bodyKey: 'guide.quran_2_b',
      ),
      const GuideItem(
        headingKey: 'guide.quran_3_h',
        bodyKey: 'guide.quran_3_b',
      ),
    ],
  ),
];
