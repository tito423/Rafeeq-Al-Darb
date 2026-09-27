import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../app/navigation.dart';
import '../../../app/shell/tab_request_provider.dart';
import '../../../core/db/quran_repository.dart';
import '../../../core/services/ayah_audio_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/digits.dart';
import '../../dorar/presentation/dorar_hub_screen.dart';
import '../../downloads/data/reciters_provider.dart';
import '../../downloads/presentation/screens/downloads_screen.dart';
import '../../hajj/presentation/hajj_screen.dart';
import '../../hifz/presentation/hifz_screen.dart';
import '../../home/presentation/widgets/on_this_day_sheet.dart';
import '../../library/data/book_catalog.dart';
import '../../library/data/library_api_service.dart';
import '../../library/presentation/screens/book_text_reader_screen.dart';
import '../../library/presentation/screens/books_search_screen.dart';
import '../../quran/data/quran_jump_provider.dart';
import '../../quran/data/quran_fullscreen_provider.dart';
import '../../quran_audio/presentation/ayah_download_screen.dart';
import '../../quran_audio/presentation/quran_audio_screen.dart';
import '../../ruqyah/presentation/screens/ruqyah_audio_screen.dart';
import '../../settings/data/focus_mode_provider.dart';
import '../../shamela/presentation/shamela_screen.dart';
import '../../tajweed/presentation/screens/tajweed_levels_screen.dart';
import '../data/assistant_intent.dart';
import '../data/speech_input.dart';

/// True once `AppShell` is on screen - the mic has nowhere to take the
/// reader before that (splash, onboarding).
final assistantShellUpProvider = StateProvider<bool>((ref) => false);

/// The parser over the app's own catalogues: surah names from the Qur'an
/// database, the reciters that have a verified source, the library's books.
final assistantParserProvider = FutureProvider<AssistantParser>((ref) async {
  final repo = await ref.watch(quranRepositoryProvider.future);
  final surahs = [for (final s in await repo.surahs()) s.nameAr];
  final reciters = [
    for (final r in await ref.watch(recitersProvider.future))
      CatalogReciter(r.identifier, [r.nameAr, r.nameEn]),
  ];
  final books = [
    for (final b in libraryBookCatalog) CatalogBook(b.id, b.titleAr, b.authorAr),
  ];
  return AssistantParser(
      AssistantCatalog(surahs: surahs, reciters: reciters, books: books));
});

/// False while a sheet or a dialog is on top: the button is drawn above the
/// whole navigator, so without this it floated bright over their dim, and
/// over «رفيق»'s own sheet (seen on emulator-5554, 2026-09-27).
final assistantTopIsPage = ValueNotifier<bool>(true);

class AssistantRouteObserver extends NavigatorObserver {
  void _top(Route<dynamic>? r) {
    if (r != null) assistantTopIsPage.value = r is PageRoute;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _top(route);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _top(previousRoute);
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _top(previousRoute);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _top(newRoute);
}

/// «رفيق»'s button, over every screen once the shell is up. Hidden where it
/// would be in the way: the tour, focus mode, a full-screen mushaf page.
class AssistantMicButton extends ConsumerWidget {
  const AssistantMicButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = !ref.watch(assistantShellUpProvider) ||
        ref.watch(tutorialRunningProvider) ||
        ref.watch(focusModeProvider) != null ||
        (ref.watch(quranFullScreenProvider) &&
            ref.watch(activeTabProvider) == AppTab.quran);
    if (hidden) return const SizedBox.shrink();
    final pad = MediaQuery.paddingOf(context);
    return ValueListenableBuilder<bool>(
      valueListenable: assistantTopIsPage,
      builder: (context, page, _) =>
          page ? _button(pad) : const SizedBox.shrink(),
    );
  }

  Widget _button(EdgeInsets pad) {
    // Bottom-left: in Arabic that is the far end of the navigation bar, above
    // «المزيد», where no screen of this app keeps a button of its own.
    return Positioned(
      left: 12 + pad.left,
      bottom: 92 + pad.bottom,
      child: Tooltip(
        message: 'assistant.tooltip'.tr(),
        child: Material(
          color: AppColors.gold.withValues(alpha: 0.92),
          shape: const CircleBorder(),
          elevation: 4,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => showAssistantSheet(),
            child: const Padding(
              padding: EdgeInsets.all(11),
              child: Icon(Icons.mic_rounded, color: Colors.black87, size: 24),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showAssistantSheet() async {
  final ctx = rootNavigatorKey.currentContext;
  if (ctx == null) return;
  await showModalBottomSheet<void>(
    context: ctx,
    showDragHandle: true,
    builder: (_) => const _AssistantSheet(),
  );
}

enum _Phase { starting, listening, done }

class _AssistantSheet extends ConsumerStatefulWidget {
  const _AssistantSheet();

  @override
  ConsumerState<_AssistantSheet> createState() => _AssistantSheetState();
}

class _AssistantSheetState extends ConsumerState<_AssistantSheet> {
  final _speech = SpeechInput.instance;
  _Phase _phase = _Phase.starting;
  String _words = '';
  String? _message;
  double _level = 0;

  @override
  void initState() {
    super.initState();
    _speech
      ..onPartial = (t) {
        if (mounted) setState(() => _words = t);
      }
      ..onLevel = (l) {
        if (mounted) setState(() => _level = l);
      }
      ..onReady = () {
        if (mounted) setState(() => _phase = _Phase.listening);
      };
    unawaited(_listen());
  }

  @override
  void dispose() {
    _speech
      ..onPartial = null
      ..onLevel = null
      ..onReady = null;
    if (_phase != _Phase.done) unawaited(_speech.cancel());
    super.dispose();
  }

  void _end(String message) {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.done;
      _message = message;
    });
  }

  Future<void> _listen() async {
    setState(() {
      _phase = _Phase.starting;
      _words = '';
      _message = null;
    });
    if (!(await Permission.microphone.request()).isGranted) {
      return _end('assistant.mic_denied'.tr());
    }
    final (any, _) = await _speech.available();
    if (!any) return _end('assistant.no_recognizer'.tr());
    final r = await _speech.listen();
    if (!mounted) return;
    if (!r.ok) return _end(_errorText(r.error));
    setState(() => _words = r.text!);
    final parser = await ref.read(assistantParserProvider.future);
    // The first alternative the app understands wins: the recogniser's top
    // guess is sometimes a near-miss of a surah or reciter name that its
    // second or third guess has right.
    var intent = parser.parse(r.text!);
    for (final alt in r.alternatives) {
      if (intent is! UnknownIntent) break;
      intent = parser.parse(alt);
    }
    if (intent is UnknownIntent) {
      return _end('assistant.not_understood'.tr());
    }
    final reply = await _describe(intent);
    _end(reply);
    await _say(reply);
    if (!mounted) return;
    // The sheet goes before the action, so the action cannot use its `ref`.
    final container = ProviderScope.containerOf(context, listen: false);
    Navigator.of(context).pop();
    await _execute(container, intent);
  }

  String _errorText(int? code) => switch (code) {
        SpeechInput.errSpeechTimeout ||
        SpeechInput.errNoMatch =>
          'assistant.no_speech'.tr(),
        SpeechInput.errNetwork ||
        SpeechInput.errNetworkTimeout =>
          'assistant.network'.tr(),
        SpeechInput.errPermission => 'assistant.mic_denied'.tr(),
        SpeechInput.errLanguageNotSupported ||
        SpeechInput.errLanguageUnavailable =>
          'assistant.lang_unavailable'.tr(),
        _ => 'assistant.failed'.tr(args: ['${code ?? '-'}']),
      };

  /// What the reader is told before it happens - short, and said aloud.
  Future<String> _describe(AssistantIntent intent) async {
    switch (intent) {
      case PlaySurahIntent(:final surah, :final reciterId):
        final repo = await ref.read(quranRepositoryProvider.future);
        final name = (await repo.surahs())[surah - 1].nameAr;
        final id = reciterId ?? ref.read(selectedReciterProvider);
        final reciters = await ref.read(recitersProvider.future);
        final r = reciters.where((x) => x.identifier == id).firstOrNull;
        return 'assistant.playing'.tr(args: [name, r?.nameAr ?? '']);
      case OpenBookIntent(:final bookId):
        final b = libraryBookCatalog.where((x) => x.id == bookId).firstOrNull;
        return 'assistant.opening'.tr(args: [b?.titleAr ?? '']);
      case AuthorBooksIntent(:final author):
        return 'assistant.opening'.tr(args: [author]);
      default:
        return 'assistant.ok'.tr();
    }
  }

  Future<void> _say(String text) async {
    try {
      final tts = FlutterTts();
      await tts.awaitSpeakCompletion(true);
      await tts.setLanguage('ar');
      await tts.speak(text);
    } catch (_) {
      // No Arabic voice on the phone: the words are on the sheet already.
    }
  }

  static Future<void> _execute(
      ProviderContainer ref, AssistantIntent intent) async {
    final nav = rootNavigatorKey.currentState;
    if (nav == null) return;
    void tab(int t) {
      nav.popUntil((r) => r.isFirst);
      ref.read(requestedTabProvider.notifier).state = t;
    }

    void push(Widget screen) =>
        nav.push(MaterialPageRoute<void>(builder: (_) => screen));

    switch (intent) {
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
            push(const RuqyahAudioScreen());
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
      case OpenBookIntent(:final bookId):
        await _openBook(nav, bookId);
      case AuthorBooksIntent(:final author):
        push(BooksSearchScreen(initialQuery: author));
      case UnknownIntent():
        break;
    }
  }

  /// Opened if it is on the phone, otherwise downloaded first - the same
  /// path the library's search takes.
  static Future<void> _openBook(NavigatorState nav, String id) async {
    final book = libraryBookCatalog.where((b) => b.id == id).firstOrNull;
    if (book == null) return;
    final api = LibraryApiService.instance;
    if (!await api.isBookDownloaded(id)) {
      final url = book.textEdition?.url;
      if (url == null) return;
      rootScaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
          content: Text('assistant.downloading'.tr(args: [book.titleAr]))));
      try {
        await api.downloadBook(id, url);
      } catch (_) {
        rootScaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
            content: Text('assistant.download_failed'.tr())));
        return;
      }
    }
    final path = await api.bookFilePath(id);
    nav.push(MaterialPageRoute<void>(
        builder: (_) => BookTextReaderScreen(book: book, path: path)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final listening = _phase == _Phase.listening;
    // A Material 3 sheet is only as wide as what is in it; this one is
    // the width of the screen.
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
            GestureDetector(
              onTap: switch (_phase) {
                _Phase.listening => () => _speech.stop(),
                _Phase.done => _listen,
                _Phase.starting => null,
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 76 + (listening ? _level.clamp(0, 10) * 3 : 0),
                height: 76 + (listening ? _level.clamp(0, 10) * 3 : 0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: listening
                      ? AppColors.gold
                      : AppColors.gold.withValues(alpha: 0.35),
                ),
                child: Icon(
                  _phase == _Phase.done ? Icons.refresh_rounded : Icons.mic_rounded,
                  size: 36,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              switch (_phase) {
                _Phase.starting => '…',
                _Phase.listening => 'assistant.listening'.tr(),
                _Phase.done => _message ?? '',
              },
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (_words.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'assistant.heard'.tr(args: [localizeDigits(_words, 'ar')]),
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
