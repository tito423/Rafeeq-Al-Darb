/// «رفيق»'s words in the app's seven languages, as people SAY them.
///
/// Owner, 2026-09-27: «المستخدم هيتكلم باللغات العامية لكل السبع لغات وهيعوز
/// يوصل لأي سمة أو اختيار في التطبيق». Two sources feed the parser:
///  * this file - the colloquial verbs, fillers and short names people use
///    («افتحلي», "take me to", «abre», «открой», «کھولو»…), written by hand;
///  * the app's own translation files ([screenLabelKeys]) - every screen and
///    option title exactly as the reader sees it in his language, so a name on
///    the screen is always a name the assistant knows.
///
/// Everything here goes through the parser's `norm`, so it is written the
/// natural way (Cyrillic in Cyrillic, accents kept) and folded there.
library;

import 'assistant_intent.dart' show AssistantScreen;
import 'assistant_settings_map.dart';

/// Words that carry no meaning in a command - dropped from what was heard
/// and from every phrase alike.
const fillerWords = <String>[
  // ar (MSA + Egyptian)
  'يا', 'رفيق', 'لو', 'سمحت', 'سمحتي', 'من', 'فضلك', 'عايز', 'عاوز', 'عايزه',
  'عاوزه', 'اريد', 'ابغي', 'ابي', 'ممكن', 'بالله', 'عليك', 'لي', 'ليا', 'لى',
  'دلوقتي', 'الان', 'حالا', 'بسرعه', 'بقي', 'طيب', 'هو', 'هي',
  // en
  'hey', 'hi', 'ok', 'okay', 'rafeeq', 'rafiq', 'rafik', 'refik', 'please',
  'can', 'could', 'would', 'you', 'i', 'want', 'wanna', 'to', 'the', 'me', 'my',
  'a', 'an', 'for', 'now', 'just', 'let', 'lets', 'by',
  // es
  'oye', 'por', 'favor', 'porfa', 'quiero', 'puedes', 'podrias', 'el', 'la',
  'los', 'las', 'de', 'del', 'un', 'una', 'mi', 'ahora',
  // fr
  'stp', 'svp', 'plait', 'je', 'veux', 'voudrais', 'peux', 'tu', 'le', 'les',
  'du', 'des', 'une', 'moi', 'mon', 'ma', 'maintenant',
  // pt
  'quero', 'pode', 'podes', 'o', 'os', 'as', 'do', 'da', 'um', 'uma', 'meu',
  'minha', 'agora',
  // ru
  'пожалуйста', 'мне', 'хочу', 'можешь', 'привет', 'эй', 'рафик', 'сейчас',
  // ur
  'براہ', 'کرم', 'مہربانی', 'مجھے', 'میں', 'چاہتا', 'چاہتی', 'ہوں', 'کو', 'کا',
  'کی', 'کے', 'ذرا', 'یار', 'رفیق', 'ابھی',
];

/// «افتح …» - a screen opens on one of these, or when its name is all that
/// was said.
const openVerbs = <String>[
  'افتح', 'افتحلي', 'افتحي', 'وريني', 'ورني', 'اعرض', 'اعرضلي', 'روح', 'روحلي',
  'ادخل', 'خش', 'هات', 'هاتلي', 'اظهر', 'طلعلي', 'جيبلي', 'ودني', 'وديني',
  'open', 'show', 'go', 'take', 'launch', 'bring', 'see', 'view', 'display',
  'abre', 'abrir', 'muestra', 'muestrame', 've', 'ir', 'llevame', 'ensename',
  'ouvre', 'ouvrir', 'montre', 'affiche', 'va', 'aller', 'emmene',
  'abra', 'mostra', 'mostrar', 'vai', 'leva',
  'открой', 'открыть', 'покажи', 'перейди', 'зайди', 'запусти',
  'کھولو', 'کھولیں', 'دکھاؤ', 'دکھائیں', 'جاؤ', 'چلو',
];

/// «شغل …» - a surah named after one of these plays.
const playVerbs = <String>[
  'شغل', 'شغلي', 'شغللي', 'اسمعني', 'سمعني', 'اقرا', 'اقرالي', 'اتلو', 'رتل',
  'ابدا',
  'play', 'recite', 'read', 'listen', 'put', 'start',
  'pon', 'reproduce', 'reproducir', 'recita', 'escuchar', 'toca',
  'joue', 'jouer', 'lance', 'mets', 'recite', 'ecouter',
  'tocar', 'reproduz', 'ouvir', 'coloca', 'bota',
  'включи', 'поставь', 'прочитай', 'читай', 'воспроизведи',
  'چلاؤ', 'چلائیں', 'سناؤ', 'سنائیں', 'پڑھو', 'لگاؤ',
];

/// «سورة» in every language (Russian and Urdu go through `norm` too).
const surahWords = <String>[
  'سوره', 'سورت', 'surah', 'sura', 'surat', 'soura', 'sourate', 'surata',
  'chapter', 'сура', 'суру', 'суры',
];

/// «كتاب X» / «كتب X».
const bookWords = <String>['كتاب', 'book', 'libro', 'livre', 'livro', 'книга', 'книгу'];
/// Said to Shamela: «دورلي في الشاملة على …», «نزلي كتاب … من الشاملة».
const shamelaWords = <String>['الشامله', 'شامله', 'الشامل', 'shamela', 'shamila'];
const downloadVerbs = <String>[
  'نزل', 'نزلي', 'نزللي', 'نزلهولي', 'حمل', 'حملي', 'حمللي', 'تنزيل',
  'تحميل', 'download', 'import', 'descarga', 'descargar', 'telecharge',
  'baixar', 'скачай',
];
/// Words around a title in a Shamela request that are not the title.
const shamelaNoise = <String>[
  'دور', 'دورلي', 'ابحث', 'ابحثلي', 'دوري', 'شوف', 'شوفلي', 'هات', 'هاتلي',
  'افتح', 'افتحلي', 'في', 'علي', 'على', 'عن', 'من', 'المكتبه', 'مكتبه',
  'كتاب', 'search', 'find', 'open', 'in', 'on', 'from', 'library', 'book',
];
const booksOfWords = <String>[
  'كتب', 'books', 'libros', 'livres', 'livros', 'книги', 'کتابیں',
];

/// «حدث في مثل هذا اليوم».
const onThisDayPhrases = <String>[
  'حدث في مثل هذا اليوم', 'في مثل هذا اليوم', 'حصل في مثل',
  'on this day', 'this day in history', 'today in history',
  'un dia como hoy', 'en este dia', 'tal dia como hoy',
  'ce jour la', 'en ce jour', 'a pareil jour',
  'neste dia', 'hoje na historia', 'um dia como hoje',
  'в этот день', 'этот день в истории',
  'آج کے دن', 'اس دن', 'تاریخ میں آج',
];

/// Hijri months, 1..12, the ways they are said and transliterated.
const hijriMonthWords = <List<String>>[
  ['محرم', 'muharram', 'moharram', 'мухаррам'],
  ['صفر', 'safar', 'сафар'],
  ['ربيع الاول', 'ربيع اول', 'ربیع الاول', 'rabi al awwal', 'rabi ul awwal',
    'rabi al-awwal', 'рабиуль авваль', 'раби аль авваль'],
  ['ربيع الثاني', 'ربيع الاخر', 'ربيع تاني', 'ربیع الثانی', 'rabi al thani',
    'rabi al akhir', 'rabi ul akhir', 'rabi al-thani', 'раби ас сани'],
  ['جمادي الاولي', 'جمادي الاول', 'جمادي اولي', 'jumada al ula',
    'jumada al awwal', 'jumada al-ula', 'джумада аль уля'],
  ['جمادي الثانيه', 'جمادي الاخره', 'جمادي الاخر', 'جمادي تاني',
    'jumada al akhira', 'jumada al thani', 'jumada al-akhirah',
    'джумада аль ахира'],
  ['رجب', 'rajab', 'rajjab', 'раджаб'],
  ['شعبان', 'shaban', 'shaaban', 'sha ban', 'шабан', 'шаабан'],
  ['رمضان', 'ramadan', 'ramazan', 'ramzan', 'ramadhan', 'рамадан', 'рамазан'],
  ['شوال', 'shawwal', 'shawal', 'шавваль', 'шаввал'],
  ['ذو القعده', 'ذي القعده', 'القعده', 'ذیقعد', 'dhul qadah', 'dhu al qadah',
    'dhul qidah', 'zul qada', 'зуль када'],
  ['ذو الحجه', 'ذي الحجه', 'الحجه', 'ذوالحج', 'dhul hijjah', 'dhu al hijjah',
    'zul hijja', 'зуль хиджа'],
];

/// The app's languages by every name people give them.
const languageNames = <String, List<String>>{
  'ar': ['عربي', 'العربيه', 'العربي', 'عربی', 'arabic', 'arabe', 'árabe',
    'арабский', 'арабском'],
  'en': ['انجليزي', 'الانجليزيه', 'الانجليزي', 'انكليزي', 'انگریزی', 'english',
    'ingles', 'inglés', 'anglais', 'inglês', 'английский', 'английском'],
  'es': ['اسباني', 'الاسبانيه', 'اسبانى', 'ہسپانوی', 'spanish', 'espanol',
    'español', 'espagnol', 'espanhol', 'испанский', 'испанском'],
  'fr': ['فرنساوي', 'فرنسي', 'الفرنسيه', 'فرانسیسی', 'french', 'frances',
    'francés', 'français', 'francais', 'francês', 'французский', 'французском'],
  'pt': ['برتغالي', 'البرتغاليه', 'پرتگالی', 'portuguese', 'portugues',
    'portugués', 'portugais', 'português', 'португальский', 'португальском'],
  'ru': ['روسي', 'الروسيه', 'روسی', 'russian', 'ruso', 'russe', 'russo',
    'русский', 'русском'],
  'ur': ['اردو', 'الاورديه', 'الأردية', 'urdu', 'ourdou', 'урду'],
};

const languageWords = <String>[
  'لغه', 'اللغه', 'زبان', 'language', 'idioma', 'langue', 'lingua', 'língua',
  'язык', 'языке',
];

/// «خلي / غير / بدل …» - a setting is being changed.
const changeVerbs = <String>[
  'خلي', 'خل', 'خليه', 'غير', 'حول', 'بدل', 'اقلب', 'حط', 'اعمل',
  'switch', 'change', 'set', 'make', 'turn', 'use',
  'cambia', 'cambiar', 'usa', 'change', 'changer', 'passe', 'utilise',
  'muda', 'mudar', 'troca', 'trocar', 'coloque', 'usar',
  'переключи', 'смени', 'поменяй', 'сделай', 'поставь',
  'بدلو', 'بدلیں', 'کرو', 'کریں', 'تبدیل', 'لگاؤ',
];

/// A switch turned on / off («شغل فيديو البداية», «اقفل التأثيرات الحركية»).
const onWords = <String>[
  'شغل', 'فعل', 'اظهر', 'ظهر', 'تشغيل', 'فعال', 'اظهار',
  'on', 'enable', 'activate', 'show',
  'activa', 'activar', 'enciende', 'muestra', 'mostrar',
  'active', 'activer', 'affiche', 'allume',
  'ativa', 'ativar', 'liga', 'mostra',
  'включи', 'включить', 'покажи',
  'آن', 'چالو', 'دکھاؤ', 'فعال',
];
const offWords = <String>[
  'اقفل', 'قفل', 'اطفي', 'طفي', 'وقف', 'الغي', 'عطل', 'شيل', 'اخفي', 'بطل',
  'off', 'disable', 'deactivate', 'hide', 'stop', 'remove',
  'desactiva', 'desactivar', 'apaga', 'quita', 'oculta',
  'desactive', 'desactiver', 'désactive', 'eteins', 'éteins', 'masque', 'enleve',
  'desativa', 'desativar', 'desliga', 'esconde', 'tira',
  'выключи', 'отключи', 'скрой', 'убери', 'выключить',
  'بند', 'ہٹاؤ', 'چھپاؤ',
];

/// The theme values, as said.
const themeValueWords = <String, List<String>>{
  'dark': ['ليلي', 'داكن', 'غامق', 'دارك', 'الوضع الليلي', 'المظلم',
    'dark', 'dark mode', 'night mode', 'night',
    'oscuro', 'modo oscuro', 'noche', 'sombre', 'mode sombre', 'nuit',
    'escuro', 'modo escuro', 'noturno',
    'темная', 'тёмная', 'темный', 'тёмный', 'ночной', 'ночная',
    'ڈارک', 'تاریک', 'رات'],
  'light': ['نهاري', 'فاتح', 'لايت', 'الوضع النهاري', 'منور',
    'light', 'light mode', 'day mode', 'bright',
    'claro', 'modo claro', 'dia', 'clair', 'mode clair', 'jour',
    'modo claro', 'diurno',
    'светлая', 'светлый', 'дневной', 'дневная',
    'لائٹ', 'روشن', 'دن'],
  'rgb': ['rgb', 'ار جي بي', 'نيون', 'neon', 'неон'],
  'system': ['النظام', 'زي الموبايل', 'مثل الجهاز', 'system', 'automatic', 'auto',
    'sistema', 'automatico', 'systeme', 'système', 'automatique',
    'системная', 'как в системе', 'автоматически', 'سسٹم', 'خودکار'],
};

const themeWords = <String>[
  'ثيم', 'الثيم', 'المظهر', 'مظهر', 'الوضع', 'السمه', 'الالوان',
  'theme', 'mode', 'appearance', 'colors', 'colours',
  'tema', 'modo', 'apariencia', 'theme', 'thème', 'apparence', 'couleurs',
  'aparencia', 'aparência', 'cores',
  'тема', 'тему', 'режим', 'оформление',
  'تھیم', 'موڈ', 'رنگ',
];

/// Switches the assistant can flip - its own words beside the setting's
/// label from the translations.
const optionWords = <String, List<String>>{
  'motion': ['الحركه', 'الانيميشن', 'التاثيرات', 'التاثيرات الحركيه', 'animations',
    'animation', 'motion', 'animaciones', 'efectos', 'effets', 'animações',
    'efeitos', 'анимации', 'анимацию', 'эффекты', 'انیمیشن', 'اثرات'],
  'splash': ['فيديو البدايه', 'فيديو الافتتاح', 'الفيديو الافتتاحي',
    'splash', 'intro video', 'video de inicio', 'video d intro',
    'video de abertura', 'заставка', 'заставку', 'تعارفی ویڈیو'],
  'transliteration': ['النطق', 'الكتابه اللاتينيه', 'transliteration',
    'pronunciation', 'transliteracion', 'transliteración', 'translitteration',
    'translittération', 'transliteracao', 'transliteração', 'транслитерация',
    'транслитерацию', 'تلفظ'],
};

/// Short names people use for each screen, beyond its title.
const screenWords = <AssistantScreen, List<String>>{
  AssistantScreen.ayahPlayer: ['ايه بايه', 'ايه ايه', 'مشغل الايات', 'التلاوه ايه',
    'ayah by ayah', 'verse by verse', 'aleya por aleya', 'verset par verset',
    'versiculo por versiculo', 'аят за аятом', 'آیت بہ آیت'],
  AssistantScreen.recitationPlayer: ['مشغل التلاوه', 'مشغل القران', 'مشغل التلاوات',
    'التلاوات', 'القراء', 'recitation player', 'recitations', 'reciters',
    'player', 'recitaciones', 'recitadores', 'reproductor', 'recitations',
    'recitateurs', 'lecteur', 'recitações', 'recitadores', 'reprodutor',
    'чтецы', 'чтецов', 'плеер', 'تلاوتیں', 'قاری', 'قراء'],
  AssistantScreen.dailyHadith: ['حديث اليوم', 'hadith of the day', 'daily hadith',
    'hadiz del dia', 'hadith du jour', 'hadith do dia', 'хадис дня',
    'آج کی حدیث'],
  AssistantScreen.azkar: ['الاذكار', 'اذكار', 'adhkar', 'azkar', 'dhikr',
    'remembrances', 'recuerdos', 'invocaciones', 'invocations', 'rappels',
    'lembranças', 'invocações', 'азкары', 'зикры', 'азкар', 'اذکار'],
  AssistantScreen.tasbeeh: ['المسبحه', 'السبحه', 'مسبحه', 'التسبيح', 'tasbeeh',
    'tasbih', 'counter', 'rosary', 'misbaha', 'contador', 'compteur',
    'chapelet', 'contador', 'тасбих', 'счетчик', 'четки', 'تسبیح'],
  AssistantScreen.library: ['المكتبه', 'مكتبه', 'الكتب', 'library', 'books',
    'biblioteca', 'libros', 'bibliotheque', 'livres', 'livros', 'библиотека',
    'библиотеку', 'книги', 'لائبریری', 'کتب خانہ'],
  AssistantScreen.settings: ['الاعدادات', 'اعدادات', 'الضبط', 'settings',
    'options', 'preferences', 'ajustes', 'configuracion', 'parametres',
    'réglages', 'reglages', 'configurações', 'configuracoes', 'настройки',
    'ترتیبات', 'سیٹنگز'],
  AssistantScreen.downloads: ['التنزيلات', 'التحميلات', 'تنزيلات', 'تحميلات',
    'downloads', 'descargas', 'telechargements', 'téléchargements',
    'transferencias', 'downloads', 'загрузки', 'ڈاؤن لوڈز'],
  AssistantScreen.qibla: ['القبله', 'اتجاه القبله', 'qibla', 'qiblah', 'kibla',
    'alquibla', 'quibla', 'кибла', 'киблу', 'قبلہ'],
  AssistantScreen.prayer: ['مواقيت الصلاه', 'الصلاه', 'المواقيت', 'الاذان',
    'prayer', 'prayer times', 'salah', 'adhan', 'oracion', 'rezo',
    'horarios de oracion', 'priere', 'prière', 'horaires', 'oração', 'oracao',
    'намаз', 'молитва', 'время намаза', 'نماز', 'اوقات نماز'],
  AssistantScreen.hifz: ['التحفيظ', 'التسميع', 'الحفظ', 'memorize', 'memorise',
    'memorization', 'hifz', 'memorizar', 'memoriser', 'memorização',
    'заучивание', 'хифз', 'حفظ'],
  AssistantScreen.ruqyah: ['الرقيه', 'ruqyah', 'ruqya', 'rukia', 'roqya',
    'рукья', 'рукъя', 'رقیہ'],
  AssistantScreen.hajj: ['الحج', 'العمره', 'المناسك', 'hajj', 'umrah', 'hajj and umrah',
    'hach', 'hadj', 'omra', 'umra', 'хадж', 'умра', 'حج', 'عمرہ'],
  AssistantScreen.tajweed: ['التجويد', 'tajweed', 'tajwid', 'tadjwid',
    'таджвид', 'تجوید'],
  AssistantScreen.dorar: ['الدرر', 'الدرر السنيه', 'التخريج', 'dorar', 'durar',
    'дорар', 'درر'],
  AssistantScreen.shamela: ['الشامله', 'المكتبه الشامله', 'shamela', 'shamila',
    'шамела', 'شاملہ'],
  AssistantScreen.clockFaces: ['شكل الساعه', 'اشكال الساعه', 'الساعات',
    'clock face', 'clock faces', 'watch face', 'clock', 'reloj', 'esfera',
    'horloge', 'cadran', 'relogio', 'relógio', 'часы', 'циферблат', 'گھڑی'],
  AssistantScreen.quran: ['المصحف', 'القران', 'quran', 'koran', 'coran',
    'alcoran', 'corão', 'alcorao', 'коран', 'корана', 'قرآن', 'قران'],
  AssistantScreen.more: ['المزيد', 'more', 'mas', 'más', 'plus', 'mais', 'ещё',
    'еще', 'مزید'],
  AssistantScreen.home: ['الرئيسيه', 'الصفحه الرئيسيه', 'البدايه', 'home',
    'main page', 'home screen', 'inicio', 'accueil', 'início', 'главная',
    'главную', 'ہوم'],
};

/// The translation keys whose text names a screen - read from all seven
/// locale files at run time, so the assistant knows every title as the
/// reader sees it.
const screenLabelKeys = <AssistantScreen, List<String>>{
  AssistantScreen.home: ['nav.home'],
  AssistantScreen.quran: ['nav.quran'],
  AssistantScreen.prayer: ['nav.prayer'],
  AssistantScreen.azkar: ['nav.azkar', 'azkar.title'],
  AssistantScreen.tasbeeh: ['nav.tasbeeh'],
  AssistantScreen.library: ['nav.library'],
  AssistantScreen.more: ['nav.more'],
  AssistantScreen.settings: ['nav.settings', 'settings.title'],
  AssistantScreen.downloads: ['nav.downloads', 'downloads.title'],
  AssistantScreen.recitationPlayer: ['quran_audio.title'],
  AssistantScreen.hifz: ['hifz.title'],
  AssistantScreen.ruqyah: ['ruqyah.title', 'ruqyah.audio_title'],
  AssistantScreen.hajj: ['hajj.title'],
  AssistantScreen.tajweed: ['tajweed.title'],
  AssistantScreen.dorar: ['dorar.hub_title', 'dorar.title'],
  AssistantScreen.shamela: ['shamela.title'],
  AssistantScreen.dailyHadith: ['hadith_daily.title'],
  AssistantScreen.clockFaces: ['home.clock_gallery_title'],
};

/// Settings whose names, said, open the settings: every short title in the
/// `settings` group (not the descriptions) - «أي اختيار في التطبيق».
Iterable<String> settingsLabels(Map<String, dynamic> locale) sync* {
  final s = locale['settings'];
  if (s is! Map) return;
  for (final e in s.entries) {
    final k = e.key as String;
    final v = e.value;
    if (v is String && !k.endsWith('_desc') && !v.contains('{') && v.length <= 40) {
      yield v;
    }
  }
}

/// Labels of the option switches, by option, from the translations.
const optionLabelKeys = <String, List<String>>{
  'motion': ['settings.motion_effects'],
  'splash': ['settings.splash_video'],
  'transliteration': ['settings.show_transliteration'],
};

String? lookup(Map<String, dynamic> locale, String dotted) {
  Object? cur = locale;
  for (final part in dotted.split('.')) {
    if (cur is! Map) return null;
    cur = cur[part];
  }
  return cur is String ? cur : null;
}

/// The screen, setting and switch titles of [locales] (code -> the parsed
/// translation file), as the parser's catalogue takes them.
({
  Map<AssistantScreen, List<String>> screens,
  List<String> settings,
  Map<String, List<String>> options,
  Map<String, List<String>> sections,
}) labelsFrom(Iterable<Map<String, dynamic>> locales) {
  final screens = <AssistantScreen, List<String>>{};
  final settings = <String>[];
  final options = <String, List<String>>{};
  final sections = <String, List<String>>{};
  for (final l in locales) {
    for (final e in assistantSettingsSections.entries) {
      for (final k in [e.key, ...e.value.$2]) {
        final v = lookup(l, k);
        if (v != null && !v.contains('{') && v.length <= 40) {
          (sections[e.key] ??= []).add(v);
        }
      }
    }
    for (final e in screenLabelKeys.entries) {
      for (final k in e.value) {
        final v = lookup(l, k);
        if (v != null) (screens[e.key] ??= []).add(v);
      }
    }
    settings.addAll(settingsLabels(l));
    for (final e in optionLabelKeys.entries) {
      for (final k in e.value) {
        final v = lookup(l, k);
        if (v != null) (options[e.key] ??= []).add(v);
      }
    }
  }
  return (
    screens: screens,
    settings: settings,
    options: options,
    sections: sections,
  );
}

/// The assistant's name, as recognisers write it in each language.
const wakeWords = <String>[
  'رفيق', 'rafik', 'rafiq', 'rafeeq', 'refik', 'rafique', 'рафик', 'رفیق',
  // As omnilingual-asr wrote it on the measured clips (2026-09-27).
  'rafek', 'rafec', 'rafeek', 'رفيك', 'رافك',
];
