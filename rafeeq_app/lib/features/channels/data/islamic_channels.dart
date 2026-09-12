import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';

/// One Islamic YouTube channel.
///
/// Every field here was read off the channel's own page by
/// `scripts/verify_youtube_channels.py` before it was written down — the
/// channel id, the handle and the avatar all came back from YouTube itself.
/// That script exists because a web search for any of these names returns
/// three or four channels each described as "the official one", and a search
/// snippet is not evidence. One guessed handle (`@MostafaAladwyOfficial`) was
/// tried and answered **404**, which is exactly the check working.
class IslamicChannel {
  final String id;

  /// The channel's own title, as YouTube reports it — not a tidied-up version.
  final String nameAr;
  final String nameEn;

  /// One line on who this is — factual and short, no praise and no claims
  /// about anyone's standing. It lives in the locale files under
  /// `channels.desc_<id>`, in all seven languages; it used to be an Arabic and
  /// an English field, and everything that was neither got the English.
  String get descriptionKey => 'channels.desc_$id';

  /// YouTube's own `UC…` id. This, not the handle, is what identifies a
  /// channel permanently — a handle can be changed by its owner.
  final String channelId;

  /// The `@handle`, where the channel has one. Empty is normal.
  final String handle;

  /// Whether this channel has a picture of its own, or YouTube's generated
  /// letter tile.
  ///
  /// Five of the nine channels merged in from the Library tab answer with a
  /// default tile — a single white letter on a flat colour, generated from
  /// the channel's name (`A` for Amgad and for Ayman, `H` for Hassan and for
  /// Haytham, `f` for fahem). Checked twice on each: `og:image` and the
  /// `avatar` block inside `ytInitialData` return the **same** URL, so that
  /// really is their avatar and not a scraping mistake — which is what it was
  /// the first time this happened (`samir_mostafa`, whose real logo was only
  /// in `og:image`).
  ///
  /// A letter tile mirrored onto the bucket would be bytes that say nothing,
  /// so those five are not mirrored at all and the card draws [icon] on
  /// [color] instead. Declining to re-host a placeholder is not the same as
  /// inventing one.
  final bool hasPhoto;

  /// Drawn when [hasPhoto] is false, and while a real avatar is loading.
  final IconData icon;
  final Color color;

  const IslamicChannel({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.channelId,
    required this.icon,
    required this.color,
    this.handle = '',
    this.hasPhoto = true,
  });

  /// Opened in the browser or the YouTube app. Built from [channelId] rather
  /// than the handle so it keeps working if the handle changes.
  String get url => 'https://www.youtube.com/channel/$channelId';

  /// The avatar, mirrored onto the project's bucket at 480px.
  ///
  /// Not hot-linked from googleusercontent: the app is offline-first, and the
  /// grid should not be a page of grey squares with the network off. The
  /// mirrored copies were verified byte-exact by
  /// `scripts/r2_upload_channel_avatars.py`.
  String get avatarUrl => '${AppConfig.contentBaseUrl}/channels/$id.jpg';
}

/// The channels the owner asked for, plus the three scholars whose books he
/// asked for in the same message — they belong in the same list.
///
/// This is a **link list**, not a feed: the app opens the channel in YouTube
/// and does not scrape, re-host or embed anyone's video content.
const islamicChannels = <IslamicChannel>[
  IslamicChannel(
    id: 'mostafa_mahmoud',
    nameAr: 'القناة الرسمية للدكتور مصطفى محمود',
    nameEn: 'Dr. Mostafa Mahmoud — Official',
    channelId: 'UCG6tWYl5Zb490PkSAjE2iRg',
    icon: Icons.science,
    color: Color(0xFF00695C),
    handle: 'DRMoustafaMahmoud',
  ),
  IslamicChannel(
    id: 'ayman_abdelgelil',
    nameAr: 'الشيخ أيمن عبد الجليل',
    nameEn: 'Sheikh Ayman Abdel Gelil',
    channelId: 'UC-hKhCAfM5HXbqqfKvcviEA',
    icon: Icons.record_voice_over,
    color: Color(0xFF4E342E),
    handle: 'ayman_abdelgelil',
  ),
  IslamicChannel(
    id: 'abdullah_rushdy',
    nameAr: 'الشيخ عبد الله رشدي',
    nameEn: 'Sheikh Abdullah Rushdy',
    channelId: 'UCUZOB_l7pZZd0ZjuAbl-tGg',
    icon: Icons.forum,
    color: Color(0xFF37474F),
    handle: 'abdullah.rushdy',
  ),
  IslamicChannel(
    id: 'yasser_alhazimi',
    nameAr: 'الدكتور ياسر الحزيمي',
    nameEn: 'Dr. Yasser Al-Hazimi',
    channelId: 'UC5Tdzct1NlgjX1CsmnGuWGg',
    icon: Icons.self_improvement,
    color: Color(0xFF5D4037),
    handle: 'ybh_1000',
  ),
  IslamicChannel(
    id: 'mohamed_hassan',
    nameAr: 'الشيخ الدكتور محمد حسان',
    nameEn: 'Sheikh Dr. Mohamed Hassan',
    channelId: 'UCr4Kz8-cozLWzGYa1WICePw',
    icon: Icons.mosque,
    color: Color(0xFF1B5E20),
  ),
  IslamicChannel(
    id: 'abu_ishaq_alheweny',
    nameAr: 'الشيخ أبو إسحاق الحويني',
    nameEn: 'Sheikh Abu Ishaq al-Huwayni',
    channelId: 'UCbUeVRqAdyTSFGh2WzmVUoA',
    icon: Icons.auto_stories,
    color: Color(0xFF3E2723),
    handle: 'aboishaqalheweny',
  ),
  IslamicChannel(
    id: 'mostafa_aladwy',
    nameAr: 'الشيخ مصطفى العدوي',
    nameEn: 'Sheikh Mostafa Al-Adawy',
    channelId: 'UCYW44APHfIo0GyAO9iosHjQ',
    icon: Icons.menu_book,
    color: Color(0xFF33691E),
    handle: 'ftawamostafaaladwy',
  ),
  // «وفي القنوات حط ... الشيخ سمير مصطفى وعمر عبد الكافي ... وصالح المغامسي
  // وعثمان الخميس». Each of these four answered `verify_youtube_channels.py`
  // with the id, title and handle written below — the titles are YouTube's
  // own, untouched. He also asked for «ياسر الخزيمي لو مش موجود»: he is
  // already here, as `yasser_alhazimi`, under the spelling his own channel
  // uses (الحزيمي).
  IslamicChannel(
    id: 'samir_mostafa',
    nameAr: 'قناة الشيخ سمير مصطفى الرسمية',
    nameEn: 'Sheikh Samir Mostafa — Official',
    channelId: 'UCch6Y4YgssEzMa4Q5zw4xjw',
    icon: Icons.record_voice_over,
    color: Color(0xFF6D4C41),
    handle: 'samirmoustafa',
  ),
  IslamicChannel(
    id: 'omar_abdelkafi',
    nameAr: 'عمر عبد الكافي',
    nameEn: 'Omar Abd al-Kafi',
    channelId: 'UCKUOmGXE9Ytlc2EzpGqimtw',
    icon: Icons.live_tv,
    color: Color(0xFF01579B),
    handle: 'abdelkafytube',
  ),
  IslamicChannel(
    id: 'saleh_almaghamsi',
    nameAr: 'الشيخ صالح المغامسي',
    nameEn: 'Sheikh Saleh Al-Maghamsi',
    channelId: 'UCfpli4VHoS12syPkPxHl7XA',
    icon: Icons.school,
    color: Color(0xFF004D40),
    handle: 'Alrasekhoon',
  ),
  IslamicChannel(
    id: 'othman_alkhamees',
    nameAr: 'الشيخ الدكتور عثمان الخميس',
    nameEn: 'Dr. Othman Alkamees',
    channelId: 'UCWjCSGhmSGu0VLf2mPFS0Kg',
    icon: Icons.help_center,
    color: Color(0xFF263238),
    handle: 'othmanalkamees',
  ),
  // «وضيف قناة مبروك زيد الخير ومحمد راتب النابلسي».
  //
  // For مبروك زيد الخير, YouTube has two: `@dr_zidelkhir_mebrouk`, whose own
  // title is his name, and `@mabrouk_zidelkhir` («روائع د. مبروك زيد الخير»),
  // which is a clips channel. The first is the one here.
  //
  // For النابلسي, the one taken is the channel of his own encyclopaedia —
  // «القناة الرسمية لموسوعة النابلسي للعلوم الإسلامية» — rather than either
  // of the two «نفحات/روائع النابلسي» channels, which republish him.
  IslamicChannel(
    id: 'mabrouk_zidelkhir',
    nameAr: 'الدكتور مبروك زيدالخير',
    nameEn: 'Dr. Mebrouk Zidelkhir',
    channelId: 'UCCLucFt_j51ToCFyiE8qMVA',
    icon: Icons.translate,
    color: Color(0xFF880E4F),
    handle: 'dr_zidelkhir_mebrouk',
  ),
  IslamicChannel(
    id: 'rateb_alnabulsi',
    nameAr: 'القناة الرسمية لموسوعة النابلسي للعلوم الإسلامية',
    nameEn: 'Al-Nabulsi Encyclopaedia of Islamic Sciences — Official',
    channelId: 'UC7naRnmAOTwDPu738W2SljQ',
    icon: Icons.library_books,
    color: Color(0xFF1A237E),
    handle: 'nabulsiencyclopedia',
  ),
  // ── The nine merged in from the Library's «قنوات دعوية» tab ──────────────
  //
  // That tab had its own private list, and `IslamicChannelsScreen` — the one
  // this file feeds — had **no route into it anywhere in the app**. So every
  // channel added here was invisible, and the About screen's «١٣ قناة» was a
  // count of a screen nobody could open. Found by opening the tab (§1.3);
  // nothing in `flutter analyze` or the tests says a word about a widget with
  // no route.
  //
  // Merging them meant checking them, and the check found three dead links
  // that had been shipping: `@Dr.AhmedAlarabi`, `@MakanyChannel` and
  // `@waikishow` all answered **404**. أحمد العربي and وعي were found again at
  // the ids below; **قناة مكاني was not, so it is gone** rather than kept as a
  // card that opens nothing (§1.1).
  //
  // `nameAr` here is the label the app already used — the owner's own wording
  // — because YouTube's title for several of them is Latin ("Hassan
  // Elhusseiny", "Amgad Samir", "fahem"); those titles are in `nameEn`.
  IslamicChannel(
    id: 'ragheb_elsergany',
    nameAr: 'د. راغب السرجاني',
    nameEn: 'Dr. Ragheb Elsergany',
    channelId: 'UCCFclvIzI-oqdzQcJ-OOhEg',
    handle: 'RaghebElsergany',
    icon: Icons.history_edu,
    color: Color(0xFF1565C0),
  ),
  IslamicChannel(
    id: 'hassan_elhusseiny',
    nameAr: 'د. حسن الحسيني',
    nameEn: 'Hassan Elhusseiny',
    channelId: 'UCvqfP1TIzsOnYD9_0b2G4xQ',
    handle: 'HassanElhusseiny',
    icon: Icons.menu_book,
    color: Color(0xFF2E7D32),
    hasPhoto: false,
  ),
  IslamicChannel(
    id: 'amgad_samir',
    nameAr: 'الشيخ أمجد سمير',
    nameEn: 'Amgad Samir',
    channelId: 'UCfwebpPHrIoHPfT_UV4a7PA',
    handle: 'AmgadSamir',
    icon: Icons.school,
    color: Color(0xFF6A1B9A),
    hasPhoto: false,
  ),
  // The handle in the shipped app (`@Dr.AhmedAlarabi`) is a 404. Found again
  // by channel id; its own vanity URL is a percent-encoded Arabic handle, so
  // no ASCII handle is recorded rather than a mangled one.
  IslamicChannel(
    id: 'ahmed_alarabi',
    nameAr: 'د. أحمد العربي',
    nameEn: 'Ahmed Alarabi',
    channelId: 'UCyc-c-r8RTLNsp1Uv2DNrSg',
    icon: Icons.auto_stories,
    color: Color(0xFFC62828),
  ),
  IslamicChannel(
    id: 'haytham_talaat',
    nameAr: 'د. هيثم طلعت',
    nameEn: 'Haytham Talaat',
    channelId: 'UCeN94hESGlFkuYg5dDPc_WQ',
    handle: 'Haythamtalaat',
    icon: Icons.lightbulb,
    color: Color(0xFFEF6C00),
    hasPhoto: false,
  ),
  IslamicChannel(
    id: 'fahem',
    nameAr: 'قناة فاهم',
    nameEn: 'fahem',
    channelId: 'UCCVhXAOYR6E9khyRbmGG7LQ',
    handle: 'fahem',
    icon: Icons.smart_display,
    color: Color(0xFF00838F),
    hasPhoto: false,
  ),
  IslamicChannel(
    id: 'eyad_qunaibi',
    nameAr: 'د. إياد قنيبي',
    nameEn: 'Dr. Eyad Qunaibi — Official',
    channelId: 'UCahYlNszeMy_PHffYvgAOHg',
    handle: 'EyadQunaibi',
    icon: Icons.psychology,
    color: Color(0xFF4527A0),
  ),
  IslamicChannel(
    id: 'ayman_abdelraheem',
    nameAr: 'م. أيمن عبد الرحيم',
    nameEn: 'Ayman Abd El Raheem',
    channelId: 'UCCIBiaKWLOhqqycYoJiOa_Q',
    handle: 'AymanAbdelRaheem',
    icon: Icons.volunteer_activism,
    color: Color(0xFF283593),
    hasPhoto: false,
  ),
  // Shipped as `@waikishow`, a 404. `@waei` resolves but to a channel called
  // "Will" — a different channel entirely, which is why a handle that merely
  // *loads* is not evidence. This is the one whose own title is «وعي».
  IslamicChannel(
    id: 'waey',
    nameAr: 'قناة وعي',
    nameEn: 'Waey',
    channelId: 'UCpfmtMWOk6ajbRsy18fgPsA',
    handle: 'waey_official',
    icon: Icons.visibility,
    color: Color(0xFF37474F),
  ),
];
