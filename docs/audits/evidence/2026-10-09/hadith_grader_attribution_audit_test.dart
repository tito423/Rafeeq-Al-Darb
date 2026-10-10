import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rafeeq_app/core/db/hadith_repository.dart';
import 'package:rafeeq_app/features/library/presentation/screens/hadith_detail_screen.dart';
import 'package:rafeeq_app/features/library/presentation/widgets/listen_text_button.dart';

class _Translations extends AssetLoader {
  const _Translations();
  @override
  Future<Map<String,dynamic>> load(String path,Locale locale) async =>
    jsonDecode(File('assets/translations/en.json').readAsStringSync()) as Map<String,dynamic>;
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late Database db;
  late HadithBook book;
  late HadithItem hadith;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    db = await databaseFactory.openDatabase(File('assets/data/hadith.db').absolute.path,
      options: OpenDatabaseOptions(readOnly:true));
    final repo = HadithRepository(db);
    book = (await repo.books()).firstWhere((b) => b.key=='tirmidhi');
    hadith = (await repo.hadithByNumber(book.id,1))!;
    expect(hadith.id,20013);
    expect(hadith.grade,'Sahih');
    expect(hadith.grader,'Darussalam');
    expect(diacritisedShare(hadith.arabic),lessThan(80));
  });
  tearDownAll(() => db.close());
  testWidgets('actual Tirmidhi1 attribution and unused listen-button disposal', (tester) async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'), (_) async => 1);
    addTearDown(() => binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'),null));
    await tester.pumpWidget(EasyLocalization(
      supportedLocales:const [Locale('en')],startLocale:const Locale('en'),path:'.',assetLoader:const _Translations(),
      child:Builder(builder:(context)=>MaterialApp(locale:context.locale,
        supportedLocales:context.supportedLocales,localizationsDelegates:context.localizationDelegates,
        home:HadithDetailScreen(book:book,chapterHadiths:[hadith],initialIndex:0))),
    ));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Sahih — Darussalam'),200,
      scrollable:find.descendant(of:find.byType(ListView),matching:find.byType(Scrollable)).first);
    await tester.pumpAndSettle();
    expect(find.text('Sahih — Darussalam'),findsOneWidget);
    expect(find.textContaining('Zubair'),findsNothing);
    expect(find.textContaining('زبير'),findsNothing);
    print('AUDIT_GRADER_ATTRIBUTION: actual DB id20013 Tirmidhi1 -> '
      'production screen Sahih — Darussalam; no named scholar or edition. '
      'Primary Sunnah.com/about identifies Darussalam attribution separately.');
    expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    final disposalError = tester.takeException();
    expect(disposalError,isA<FlutterError>());
    expect(disposalError.toString(),contains("Looking up a deactivated widget's ancestor is unsafe"));
    print('AUDIT_UNUSED_LISTEN_DISPOSAL: closing actual Tirmidhi1 without listening '
      'creates the lazy pulse controller during dispose and raises: $disposalError');
    await tester.pump();
  });
}
