import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../app/navigation.dart';
import '../../../app/shell/tab_request_provider.dart';
import '../../../core/db/azkar_repository.dart';
import '../../../core/db/hadeethenc_repository.dart';
import '../../../core/db/hadith_repository.dart';
import '../../../core/db/quran_repository.dart';
import '../../../core/i18n/supported_locales.dart';
import '../../../core/services/ayah_audio_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_controller.dart';
import '../../adhan/presentation/screens/adhan_background_screen.dart';
import '../../adhan/presentation/screens/adhan_settings_screen.dart';
import '../../adhan/presentation/screens/prayer_adjustments_screen.dart';
import '../../adhan/presentation/screens/prayer_location_screen.dart';
import '../../azkar/presentation/screens/azkar_section_screen.dart';
import '../../dedications/presentation/dedications_screen.dart';
import '../../dorar/presentation/dorar_history_screen.dart';
import '../../dorar/presentation/dorar_hub_screen.dart';
import '../../dorar/presentation/dorar_screen.dart';
import '../../dorar/presentation/dorar_search_screen.dart';
import '../../dorar/presentation/dorar_tafseer_screen.dart';
import '../../downloads/data/reciters_provider.dart';
import '../../downloads/presentation/screens/downloads_screen.dart';
import '../../hadeethenc/data/hadeethenc_providers.dart';
import '../../hadeethenc/presentation/screens/hadeethenc_category_screen.dart';
import '../../hadeethenc/presentation/screens/hadeethenc_detail_screen.dart';
import '../../hajj/presentation/hajj_screen.dart';
import '../../hifz/presentation/hifz_screen.dart';
import '../../hifz/presentation/hifz_session_screen.dart';
import '../../home/presentation/widgets/clock_gallery_sheet.dart';
import '../../home/presentation/widgets/on_this_day_sheet.dart';
import '../../khatma/presentation/khatma_screen.dart';
import '../../library/data/book_catalog.dart';
import '../../library/data/library_api_service.dart';
import '../../library/presentation/screens/book_text_reader_screen.dart';
import '../../library/presentation/screens/books_search_screen.dart';
import '../../library/presentation/screens/hadith_book_screen.dart';
import '../../library/presentation/screens/hadith_chapter_screen.dart';
import '../../library/presentation/screens/hadith_detail_screen.dart';
import '../../onboarding/presentation/screens/onboarding_screen.dart';
import '../../quran/data/quran_jump_provider.dart';
import '../../quran/presentation/screens/sciences_pack_screen.dart';
import '../../quran_audio/data/mp3quran_api.dart';
import '../../quran_audio/presentation/ayah_download_screen.dart';
import '../../quran_audio/presentation/ayah_reciter_screen.dart';
import '../../quran_audio/presentation/quran_audio_screen.dart';
import '../../quran_audio/presentation/reciter_screen.dart';
import '../../ruqyah/presentation/screens/ruqyah_audio_screen.dart';
import '../../ruqyah/presentation/screens/ruqyah_screen.dart';
import '../../search/presentation/screens/search_screen.dart';
import '../../settings/data/transliteration_settings_provider.dart';
import '../../settings/presentation/screens/about_screen.dart';
import '../../settings/presentation/screens/settings_screen.dart'
    show SettingsBody, SettingsPart;
import '../../settings/presentation/screens/sources_screen.dart';
import '../../shamela/data/shamela_library.dart';
import '../../shamela/presentation/shamela_screen.dart';
import '../../splash/data/splash_video_provider.dart';
import '../../splash/presentation/screens/splash_preview_screen.dart';
import '../../sunan_suwar/data/sunan_suwar_catalog.dart';
import '../../sunan_suwar/presentation/single_surah_screen.dart';
import '../../support/presentation/screens/support_screen.dart';
import '../../tajweed/presentation/screens/jazariyyah_level_screen.dart';
import '../../tajweed/presentation/screens/makharij_screen.dart';
import '../../tajweed/presentation/screens/tajweed_levels_screen.dart';
import '../../tajweed/presentation/screens/tamhid_level_screen.dart';
import '../../tajweed/presentation/screens/tuhfa_level_screen.dart';
import '../data/assistant_intent.dart';
import '../data/assistant_lexicon.dart';
import '../data/assistant_settings.dart';
import '../data/assistant_settings_map.dart';
import '../data/rafeeq_ear.dart';
import '../data/rafeeq_voice_pack.dart';

/// True once `AppShell` is on screen - there is nowhere to take the reader
/// before that (splash, onboarding).
final assistantShellUpProvider = StateProvider<bool>((ref) => false);

/// The parser over the app's own catalogues: surah names (Arabic and
/// transliterated) from the Qur'an database, the reciters that have a
/// verified source, the library's books AND the books the reader imported
/// from Shamela, and every screen, setting and switch title of the seven
/// translation files.
final assistantParserProvider = FutureProvider<AssistantParser>((ref) async {
  final repo = await ref.watch(quranRepositoryProvider.future);
  final surahs = await repo.surahs();
  final azkarRepo = await ref.watch(azkarRepositoryProvider.future);
  final azkarSections = await azkarRepo.sections();
  final reciters = [
    for (final r in await ref.watch(recitersProvider.future))
      CatalogReciter(r.identifier, [r.nameAr, r.nameEn]),
  ];
  var wholeSurahReciters = const <Mp3Reciter>[];
  try {
    wholeSurahReciters = await ref.watch(mp3RecitersProvider.future);
  } catch (error) {
    debugPrint('assistant catalogue: whole-surah reciters unavailable: $error');
  }
  var hadeethCategories = const <HadeethCategory>[];
  try {
    final hadeethRepo = await ref.watch(hadeethEncRepositoryProvider.future);
    if (hadeethRepo != null) hadeethCategories = await hadeethRepo.categories();
  } catch (error) {
    debugPrint('assistant catalogue: hadeeth categories unavailable: $error');
  }
  var hadithBooks = const <HadithBook>[];
  var hadithChapters = const <HadithChapter>[];
  try {
    final hadithRepo = await ref.watch(hadithRepositoryProvider.future);
    if (hadithRepo != null) {
      hadithBooks = await hadithRepo.books();
      hadithChapters = [for (final book in hadithBooks)
        ...await hadithRepo.chaptersOfBook(book.id)];
    }
  } catch (error) {
    debugPrint('assistant catalogue: hadith books unavailable: $error');
  }
  await ShamelaLibrary.instance.load();
  final books = [
    for (final b in libraryBookCatalog) CatalogBook(b.id, b.titleAr, b.authorAr),
    // «لا موجود، نزلته من الشاملة» (owner, 2026-09-27) - «رجال حول الرسول»
    // was on his phone, imported, and the assistant did not know it.
    for (final b in ShamelaLibrary.instance.books)
      CatalogBook(b.id, b.titleAr, b.authorAr),
  ];
  final locales = <Map<String, dynamic>>[];
  for (final l in kSupportedLocales) {
    try {
      locales.add(jsonDecode(await rootBundle
              .loadString('assets/translations/${l.languageCode}.json'))
          as Map<String, dynamic>);
    } catch (error, stackTrace) {
      debugPrint('assistant catalogue: failed to load '
          '${l.languageCode}: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
  final labels = labelsFrom(locales);
  debugPrint('assistant catalogue: locales=${locales.length}, '
      'sections=${labels.sections.length}, '
      'section phrases=${labels.sections.values.fold<int>(0, (n, v) => n + v.length)}');
  return AssistantParser(AssistantCatalog(
    surahs: [for (final s in surahs) s.nameAr],
    surahsLatin: [for (final s in surahs) s.nameEn],
    sunanSurahIds: {for (final s in sunanSuwarCatalog) s.surahId},
    azkarSections: [
      for (final s in azkarSections)
        CatalogAzkarSection(s.id, _azkarSectionNames(locales, s.id, s.title)),
    ],
    wholeSurahReciters: [
      for (final r in wholeSurahReciters) CatalogWholeReciter(r.id, [r.name]),
    ],
    hadeethCategories: [for (final c in hadeethCategories)
      CatalogHadeethCategory(c.id, [c.title, c.titleAr])],
    hadithBooks: [for (final b in hadithBooks)
      CatalogHadithBook(b.id, [b.nameAr, b.nameEn])],
    hadithChapters: [for (final c in hadithChapters)
      CatalogHadithChapter(c.bookId, c.chapterNo, [c.nameAr, c.nameEn])],
    reciters: reciters,
    books: books,
    screenLabels: labels.screens,
    settingLabels: labels.settings,
    optionLabels: labels.options,
    settingSections: labels.sections,
  ));
});

List<String> _azkarSectionNames(
    List<Map<String, dynamic>> locales, int id, String arabicTitle) {
  final names = <String>{arabicTitle};
  for (final locale in locales) {
    final azkar = locale['azkar'];
    if (azkar is! Map<String, dynamic>) continue;
    final sections = azkar['section'];
    if (sections is! Map<String, dynamic>) continue;
    final title = sections['$id'];
    if (title is String && title.trim().isNotEmpty) names.add(title);
  }
  return names.toList();
}

/// The app's language code now («ar», «en», …).
String _appLanguage() {
  final ctx = rootNavigatorKey.currentContext;
  return ctx == null ? 'ar' : ctx.locale.languageCode;
}

/// True while «رفيق»'s sheet is open - it takes what is said next.
final assistantSheetOpen = ValueNotifier<bool>(false);

const _channel = MethodChannel('com.tito.rafeeq_aldarb/assistant');

/// «يا رفيق», heard wherever the reader is, while he has it switched on and
/// the voice pack is on the phone.
///
/// There is no button: «الأفضل إنه يختفي، مايظهرش غير لما أنده يا رفيق»
/// (owner, 2026-09-27). Said with a command («يا رفيق شغل الكهف»), the
/// command runs at once; said alone, the sheet opens and takes the next
/// sentence.
///
/// Never in anyone's way («خد بالك من الكونفلكت … ولما تيجي مكالمة … في كل
/// الحالات»): it takes no audio focus, and the microphone is CLOSED while a
/// call rings or runs, while any sound plays (this app's recitation or adhan,
/// another app's music), and while any other app - or the tasmee - records;
/// checked every second, and it opens again when all is quiet. In the
/// background a foreground service with a notification keeps it alive; its
/// «إيقاف» switches the assistant off.
class AssistantWakeListener extends ConsumerStatefulWidget {
  const AssistantWakeListener({super.key});

  @override
  ConsumerState<AssistantWakeListener> createState() =>
      _AssistantWakeListenerState();
}

class _AssistantWakeListenerState extends ConsumerState<AssistantWakeListener>
    with WidgetsBindingObserver {
  final _ear = RafeeqEar.instance;
  Timer? _tick;
  StreamSubscription<String>? _heard;
  bool _foreground = true;
  bool _serviceOn = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    RafeeqVoicePack.instance.check();
    ShamelaLibrary.instance.addListener(_booksChanged);
    _heard = _ear.heard.listen(_onHeard);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ShamelaLibrary.instance.removeListener(_booksChanged);
    _tick?.cancel();
    _heard?.cancel();
    super.dispose();
  }

  void _booksChanged() => ref.invalidate(assistantParserProvider);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _check();
  }

  Future<void> _check() async {
    if (_busy || !mounted) return;
    _busy = true;
    try {
      final on = ref.read(assistantEnabledProvider) &&
          RafeeqVoicePack.instance.installed.value == true &&
          ref.read(assistantShellUpProvider);
      // «إيقاف» pressed in the notification.
      if (on && _serviceOn && await _channel.invokeMethod<bool>('stoppedByUser') == true) {
        _serviceOn = false;
        await ref.read(assistantEnabledProvider.notifier).set(false);
        await _ear.stop();
        return;
      }
      if (!on) {
        if (_ear.listening.value) await _ear.stop();
        if (_serviceOn) {
          _serviceOn = false;
          await _channel.invokeMethod('stopService');
        }
        return;
      }
      // Started only while the app is on screen: Android refuses a
      // microphone service started from the background.
      if (!_serviceOn && _foreground) {
        _serviceOn = true;
        await _channel.invokeMethod('startService', {
          'title': 'assistant.name'.tr(),
          'text': 'assistant.notif_text'.tr(),
          'stop': 'assistant.notif_stop'.tr(),
          'channel': 'assistant.setting_title'.tr(),
        });
      }
      final busy = await _channel.invokeMapMethod<String, dynamic>('busy') ?? {};
      final ours = _ear.listening.value ? 1 : 0;
      final quiet = busy['call'] != true &&
          busy['playing'] != true &&
          ((busy['recording'] as int?) ?? 0) <= ours &&
          (_foreground || _serviceOn) &&
          await Permission.microphone.isGranted;
      if (quiet && !_ear.listening.value) {
        await _ear.start();
      } else if (!quiet && _ear.listening.value) {
        await _ear.stop();
      }
      if (_ear.listening.value) await _testClip();
    } catch (_) {
      // A failed check is retried on the next tick.
    } finally {
      _busy = false;
    }
  }

  /// A 16 kHz mono WAV pushed to the app's external files folder as
  /// `rafeeq_test.wav` is heard once, as if spoken, then deleted - how
  /// «رفيق» is checked end to end on the emulator, which hears nothing from
  /// the PC. The time from feeding to text is logged.
  DateTime? _fedAt;
  Future<void> _testClip() async {
    final dir = await getExternalStorageDirectory();
    if (dir == null) return;
    final f = File('${dir.path}/rafeeq_test.wav');
    if (!f.existsSync()) return;
    final b = await f.readAsBytes();
    await f.delete();
    final pcm = b.buffer.asInt16List(44, (b.length - 44) ~/ 2);
    _fedAt = DateTime.now();
    _ear.feed(Float32List.fromList([for (final v in pcm) v / 32768.0]));
  }

  Future<void> _onHeard(String text) async {
    if (_fedAt != null) {
      debugPrint('rafeeq heard in ${DateTime.now().difference(_fedAt!).inMilliseconds} ms: $text');
      _fedAt = null;
    }
    if (assistantSheetOpen.value || !mounted) return; // the sheet takes it
    final rest = afterWakeWord(text);
    if (rest == null) return;
    final container = ProviderScope.containerOf(context, listen: false);
    if (rest.isNotEmpty) {
      final parser = await ref.read(assistantParserProvider.future);
      final intent = parser.parse(rest);
      debugPrint('rafeeq intent: "$rest" -> $intent');
      if (intent is! UnknownIntent) {
        await _act(container, intent);
        return;
      }
    }
    if (!_foreground) await _channel.invokeMethod('toFront');
    await showAssistantSheet(heard: rest.isEmpty ? null : text);
  }

  Future<void> _act(ProviderContainer container, AssistantIntent intent) async {
    final reply = await describeIntent(container, intent);
    if (!_foreground && intent is! PlaySurahIntent &&
        intent is! SetThemeIntent && intent is! ToggleOptionIntent) {
      await _channel.invokeMethod('toFront');
    }
    rootScaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
        content: Text(reply), duration: const Duration(seconds: 2)));
    await runIntent(container, intent);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(assistantEnabledProvider, (_, _) => _check());
    ref.listen<bool>(assistantShellUpProvider, (_, _) => _check());
    return const SizedBox.shrink();
  }
}

/// Opens the sheet that takes the next sentence. [heard] is what was said
/// with the call when it was not understood.
Future<void> showAssistantSheet({String? heard}) async {
  final ctx = rootNavigatorKey.currentContext;
  if (ctx == null || assistantSheetOpen.value) return;
  assistantSheetOpen.value = true;
  try {
    await showModalBottomSheet<void>(
      context: ctx,
      showDragHandle: true,
      builder: (_) => _AssistantSheet(firstHeard: heard),
    );
  } finally {
    assistantSheetOpen.value = false;
  }
}

/// What the reader is told before it happens - short, on screen.
Future<String> describeIntent(
    ProviderContainer ref, AssistantIntent intent) async {
  switch (intent) {
    case PlaySurahIntent(:final surah, :final reciterId):
      final repo = await ref.read(quranRepositoryProvider.future);
      final s = (await repo.surahs())[surah - 1];
      final ar = _appLanguage() == 'ar' || _appLanguage() == 'ur';
      final id = reciterId ?? ref.read(selectedReciterProvider);
      final reciters = await ref.read(recitersProvider.future);
      final r = reciters.where((x) => x.identifier == id).firstOrNull;
      return 'assistant.playing'.tr(args: [
        ar ? s.nameAr : s.nameEn,
        r == null ? '' : (ar ? r.nameAr : r.nameEn),
      ]);
    case OpenBookIntent(:final bookId):
      final b = libraryBookCatalog.where((x) => x.id == bookId).firstOrNull ??
          ShamelaLibrary.instance.byId(bookId);
      return 'assistant.opening'.tr(args: [b?.titleAr ?? '']);
    case AuthorBooksIntent(:final author):
      return 'assistant.opening'.tr(args: [author]);
    case ShamelaSearchIntent(:final title):
      return 'assistant.opening'.tr(args: [title]);
    case OpenSettingIntent(:final section):
      return 'assistant.opening'.tr(args: [section.tr()]);
    default:
      return 'assistant.ok'.tr();
  }
}

/// Does what was asked.
Future<void> runIntent(ProviderContainer ref, AssistantIntent intent) async {
  final nav = rootNavigatorKey.currentState;
  if (nav == null) return;
  void tab(int t) {
    nav.popUntil((r) => r.isFirst);
    ref.read(requestedTabProvider.notifier).state = t;
  }

  void push(Widget screen) =>
      nav.push(MaterialPageRoute<void>(builder: (_) => screen));

  switch (intent) {
    case OpenSettingIntent(:final section):
      final part = assistantSettingsSections[section]?.$1 == 'reminders'
          ? SettingsPart.reminders
          : SettingsPart.settings;
      push(Scaffold(
        appBar: AppBar(title: Text(section.tr())),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: SettingsBody(part: part, focusSection: section),
        ),
      ));
    case ShamelaSearchIntent(:final title, :final download):
      push(ShamelaScreen(initialQuery: title, openBest: download));
    case OpenScreenIntent(:final screen):
      switch (screen) {
        case AssistantScreen.home || AssistantScreen.dailyHadith:
          tab(AppTab.home);
        case AssistantScreen.quran:
          tab(AppTab.quran);
        case AssistantScreen.prayer || AssistantScreen.qibla:
          tab(AppTab.prayer);
        case AssistantScreen.azkar:
          tab(AppTab.azkar);
        case AssistantScreen.tasbeeh:
          tab(AppTab.tasbeeh);
        case AssistantScreen.library:
          tab(AppTab.library);
        case AssistantScreen.more || AssistantScreen.settings:
          tab(AppTab.more);
        case AssistantScreen.downloads:
          push(const DownloadsScreen());
        case AssistantScreen.recitationPlayer:
          push(const QuranAudioScreen());
        case AssistantScreen.ayahPlayer:
          push(const AyahDownloadScreen());
        case AssistantScreen.hifz:
          push(const HifzScreen());
        case AssistantScreen.ruqyah:
          push(const RuqyahScreen());
        case AssistantScreen.hajj:
          push(const HajjScreen());
        case AssistantScreen.tajweed:
          push(const TajweedLevelsScreen());
        case AssistantScreen.dorar:
          push(const DorarHubScreen());
        case AssistantScreen.shamela:
          push(const ShamelaScreen());
        case AssistantScreen.onThisDay:
          await showHijriDaySheet(nav.context);
        case AssistantScreen.clockFaces:
          tab(AppTab.home);
          await ClockGallerySheet.show(nav.context);
        case AssistantScreen.about:
          push(const AboutScreen());
        case AssistantScreen.sources:
          push(const SourcesScreen());
        case AssistantScreen.support:
          push(const SupportScreen());
        case AssistantScreen.dedications:
          push(const DedicationsScreen());
        case AssistantScreen.khatma:
          push(const KhatmaScreen());
        case AssistantScreen.bookSearch:
          push(const BooksSearchScreen());
        case AssistantScreen.adhanSettings:
          push(const AdhanSettingsScreen());
        case AssistantScreen.adhanBackgrounds:
          push(const AdhanBackgroundScreen());
        case AssistantScreen.prayerAdjustments:
          push(const PrayerAdjustmentsScreen());
        case AssistantScreen.prayerLocation:
          push(const PrayerLocationScreen());
        case AssistantScreen.quranSciences:
          push(const SciencesPackScreen());
        case AssistantScreen.makharij:
          push(const MakharijScreen());
        case AssistantScreen.tuhfa:
          push(const TuhfaLevelScreen());
        case AssistantScreen.jazariyyah:
          push(const JazariyyahLevelScreen());
        case AssistantScreen.tamhid:
          push(const TamhidLevelScreen());
        case AssistantScreen.dorarSearch:
          push(const DorarSearchScreen());
        case AssistantScreen.dorarHadith:
          push(const DorarScreen());
        case AssistantScreen.dorarTafseer:
          push(const DorarTafseerScreen());
        case AssistantScreen.dorarHistory:
          push(const DorarHistoryScreen());
        case AssistantScreen.ruqyahAudio:
          push(const RuqyahAudioScreen());
        case AssistantScreen.initialDownloads:
          push(const OnboardingScreen(revisit: true));
        case AssistantScreen.splashPreview:
          push(const SplashPreviewScreen());
        case AssistantScreen.quranSearch:
          final repo = await ref.read(quranRepositoryProvider.future);
          push(SearchScreen(repo: repo));
      }
    case OnThisDayIntent(:final day, :final month):
      await showHijriDaySheet(nav.context,
          day: day != null && month != null ? (month, day) : null);
    case PlaySurahIntent(:final surah, :final reciterId):
      final repo = await ref.read(quranRepositoryProvider.future);
      final first = await repo.ayah(surah, 1);
      if (first == null) return;
      // Saying a reciter chooses him, as picking him in the list does, so
      // the mushaf's own play button goes on with the same voice.
      if (reciterId != null) {
        await ref.read(selectedReciterProvider.notifier).select(reciterId);
      }
      ref.read(quranJumpRequestProvider.notifier).state = first.pageNumber;
      tab(AppTab.quran);
      await AyahAudioService.instance.startContinuous(
        from: first,
        repo: repo,
        edition: reciterId ?? ref.read(selectedReciterProvider),
        wholeMushaf: false,
      );
    case MemorizeSurahIntent(:final surah):
      final repo = await ref.read(quranRepositoryProvider.future);
      final item = (await repo.surahs()).where((s) => s.id == surah).firstOrNull;
      if (item != null) push(HifzSessionScreen.surah(item));
    case OpenSunanSurahIntent(:final surah):
      push(SingleSurahScreen(surahId: surah));
    case OpenAzkarSectionIntent(:final sectionId):
      final repo = await ref.read(azkarRepositoryProvider.future);
      final section =
          (await repo.sections()).where((s) => s.id == sectionId).firstOrNull;
      if (section != null) push(AzkarSectionScreen(section: section));
    case OpenAyahReciterIntent(:final reciterId):
      final reciters = await ref.read(recitersProvider.future);
      final reciter =
          reciters.where((r) => r.identifier == reciterId).firstOrNull;
      if (reciter != null) push(AyahReciterScreen(reciter: reciter));
    case OpenWholeSurahReciterIntent(:final reciterId):
      final reciters = await ref.read(mp3RecitersProvider.future);
      final reciter = reciters.where((r) => r.id == reciterId).firstOrNull;
      if (reciter != null) push(ReciterScreen(reciter: reciter));
    case OpenHadeethCategoryIntent(:final categoryId):
      final repo = await ref.read(hadeethEncRepositoryProvider.future);
      final catalog = await ref.read(hadeethEncCatalogProvider.future);
      final pack = catalog.forLocale(_appLanguage());
      if (repo == null || pack == null) return;
      final category =
          (await repo.categories()).where((c) => c.id == categoryId).firstOrNull;
      if (category != null) {
        push(HadeethEncCategoryScreen(
          repo: repo, category: category,
          sourceName: catalog.nameFor(pack.lang),
          sourceUrl: catalog.sourceUrl, rtl: pack.isRtl,
        ));
      }
    case OpenHadeethEncDetailIntent(:final itemId):
      final repo = await ref.read(hadeethEncRepositoryProvider.future);
      final catalog = await ref.read(hadeethEncCatalogProvider.future);
      final pack = catalog.forLocale(_appLanguage());
      final item = await repo?.byId(itemId);
      if (item != null && pack != null) {
        push(HadeethEncDetailScreen(
          item: item, sourceName: catalog.nameFor(pack.lang),
          sourceUrl: catalog.sourceUrl, rtl: pack.isRtl,
        ));
      }
    case OpenHadithBookIntent(:final bookId):
      final repo = await ref.read(hadithRepositoryProvider.future);
      if (repo == null) return;
      final book = (await repo.books()).where((b) => b.id == bookId).firstOrNull;
      if (book != null) push(HadithBookScreen(book: book, repo: repo));
    case OpenHadithChapterIntent(:final bookId, :final chapterNo):
      final repo = await ref.read(hadithRepositoryProvider.future);
      if (repo == null) return;
      final book = (await repo.books()).where((b) => b.id == bookId).firstOrNull;
      final chapter = (await repo.chaptersOfBook(bookId))
          .where((c) => c.chapterNo == chapterNo).firstOrNull;
      if (book != null && chapter != null) {
        push(HadithChapterScreen(book: book, chapter: chapter, repo: repo));
      }
    case OpenHadithDetailIntent(:final bookId, :final numberInBook):
      final repo = await ref.read(hadithRepositoryProvider.future);
      if (repo == null) return;
      final book = (await repo.books()).where((b) => b.id == bookId).firstOrNull;
      final item = await repo.hadithByNumber(bookId, numberInBook);
      if (book == null || item == null) return;
      final chapterItems = await repo.hadithsOfChapter(bookId, item.chapterNo);
      final index = chapterItems.indexWhere((h) => h.id == item.id);
      if (index >= 0) {
        push(HadithDetailScreen(book: book,
            chapterHadiths: chapterItems, initialIndex: index));
      }
    case OpenBookIntent(:final bookId):
      await _openBook(nav, bookId);
    case AuthorBooksIntent(:final author):
      push(BooksSearchScreen(initialQuery: author));
    case SetThemeIntent(:final theme):
      await ref
          .read(themeControllerProvider.notifier)
          .set(ThemeVariant.values.byName(theme));
    case SetLanguageIntent(:final code):
      await nav.context.setLocale(Locale(code));
    case ToggleOptionIntent(:final option, :final on):
      switch (option) {
        case 'motion':
          await ref.read(motionEffectsProvider.notifier).set(on);
        case 'splash':
          await ref.read(splashVideoEnabledProvider.notifier).set(on);
        case 'transliteration':
          await ref.read(transliterationEnabledProvider.notifier).set(on);
      }
    case UnknownIntent():
      break;
  }
}

/// Opened if it is on the phone, otherwise downloaded first - the same
/// path the library's search takes. A book imported from Shamela is always
/// on the phone.
Future<void> _openBook(NavigatorState nav, String id) async {
  final shamela = ShamelaLibrary.instance.byId(id);
  final book =
      shamela ?? libraryBookCatalog.where((b) => b.id == id).firstOrNull;
  if (book == null) return;
  final api = LibraryApiService.instance;
  if (shamela == null && !await api.isBookDownloaded(id)) {
    final url = book.textEdition?.url;
    if (url == null) return;
    rootScaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
        content: Text('assistant.downloading'.tr(args: [book.titleAr]))));
    try {
      await api.downloadBook(id, url);
    } catch (_) {
      rootScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text('assistant.download_failed'.tr())));
      return;
    }
  }
  final path = await api.bookFilePath(id);
  unawaited(nav.push(MaterialPageRoute<void>(
      builder: (_) => BookTextReaderScreen(book: book, path: path))));
}

/// The sheet «يا رفيق» alone opens: it takes the next sentence, shows what
/// was heard and what will happen, and closes. Nothing to press - it closes
/// by itself after [_wait] of silence.
class _AssistantSheet extends ConsumerStatefulWidget {
  const _AssistantSheet({this.firstHeard});
  final String? firstHeard;

  @override
  ConsumerState<_AssistantSheet> createState() => _AssistantSheetState();
}

class _AssistantSheetState extends ConsumerState<_AssistantSheet> {
  static const _wait = Duration(seconds: 10);
  final _ear = RafeeqEar.instance;
  StreamSubscription<String>? _sub;
  Timer? _close;
  String _words = '';
  String? _message;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    if (widget.firstHeard != null) {
      _words = widget.firstHeard!;
      _message = 'assistant.not_understood'.tr();
    }
    _sub = _ear.heard.listen(_onHeard);
    _armClose();
  }

  void _armClose() {
    _close?.cancel();
    _close = Timer(_wait, () {
      if (mounted && !_done) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _close?.cancel();
    super.dispose();
  }

  Future<void> _onHeard(String text) async {
    if (_done || !mounted) return;
    // «يا رفيق شغل الكهف» said again into the open sheet counts too.
    final said = afterWakeWord(text) ?? text;
    setState(() {
      _words = text;
      _message = null;
    });
    _armClose();
    if (said.isEmpty) return;
    final parser = await ref.read(assistantParserProvider.future);
    final intent = parser.parse(said);
    debugPrint('rafeeq sheet intent: "$said" -> $intent');
    if (!mounted) return;
    if (intent is UnknownIntent) {
      setState(() => _message = 'assistant.not_understood'.tr());
      return;
    }
    _done = true;
    final container = ProviderScope.containerOf(context, listen: false);
    final reply = await describeIntent(container, intent);
    if (!mounted) return;
    setState(() => _message = reply);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    Navigator.of(context).pop();
    await runIntent(container, intent);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('assistant.name'.tr(),
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 18),
            ValueListenableBuilder<bool>(
              valueListenable: _ear.speaking,
              builder: (context, speaking, _) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: speaking ? 96 : 76,
                height: speaking ? 96 : 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold.withValues(alpha: speaking ? 0.9 : 0.4),
                ),
                child: const Icon(Icons.graphic_eq_rounded,
                    size: 36, color: Colors.black87),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _message ?? 'assistant.listening'.tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (_words.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'assistant.heard'.tr(args: [_words]),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
