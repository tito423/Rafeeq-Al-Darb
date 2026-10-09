import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rafeeq_app/features/library/data/book_catalog.dart';
import 'package:rafeeq_app/features/library/presentation/widgets/book_provenance_strip.dart';

class _Translations extends AssetLoader {
  const _Translations();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => {};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  setUpAll(EasyLocalization.ensureInitialized);
  testWidgets('audit: Ghidha provenance renders the publisher prefix without edition', (tester) async {
    final book = bookById('ghidha_al_albab')!;
    await tester.pumpWidget(EasyLocalization(
      supportedLocales: const [Locale('ar')], startLocale: const Locale('ar'),
      path: '.', assetLoader: const _Translations(),
      child: Builder(builder: (context) => MaterialApp(
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales, locale: context.locale,
        home: Scaffold(body: BookProvenanceStrip(
          book: book, paper: Colors.white, ink: Colors.black,
          hairline: Colors.grey, onTap: () {},
        )),
      )),
    ));
    await tester.pumpAndSettle();
    final label = book.textEdition!.sourceLabel;
    expect(label, 'المكتبة الشاملة — ');
    expect(find.text(label), findsOneWidget);
    expect(find.textContaining('قرطبة'), findsNothing);
    expect(find.textContaining('١٩٩٣'), findsNothing);
    print('AUDIT_BOOK_PROVENANCE: actual catalog + strip label="$label"; no publisher or edition rendered');
  });
}
