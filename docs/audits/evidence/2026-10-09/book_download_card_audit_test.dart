import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rafeeq_app/features/library/data/book_catalog.dart';
import 'package:rafeeq_app/features/library/data/library_api_service.dart';
import 'package:rafeeq_app/features/library/presentation/widgets/book_card.dart';

class _Translations extends AssetLoader {
  const _Translations();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => {
    'library': {'download': 'Download', 'hide': 'Hide', 'size': 'Size'},
    'common': {'cancel': 'Cancel'},
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  setUpAll(EasyLocalization.ensureInitialized);
  testWidgets('audit: active direct book transfer still offers another download', (tester) async {
    final book = bookById('ghidha_al_albab')!;
    final downloads = LibraryApiService.instance.bookDownloads;
    final previous = downloads.value;
    addTearDown(() => downloads.value = previous);
    // Exact public progress state written by downloadBook/onReceiveProgress.
    // No network or app data is changed by this proof.
    downloads.value = {book.id: 0.5};
    var repeatTaps = 0;
    await tester.pumpWidget(EasyLocalization(
      supportedLocales: const [Locale('en')], startLocale: const Locale('en'),
      path: '.', assetLoader: const _Translations(),
      child: Builder(builder: (context) => MaterialApp(
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales, locale: context.locale,
        home: Scaffold(body: BookCard(
          book: book, paths: const {},
          onDownload: () => repeatTaps++, onOpen: () {},
        )),
      )),
    ));
    await tester.pumpAndSettle();
    expect(downloads.value[book.id], 0.5);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Cancel'), findsNothing);
    final button = find.widgetWithText(OutlinedButton, 'Download');
    expect(button, findsOneWidget);
    expect(tester.widget<OutlinedButton>(button).onPressed, isNotNull);
    await tester.tap(button);
    expect(repeatTaps, 1);
    expect(tester.takeException(), isNull);
    print('AUDIT_BOOK_DOWNLOAD_CARD: direct progress=0.5; progress hidden; cancel absent; enabled Download accepted duplicate callback');
  });
}
