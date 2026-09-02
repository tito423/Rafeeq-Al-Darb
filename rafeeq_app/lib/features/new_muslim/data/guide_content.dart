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
  final String titleAr;
  final String titleEn;
  final String icon; // a Material icon name key, resolved in the UI layer
  final List<GuideItem> items;

  const GuideSection({
    required this.titleAr,
    required this.titleEn,
    required this.icon,
    required this.items,
  });
}

class GuideItem {
  /// A short heading for this step/point, e.g. "الشهادتان".
  final String headingAr;
  final String headingEn;

  /// The instructional body.
  final String bodyAr;
  final String bodyEn;

  /// An Arabic phrase/dua to say at this step, shown in the Quran font —
  /// null when the item has no accompanying recitation.
  final String? phraseAr;

  const GuideItem({
    required this.headingAr,
    required this.headingEn,
    required this.bodyAr,
    required this.bodyEn,
    this.phraseAr,
  });
}

final List<GuideSection> newMuslimGuideSections = [
  GuideSection(
    titleAr: 'أركان الإسلام',
    titleEn: 'Pillars of Islam',
    icon: 'pillars',
    items: [
      const GuideItem(
        headingAr: '١. الشهادتان',
        headingEn: '1. The Two Testimonies (Shahada)',
        bodyAr: 'أن تشهد أن لا إله إلا الله وحده لا شريك له، وأن محمداً '
            'عبده ورسوله. بهاتين الشهادتين يدخل الإنسان في الإسلام، '
            'وهما أول ما يُطلب من كل مسلم أن يعتقده بقلبه وينطق به بلسانه.',
        bodyEn: 'To bear witness that there is no god but Allah alone, '
            'with no partner, and that Muhammad is His servant and '
            'messenger. These two testimonies are how a person enters '
            'Islam, believed in the heart and spoken with the tongue.',
        phraseAr: 'أَشْهَدُ أَنْ لَا إِلَهَ إِلَّا اللَّهُ، وَأَشْهَدُ '
            'أَنَّ مُحَمَّداً رَسُولُ اللَّهِ',
      ),
      const GuideItem(
        headingAr: '٢. الصلاة',
        headingEn: '2. Prayer (Salah)',
        bodyAr: 'خمس صلوات مفروضة كل يوم وليلة: الفجر، الظهر، العصر، '
            'المغرب، والعشاء، في أوقاتها المحددة. الصلاة صلة مباشرة بين '
            'العبد وربه، وهي عمود الإسلام. انظر قسم "خطوات الصلاة" في '
            'هذا الدليل.',
        bodyEn: 'Five obligatory prayers each day and night: Fajr, Dhuhr, '
            'Asr, Maghrib, and Isha, each at its fixed time. Prayer is a '
            'direct connection between the servant and their Lord, and '
            'is the pillar of Islam — see "Steps of Prayer" in this guide.',
      ),
      const GuideItem(
        headingAr: '٣. الزكاة',
        headingEn: '3. Obligatory Charity (Zakah)',
        bodyAr: 'إخراج نسبة محددة (٢.٥٪ غالباً) من المال الذي بلغ حداً '
            'معيناً (النصاب) وحال عليه عام كامل، تُصرف لأصناف محددة من '
            'المحتاجين. وهي تطهير للمال وتزكية للنفس، وليست واجبة إلا '
            'على من ملك النصاب.',
        bodyEn: "Giving a set portion (usually 2.5%) of wealth that has "
            "reached a minimum threshold (nisab) and been held for a "
            "full year, to specific categories of those in need. It "
            "purifies wealth and is only obligatory on those who meet "
            "the threshold.",
      ),
      const GuideItem(
        headingAr: '٤. صوم رمضان',
        headingEn: '4. Fasting Ramadan',
        bodyAr: 'الامتناع عن الطعام والشراب وسائر المفطرات من طلوع الفجر '
            'إلى غروب الشمس، طوال شهر رمضان من كل عام هجري. من عجز عنه '
            'لعذر شرعي (كالمرض أو السفر) له أحكام تخفيف مبيّنة في الفقه.',
        bodyEn: 'Abstaining from food, drink, and other invalidators '
            'from dawn until sunset throughout the month of Ramadan '
            'each Islamic year. Those genuinely unable (illness, '
            'travel) have well-defined concessions in Islamic law.',
      ),
      const GuideItem(
        headingAr: '٥. حج البيت',
        headingEn: '5. Pilgrimage (Hajj)',
        bodyAr: 'زيارة بيت الله الحرام بمكة لأداء مناسك محددة، مرة واحدة '
            'في العمر، لمن استطاع إليه سبيلاً (بدنياً ومالياً). وهو غير '
            'واجب على من لا يستطيع.',
        bodyEn: 'A pilgrimage to the Sacred House in Makkah to perform '
            'specific rites, once in a lifetime, for anyone physically '
            'and financially able to undertake it — not obligatory on '
            'those who cannot.',
      ),
    ],
  ),
  GuideSection(
    titleAr: 'أركان الإيمان',
    titleEn: 'Articles of Faith (Iman)',
    icon: 'faith',
    items: [
      const GuideItem(
        headingAr: '١. الإيمان بالله',
        headingEn: '1. Belief in Allah',
        bodyAr: 'الإيمان بوجود الله سبحانه وتعالى، وأنه ربّ كل شيء '
            'ومليكه وخالقه، وأنه المستحق وحده للعبادة، المتصف بصفات '
            'الكمال المنزّه عن كل نقص.',
        bodyEn: 'Belief in Allah\'s existence, that He alone is the '
            'Lord, Sovereign, and Creator of everything, that He alone '
            'deserves worship, and that He is described by attributes '
            'of perfection, free of any deficiency.',
      ),
      const GuideItem(
        headingAr: '٢. الإيمان بالملائكة',
        headingEn: '2. Belief in the Angels',
        bodyAr: 'الإيمان بأن الله خلق الملائكة من نور، وأنهم عباد '
            'مكرمون لا يعصون الله ما أمرهم، يقومون بمهام كثيرة بأمره '
            'تعالى.',
        bodyEn: 'Belief that Allah created the angels from light, that '
            'they are honored servants who never disobey Him, and that '
            'they carry out many tasks by His command.',
      ),
      const GuideItem(
        headingAr: '٣. الإيمان بالكتب',
        headingEn: '3. Belief in the Revealed Books',
        bodyAr: 'الإيمان بأن الله أنزل كتباً على رسله، منها التوراة '
            'والإنجيل والزبور، وآخرها وخاتمها القرآن الكريم، المهيمن '
            'على ما قبله والمحفوظ من التحريف.',
        bodyEn: 'Belief that Allah revealed scriptures to His messengers '
            '— including the Torah, the Gospel, and the Psalms — with '
            'the Quran as the final revelation, superseding what came '
            'before it and preserved from alteration.',
      ),
      const GuideItem(
        headingAr: '٤. الإيمان بالرسل',
        headingEn: '4. Belief in the Messengers',
        bodyAr: 'الإيمان بأن الله أرسل رسلاً لهداية البشر، من آدم إلى '
            'محمد صلى الله عليه وسلم، خاتم الأنبياء والمرسلين الذي لا '
            'نبي بعده.',
        bodyEn: 'Belief that Allah sent messengers to guide humanity, '
            'from Adam to Muhammad ﷺ, the seal of the prophets, after '
            'whom there is no other prophet.',
      ),
      const GuideItem(
        headingAr: '٥. الإيمان باليوم الآخر',
        headingEn: '5. Belief in the Last Day',
        bodyAr: 'الإيمان بالبعث بعد الموت، والحساب على الأعمال، ثم '
            'الجزاء: الجنة لمن أطاع الله، والنار لمن كفر به وعصاه.',
        bodyEn: 'Belief in resurrection after death, being held to '
            'account for one\'s deeds, and the recompense that follows: '
            'Paradise for those who obeyed Allah, the Fire for those '
            'who disbelieved and disobeyed.',
      ),
      const GuideItem(
        headingAr: '٦. الإيمان بالقدر',
        headingEn: '6. Belief in Divine Decree (Qadar)',
        bodyAr: 'الإيمان بأن الله علم كل شيء قبل وقوعه، وكتبه، وشاءه، '
            'وخلقه — خيره وشره — مع إثبات أن للإنسان اختياراً حقيقياً '
            'يُحاسَب عليه.',
        bodyEn: 'Belief that Allah knew, decreed, willed, and created '
            'everything — good and bad — before it happened, while '
            'affirming that a person still has real choice, for which '
            'they are held accountable.',
      ),
    ],
  ),
  GuideSection(
    titleAr: 'الوضوء',
    titleEn: 'Wudu (Ablution)',
    icon: 'wudu',
    items: [
      const GuideItem(
        headingAr: '١. النيّة والتسمية',
        headingEn: '1. Intention and "Bismillah"',
        bodyAr: 'ينوي بقلبه رفع الحدث للصلاة (النية محلّها القلب، لا '
            'تُنطق)، ويقول: "بسم الله".',
        bodyEn: 'Intend in the heart to purify oneself for prayer (the '
            'intention is in the heart, not spoken aloud), and say '
            '"Bismillah" (in the name of Allah).',
        phraseAr: 'بِسْمِ اللَّهِ',
      ),
      const GuideItem(
        headingAr: '٢. غسل الكفين',
        headingEn: '2. Washing the Hands',
        bodyAr: 'يغسل كفيه ثلاث مرات قبل إدخالهما في الإناء.',
        bodyEn: 'Wash both hands three times before dipping them into '
            'the water.',
      ),
      const GuideItem(
        headingAr: '٣. المضمضة والاستنشاق',
        headingEn: '3. Rinsing the Mouth and Nose',
        bodyAr: 'يتمضمض ويستنشق الماء وينثره ثلاث مرات.',
        bodyEn: 'Rinse the mouth and sniff water into the nose then '
            'expel it, three times.',
      ),
      const GuideItem(
        headingAr: '٤. غسل الوجه',
        headingEn: '4. Washing the Face',
        bodyAr: 'يغسل وجهه ثلاث مرات، من منابت الشعر إلى أسفل الذقن، '
            'ومن الأذن إلى الأذن.',
        bodyEn: 'Wash the face three times, from the hairline to below '
            'the chin, and from ear to ear.',
      ),
      const GuideItem(
        headingAr: '٥. غسل اليدين إلى المرفقين',
        headingEn: '5. Washing the Arms to the Elbows',
        bodyAr: 'يغسل يده اليمنى إلى المرفق ثلاث مرات، ثم اليسرى كذلك.',
        bodyEn: 'Wash the right arm up to and including the elbow three '
            'times, then the left arm the same way.',
      ),
      const GuideItem(
        headingAr: '٦. مسح الرأس والأذنين',
        headingEn: '6. Wiping the Head and Ears',
        bodyAr: 'يمسح رأسه كله بيديه المبلولتين مرة واحدة، من مقدمه إلى '
            'مؤخره ثم يردهما، ثم يمسح أذنيه ظاهرهما وباطنهما.',
        bodyEn: 'Wipe the whole head once with wet hands, from front to '
            'back and back to front, then wipe the ears, inside and '
            'outside.',
      ),
      const GuideItem(
        headingAr: '٧. غسل القدمين إلى الكعبين',
        headingEn: '7. Washing the Feet to the Ankles',
        bodyAr: 'يغسل قدمه اليمنى إلى الكعبين ثلاث مرات مع تخليل '
            'الأصابع، ثم اليسرى كذلك.',
        bodyEn: 'Wash the right foot up to and including the ankles '
            'three times, running water between the toes, then the '
            'left foot the same way.',
      ),
      const GuideItem(
        headingAr: '٨. الدعاء بعد الوضوء',
        headingEn: '8. The Supplication After Wudu',
        bodyAr: 'بعد إتمام الوضوء يقول الشهادتين. من قالها فُتحت له '
            'أبواب الجنة الثمانية يدخل من أيها شاء.',
        bodyEn: 'After finishing, say the two testimonies of faith. '
            'Whoever says this has all eight gates of Paradise opened '
            'for them, to enter from whichever they wish.',
        phraseAr: 'أَشْهَدُ أَنْ لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا '
            'شَرِيكَ لَهُ، وَأَشْهَدُ أَنَّ مُحَمَّداً عَبْدُهُ وَرَسُولُهُ',
      ),
    ],
  ),
  GuideSection(
    titleAr: 'خطوات الصلاة',
    titleEn: 'Steps of Prayer',
    icon: 'prayer',
    items: [
      const GuideItem(
        headingAr: '١. الاستعداد',
        headingEn: '1. Preparation',
        bodyAr: 'يتوضأ، ويستقبل القبلة، وينوي الصلاة بقلبه (بدون نطق).',
        bodyEn: 'Perform wudu, face the Qibla, and intend the specific '
            'prayer in the heart (silently, not spoken).',
      ),
      const GuideItem(
        headingAr: '٢. تكبيرة الإحرام',
        headingEn: '2. The Opening Takbeer',
        bodyAr: 'يرفع يديه ويقول "الله أكبر" ليدخل في الصلاة، ثم '
            'يضع يده اليمنى على اليسرى فوق صدره.',
        bodyEn: 'Raise the hands and say "Allahu Akbar" to enter the '
            'prayer, then place the right hand over the left on the '
            'chest.',
        phraseAr: 'اللَّهُ أَكْبَرُ',
      ),
      const GuideItem(
        headingAr: '٣. القيام والقراءة',
        headingEn: '3. Standing and Recitation',
        bodyAr: 'يقرأ سورة الفاتحة، ثم ما تيسر من القرآن في الركعتين '
            'الأوليين.',
        bodyEn: 'Recite Surah Al-Fatiha, then any portion of the Quran, '
            'in the first two rak\'ahs.',
      ),
      const GuideItem(
        headingAr: '٤. الركوع',
        headingEn: '4. Bowing (Ruku)',
        bodyAr: 'يكبّر وينحني حتى يستوي ظهره، ويضع يديه على ركبتيه، '
            'ويقول: "سبحان ربي العظيم" ثلاثاً.',
        bodyEn: 'Say the takbeer and bow until the back is level, '
            'placing the hands on the knees, saying "Subhana rabbiyal '
            '\'adheem" (Glory be to my Lord the Great) three times.',
        phraseAr: 'سُبْحَانَ رَبِّيَ الْعَظِيمِ',
      ),
      const GuideItem(
        headingAr: '٥. الرفع من الركوع',
        headingEn: '5. Rising From Bowing',
        bodyAr: 'يقول "سمع الله لمن حمده" أثناء القيام، ثم "ربنا ولك '
            'الحمد" بعد الاستواء واقفاً.',
        bodyEn: 'Say "Sami\' Allahu liman hamidah" (Allah hears whoever '
            'praises Him) while rising, then "Rabbana wa lakal hamd" '
            '(Our Lord, to You is all praise) once fully upright.',
        phraseAr: 'سَمِعَ اللَّهُ لِمَنْ حَمِدَهُ، رَبَّنَا وَلَكَ '
            'الْحَمْدُ',
      ),
      const GuideItem(
        headingAr: '٦. السجود',
        headingEn: '6. Prostration (Sujood)',
        bodyAr: 'يكبّر ويسجد على سبعة أعضاء (الجبهة مع الأنف، الكفان، '
            'الركبتان، أطراف القدمين)، ويقول: "سبحان ربي الأعلى" '
            'ثلاثاً.',
        bodyEn: 'Say the takbeer and prostrate on seven points (the '
            'forehead with the nose, both palms, both knees, the tips '
            'of the toes), saying "Subhana rabbiyal a\'la" (Glory be to '
            'my Lord the Most High) three times.',
        phraseAr: 'سُبْحَانَ رَبِّيَ الْأَعْلَى',
      ),
      const GuideItem(
        headingAr: '٧. الجلوس بين السجدتين',
        headingEn: '7. Sitting Between the Two Prostrations',
        bodyAr: 'يرفع رأسه من السجود ويجلس مطمئناً، ويقول: "رب اغفر '
            'لي"، ثم يسجد السجدة الثانية كالأولى.',
        bodyEn: 'Rise from prostration and sit calmly, saying "Rabbi '
            'ghfir li" (My Lord, forgive me), then prostrate a second '
            'time the same way.',
        phraseAr: 'رَبِّ اغْفِرْ لِي',
      ),
      const GuideItem(
        headingAr: '٨. تكرار الركعات',
        headingEn: '8. Repeating for Remaining Rak\'ahs',
        bodyAr: 'يقوم للركعة التالية ويكرر ما سبق، بحسب عدد ركعات '
            'الصلاة (٢ للفجر، ٤ للظهر والعصر والعشاء، ٣ للمغرب).',
        bodyEn: 'Stand for the next rak\'ah and repeat the same '
            'sequence, according to how many rak\'ahs that prayer has '
            '(2 for Fajr, 4 for Dhuhr/Asr/Isha, 3 for Maghrib).',
      ),
      const GuideItem(
        headingAr: '٩. التشهد',
        headingEn: '9. The Tashahhud',
        bodyAr: 'يجلس بعد الركعة الثانية (وفي آخر الصلاة) ويقرأ '
            'التشهد، ويصلي على النبي صلى الله عليه وسلم.',
        bodyEn: 'Sit after the second rak\'ah (and at the end of the '
            'prayer) and recite the Tashahhud, then send blessings '
            'upon the Prophet ﷺ.',
        phraseAr: 'التَّحِيَّاتُ لِلَّهِ وَالصَّلَوَاتُ وَالطَّيِّبَاتُ، '
            'السَّلَامُ عَلَيْكَ أَيُّهَا النَّبِيُّ وَرَحْمَةُ اللَّهِ '
            'وَبَرَكَاتُهُ، السَّلَامُ عَلَيْنَا وَعَلَى عِبَادِ اللَّهِ '
            'الصَّالِحِينَ، أَشْهَدُ أَنْ لَا إِلَهَ إِلَّا اللَّهُ '
            'وَأَشْهَدُ أَنَّ مُحَمَّداً عَبْدُهُ وَرَسُولُهُ',
      ),
      const GuideItem(
        headingAr: '١٠. التسليم',
        headingEn: '10. The Closing Salam',
        bodyAr: 'يختم الصلاة بالتسليم عن يمينه ثم عن يساره.',
        bodyEn: 'End the prayer by turning the head to say the salam '
            'to the right, then to the left.',
        phraseAr: 'السَّلَامُ عَلَيْكُمْ وَرَحْمَةُ اللَّهِ',
      ),
    ],
  ),
  GuideSection(
    titleAr: 'مقدمة في القرآن',
    titleEn: 'Introduction to the Quran',
    icon: 'quran',
    items: [
      const GuideItem(
        headingAr: 'ما هو القرآن؟',
        headingEn: 'What Is the Quran?',
        bodyAr: 'القرآن الكريم هو كلام الله المنزّل على النبي محمد صلى '
            'الله عليه وسلم بواسطة الملَك جبريل عليه السلام، وهو محفوظ '
            'من التحريف، ويُتعبَّد بتلاوته.',
        bodyEn: 'The Quran is the literal word of Allah, revealed to '
            'the Prophet Muhammad ﷺ through the angel Gabriel, '
            'preserved from any alteration, and its recitation is '
            'itself an act of worship.',
      ),
      const GuideItem(
        headingAr: 'كيف هو منظّم؟',
        headingEn: 'How Is It Organized?',
        bodyAr: 'ينقسم إلى ١١٤ سورة، مكية (نزلت قبل الهجرة) ومدنية '
            '(نزلت بعدها)، ويقسّم أيضاً إلى ٣٠ جزءاً لتيسير ختمه على مدار '
            'الشهر.',
        bodyEn: 'It is divided into 114 surahs (chapters) — Meccan '
            '(revealed before the migration to Medina) or Medinan '
            '(after) — and also into 30 equal parts (juz\') to make '
            'completing it over a month easier.',
      ),
      const GuideItem(
        headingAr: 'من أين أبدأ؟',
        headingEn: 'Where to Start',
        bodyAr: 'يبدأ كثير من المسلمين الجدد بحفظ سورة الفاتحة (تُقرأ '
            'في كل ركعة) وقصار السور في آخر جزء من القرآن (جزء عمّ)، '
            'ثم يتدرج في القراءة والفهم. تجد كل ذلك في تبويب "القرآن" '
            'من هذا التطبيق، بالنص والتلاوة وترجمة المعنى.',
        bodyEn: 'Many new Muslims begin by memorizing Surah Al-Fatiha '
            '(recited in every unit of prayer) and the short surahs in '
            'the Quran\'s final section (Juz \'Amma), then progress from '
            'there. This app\'s "Quran" tab has the full text, real '
            'recitation, and translated meaning to help with that.',
      ),
    ],
  ),
];
