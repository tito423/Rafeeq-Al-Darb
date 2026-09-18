/// «تذكير بالتسابيح متنوع ومتعدد على مدار اليوم مع ذكر الحديث الذي يرغّب في
/// التسبيح المعروض».
///
/// Each reminder names a dhikr and quotes the hadith that encourages it. The
/// quotes are CUT, never typed: `scripts` sliced each one out of `hadith.db`
/// between two anchor phrases (whitespace collapsed, every letter and mark
/// kept), and `test/tasbih_items_test.dart` fails if any stops being a
/// substring of the numbered hadith it names. Bukhari and Muslim are cited by
/// book, as the app cites the Sahihayn everywhere; a hadith the database
/// grades weak was left out — «من قال سبحان الله العظيم وبحمده غُرست له نخلة
/// في الجنة» is at-Tirmidhi 3548–3549, graded Da'if, and is not here.
class TasbihItem {
  /// Also the translation key suffix for the dhikr's title: `tasbih.t_<key>`.
  final String key;
  final String citationKey;
  final String text;

  /// The hadith quoted, as `hadith.db` numbers it.
  final String bookKey;
  final int number;

  const TasbihItem({
    required this.key,
    required this.citationKey,
    required this.text,
    required this.bookKey,
    required this.number,
  });

  String get titleKey => 'tasbih.t_$key';
}

const tasbihItems = <TasbihItem>[
  TasbihItem(
    key: 'subhan_100',
    citationKey: 'tasbih.cite_both',
    text: 'مَنْ قَالَ سُبْحَانَ اللَّهِ وَبِحَمْدِهِ‏.‏ فِي يَوْمٍ مِائَةَ مَرَّةٍ حُطَّتْ خَطَايَاهُ، وَإِنْ كَانَتْ مِثْلَ زَبَدِ الْبَحْرِ',
    bookKey: 'bukhari',
    number: 6166,
  ),
  TasbihItem(
    key: 'tahlil_100',
    citationKey: 'tasbih.cite_both',
    text: 'مَنْ قَالَ لاَ إِلَهَ إِلاَّ اللَّهُ، وَحْدَهُ لاَ شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، وَهْوَ عَلَى كُلِّ شَىْءٍ قَدِيرٌ‏.‏ فِي يَوْمٍ مِائَةَ مَرَّةٍ، كَانَتْ لَهُ عَدْلَ عَشْرِ رِقَابٍ، وَكُتِبَ لَهُ مِائَةُ حَسَنَةٍ، وَمُحِيَتْ عَنْهُ مِائَةُ سَيِّئَةٍ، وَكَانَتْ لَهُ حِرْزًا مِنَ الشَّيْطَانِ يَوْمَهُ ذَلِكَ، حَتَّى يُمْسِيَ، وَلَمْ يَأْتِ أَحَدٌ بِأَفْضَلَ مِمَّا جَاءَ بِهِ إِلاَّ رَجُلٌ عَمِلَ أَكْثَرَ مِنْهُ',
    bookKey: 'bukhari',
    number: 6164,
  ),
  TasbihItem(
    key: 'two_words',
    citationKey: 'tasbih.cite_both',
    text: 'كَلِمَتَانِ خَفِيفَتَانِ عَلَى اللِّسَانِ، ثَقِيلَتَانِ فِي الْمِيزَانِ، حَبِيبَتَانِ إِلَى الرَّحْمَنِ، سُبْحَانَ اللَّهِ الْعَظِيمِ، سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
    bookKey: 'bukhari',
    number: 6167,
  ),
  TasbihItem(
    key: 'four_words',
    citationKey: 'tasbih.cite_muslim',
    text: 'أَحَبُّ الْكَلاَمِ إِلَى اللَّهِ أَرْبَعٌ سُبْحَانَ اللَّهِ وَالْحَمْدُ لِلَّهِ وَلاَ إِلَهَ إِلاَّ اللَّهُ وَاللَّهُ أَكْبَرُ‏.‏ لاَ يَضُرُّكَ بَأَيِّهِنَّ بَدَأْتَ',
    bookKey: 'muslim',
    number: 5455,
  ),
  TasbihItem(
    key: 'hawqala',
    citationKey: 'tasbih.cite_both',
    text: 'أَلاَ أَدُلُّكَ عَلَى كَلِمَةٍ مِنْ كَنْزٍ مِنْ كُنُوزِ الْجَنَّةِ ‏"‏‏.‏ قُلْتُ بَلَى يَا رَسُولَ اللَّهِ فِدَاكَ أَبِي وَأُمِّي‏.‏ قَالَ ‏"‏ لاَ حَوْلَ وَلاَ قُوَّةَ إِلاَّ بِاللَّهِ',
    bookKey: 'bukhari',
    number: 4029,
  ),
  TasbihItem(
    key: 'thousand',
    citationKey: 'tasbih.cite_muslim',
    text: 'أَيَعْجِزُ أَحَدُكُمْ أَنْ يَكْسِبَ كُلَّ يَوْمٍ أَلْفَ حَسَنَةٍ ‏"‏ ‏.‏ فَسَأَلَهُ سَائِلٌ مِنْ جُلَسَائِهِ كَيْفَ يَكْسِبُ أَحَدُنَا أَلْفَ حَسَنَةٍ قَالَ ‏"‏ يُسَبِّحُ مِائَةَ تَسْبِيحَةٍ فَيُكْتَبُ لَهُ أَلْفُ حَسَنَةٍ أَوْ يُحَطُّ عَنْهُ أَلْفُ خَطِيئَةٍ',
    bookKey: 'muslim',
    number: 6686,
  ),
  TasbihItem(
    key: 'istighfar',
    citationKey: 'tasbih.cite_bukhari',
    text: 'وَاللَّهِ إِنِّي لأَسْتَغْفِرُ اللَّهَ وَأَتُوبُ إِلَيْهِ فِي الْيَوْمِ أَكْثَرَ مِنْ سَبْعِينَ مَرَّةً',
    bookKey: 'bukhari',
    number: 6070,
  ),
  TasbihItem(
    key: 'mufarridun',
    citationKey: 'tasbih.cite_muslim',
    text: 'سَبَقَ الْمُفَرِّدُونَ ‏"‏ ‏.‏ قَالُوا وَمَا الْمُفَرِّدُونَ يَا رَسُولَ اللَّهِ قَالَ ‏"‏ الذَّاكِرُونَ اللَّهَ كَثِيرًا وَالذَّاكِرَاتُ',
    bookKey: 'muslim',
    number: 6643,
  ),
];
