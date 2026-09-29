import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/app/navigation.dart';
import 'package:rafeeq_app/app/shell/tab_request_provider.dart';
import 'package:rafeeq_app/core/db/quran_repository.dart';
import 'package:rafeeq_app/features/assistant/presentation/assistant_quran_word.dart';
import 'package:rafeeq_app/features/quran/data/quran_jump_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The spoken word question, end to end on the real corpus: one place opens
/// the mushaf at once, several places give a list the reader picks from.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late QuranRepository repo;

  setUpAll(() async {
    repo = QuranRepository(await databaseFactory.openDatabase(
        File('assets/data/quran_local.db').absolute.path,
        options: OpenDatabaseOptions(readOnly: true)));
  });

  Future<ProviderContainer> host(WidgetTester tester) async {
    final container = ProviderContainer(overrides: [
      quranRepositoryProvider.overrideWith((ref) async => repo),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        home: const Scaffold(body: SizedBox()),
      ),
    ));
    return container;
  }

  testWidgets('a word said once opens the mushaf on it at once', (tester) async {
    final container = await host(tester);
    await tester.runAsync(() => runQuranWord(container, 'عسعس'));
    await tester.pump();
    final page = container.read(quranJumpRequestProvider);
    expect(page, isNotNull, reason: 'the mushaf was asked to jump');
    final ayah = (await tester.runAsync(() => repo.searchQuran('عسعس')))!.single;
    expect(page, ayah.pageNumber);
    expect(container.read(requestedTabProvider), AppTab.quran);
  });

  testWidgets('a common word gives a list, and a tap opens that ayah',
      (tester) async {
    final container = await host(tester);
    await tester.runAsync(() => runQuranWord(container, 'الرحمن').timeout(
        const Duration(milliseconds: 1500), onTimeout: () {}));
    await tester.pumpAndSettle();
    expect(find.text('assistant.word_hint'), findsOneWidget);
    expect(find.byType(ListTile), findsWidgets);
    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();
    expect(container.read(quranJumpRequestProvider), isNotNull);
    expect(container.read(requestedTabProvider), AppTab.quran);
  });

  testWidgets('a word that is not there says so and opens nothing',
      (tester) async {
    final container = await host(tester);
    await tester.runAsync(() => runQuranWord(container, 'زخرفةمخترعة'));
    await tester.pump();
    expect(find.text('assistant.word_none'), findsOneWidget);
    expect(container.read(quranJumpRequestProvider), isNull);
  });
}
