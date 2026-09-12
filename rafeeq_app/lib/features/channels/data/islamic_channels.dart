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

  const IslamicChannel({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.channelId,
    this.handle = '',
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
    handle: 'DRMoustafaMahmoud',
  ),
  IslamicChannel(
    id: 'ayman_abdelgelil',
    nameAr: 'الشيخ أيمن عبد الجليل',
    nameEn: 'Sheikh Ayman Abdel Gelil',
    channelId: 'UC-hKhCAfM5HXbqqfKvcviEA',
    handle: 'ayman_abdelgelil',
  ),
  IslamicChannel(
    id: 'abdullah_rushdy',
    nameAr: 'الشيخ عبد الله رشدي',
    nameEn: 'Sheikh Abdullah Rushdy',
    channelId: 'UCUZOB_l7pZZd0ZjuAbl-tGg',
    handle: 'abdullah.rushdy',
  ),
  IslamicChannel(
    id: 'yasser_alhazimi',
    nameAr: 'الدكتور ياسر الحزيمي',
    nameEn: 'Dr. Yasser Al-Hazimi',
    channelId: 'UC5Tdzct1NlgjX1CsmnGuWGg',
    handle: 'ybh_1000',
  ),
  IslamicChannel(
    id: 'mohamed_hassan',
    nameAr: 'الشيخ الدكتور محمد حسان',
    nameEn: 'Sheikh Dr. Mohamed Hassan',
    channelId: 'UCr4Kz8-cozLWzGYa1WICePw',
  ),
  IslamicChannel(
    id: 'abu_ishaq_alheweny',
    nameAr: 'الشيخ أبو إسحاق الحويني',
    nameEn: 'Sheikh Abu Ishaq al-Huwayni',
    channelId: 'UCbUeVRqAdyTSFGh2WzmVUoA',
    handle: 'aboishaqalheweny',
  ),
  IslamicChannel(
    id: 'mostafa_aladwy',
    nameAr: 'الشيخ مصطفى العدوي',
    nameEn: 'Sheikh Mostafa Al-Adawy',
    channelId: 'UCYW44APHfIo0GyAO9iosHjQ',
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
    handle: 'samirmoustafa',
  ),
  IslamicChannel(
    id: 'omar_abdelkafi',
    nameAr: 'عمر عبد الكافي',
    nameEn: 'Omar Abd al-Kafi',
    channelId: 'UCKUOmGXE9Ytlc2EzpGqimtw',
    handle: 'abdelkafytube',
  ),
  IslamicChannel(
    id: 'saleh_almaghamsi',
    nameAr: 'الشيخ صالح المغامسي',
    nameEn: 'Sheikh Saleh Al-Maghamsi',
    channelId: 'UCfpli4VHoS12syPkPxHl7XA',
    handle: 'Alrasekhoon',
  ),
  IslamicChannel(
    id: 'othman_alkhamees',
    nameAr: 'الشيخ الدكتور عثمان الخميس',
    nameEn: 'Dr. Othman Alkamees',
    channelId: 'UCWjCSGhmSGu0VLf2mPFS0Kg',
    handle: 'othmanalkamees',
  ),
];
