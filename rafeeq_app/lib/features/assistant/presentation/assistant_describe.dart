import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navigation.dart';
import '../../../core/db/quran_repository.dart';
import '../../../core/utils/digits.dart' show localizeDigits;
import '../../downloads/data/reciters_provider.dart';
import '../../library/data/book_catalog.dart';
import '../../shamela/data/shamela_library.dart';
import '../data/assistant_intent.dart';

/// The app's language code now («ar», «en», …).
String assistantLanguage() {
  final ctx = rootNavigatorKey.currentContext;
  if (ctx == null) return 'ar';
  try {
    return ctx.locale.languageCode;
  } catch (_) {
    return 'ar'; // no EasyLocalization above (a widget test)
  }
}

/// What the reader is told before it happens - short, on screen.
Future<String> describeIntent(
    ProviderContainer ref, AssistantIntent intent) async {
  switch (intent) {
    case PlaySurahIntent(:final surah, :final reciterId):
      final repo = await ref.read(quranRepositoryProvider.future);
      final s = (await repo.surahs())[surah - 1];
      final ar = assistantLanguage() == 'ar' || assistantLanguage() == 'ur';
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
    case OpenQuranAyahIntent(:final surah, :final ayah):
      final s = (await (await ref.read(quranRepositoryProvider.future))
          .surahs())[surah - 1];
      final ar = assistantLanguage() == 'ar' || assistantLanguage() == 'ur';
      return 'assistant.opening'.tr(args: [
        '${ar ? s.nameAr : s.nameEn} ${localizeDigits('$ayah', assistantLanguage())}',
      ]);
    case QuranWordIntent(:final query):
      return 'assistant.word_searching'.tr(args: [query]);
    default:
      return 'assistant.ok'.tr();
  }
}
