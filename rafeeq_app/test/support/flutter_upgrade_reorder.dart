import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/app/rafeeq_app.dart';
import 'package:rafeeq_app/features/library/data/islamic_websites.dart';
import 'package:rafeeq_app/features/library/data/link_list_customization.dart';
import 'package:rafeeq_app/features/library/presentation/widgets/link_list_manage_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ActualTranslations extends AssetLoader {
  const _ActualTranslations(this.document);
  final Map<String, dynamic> document;
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      document;
}

void flutterUpgradeReorderTests({
  Future<void> Function(String)? screenshotReady,
}) {
  for (final language in ['ar', 'en', 'fr', 'es', 'pt', 'ru', 'ur']) {
    for (final downward in [true, false]) {
      testWidgets(
        'A48 actual website reorder ${downward ? "down" : "up"} ($language)',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          late SharedPreferences prefs;
          late Map<String, dynamic> document;
          await tester.runAsync(() async {
            await EasyLocalization.ensureInitialized();
            prefs = await SharedPreferences.getInstance();
            document =
                jsonDecode(
                      await rootBundle.loadString(
                        'assets/translations/$language.json',
                      ),
                    )
                    as Map<String, dynamic>;
          });
          final container = ProviderContainer(
            overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
          );
          addTearDown(container.dispose);
          final locale = Locale(language);
          final actual = islamicWebsites.take(3).toList();
          final ids = [for (final site in actual) site.url];
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: EasyLocalization(
                supportedLocales: [locale],
                startLocale: locale,
                fallbackLocale: locale,
                path: 'assets/translations',
                saveLocale: false,
                assetLoader: _ActualTranslations(document),
                child: Builder(
                  builder: (context) => MaterialApp(
                    locale: context.locale,
                    supportedLocales: context.supportedLocales,
                    localizationsDelegates: context.localizationDelegates,
                    home: LinkListManageScreen(
                      listId: 'a48-owned-test',
                      title: 'links.manage'.tr(),
                      catalogue: (_) => [
                        for (final site in actual)
                          ManagedLink(
                            id: site.url,
                            name: site.name,
                            subtitle: site.descriptionKey.tr(),
                            url: site.url,
                            leading: Icon(site.icon),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final list = tester.widget<ReorderableListView>(
            find.byType(ReorderableListView),
          );
          // Flutter now supplies the destination AFTER removing the old item.
          expect(list.onReorderItem, isNotNull);
          list.onReorderItem!(downward ? 0 : 2, downward ? 2 : 0);
          await tester.pumpAndSettle();
          final expected = downward
              ? [ids[1], ids[2], ids[0]]
              : [ids[2], ids[0], ids[1]];
          expect(
            container.read(linkListProvider('a48-owned-test')).order,
            expected,
          );
          final stored =
              jsonDecode(prefs.getString('links.a48-owned-test.v1')!)
                  as Map<String, dynamic>;
          expect(stored['order'], expected);
          expect(
            LinkListNotifier(prefs, 'a48-owned-test').state.order,
            expected,
          );
          for (final site in actual) {
            expect(find.text(site.name), findsOneWidget);
            expect(find.text(site.url), findsOneWidget);
          }
          if (screenshotReady != null) {
            await screenshotReady('${language}_${downward ? "down" : "up"}');
          }
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        },
      );
    }
  }
}
