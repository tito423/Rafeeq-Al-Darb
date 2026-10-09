import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rafeeq_app/core/config/prefs_provider.dart';
import 'package:rafeeq_app/features/more/presentation/widgets/more_group.dart';
import 'package:rafeeq_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:rafeeq_app/features/splash/data/splash_video_provider.dart';

class _Translations extends AssetLoader {
  const _Translations();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('assets/translations/en.json').readAsStringSync())
          as Map<String, dynamic>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({'splash_video_enabled_v1': false});
  setUpAll(EasyLocalization.ensureInitialized);
  for (final parentInsideGroup in [false, true]) {
  testWidgets('audit: More section parent inside group=$parentInsideGroup', (tester) async {
    SharedPreferences.setMockInitialValues({'splash_video_enabled_v1': false});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
    ]);
    addTearDown(container.dispose);
    final sectionKey = GlobalKey();
    Widget section(WidgetRef ref, bool value) => CollapsibleSection(
      key: sectionKey, title: 'Audit splash section',
      children: [SwitchListTile(title: const Text('Audit video switch'),
        value: value,
        onChanged: (v) => ref.read(splashVideoEnabledProvider.notifier).set(v),
      )],
    );
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: EasyLocalization(
        supportedLocales: const [Locale('en')], startLocale: const Locale('en'),
        path: '.', assetLoader: const _Translations(),
        child: Builder(builder: (context) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales, locale: context.locale,
          home: Scaffold(body: ListView(children: [
            if (parentInsideGroup)
              MoreGroup(title: 'Audit settings group', subtitle: '',
                icon: Icons.settings, children: [
                  // Actual SettingsBody is a Consumer inside MoreGroup.
                  Consumer(builder: (context, ref, _) =>
                    section(ref, ref.watch(splashVideoEnabledProvider))),
                ],
              )
            else Consumer(builder: (context, ref, _) {
              final value = ref.watch(splashVideoEnabledProvider);
              return MoreGroup(title: 'Audit settings group', subtitle: '',
                icon: Icons.settings, children: [
                  // The actual public section and actual persistent provider;
                  // same parent-owned SwitchListTile pattern as SettingsBody.
                  section(ref, value),
                ],
              );
            }),
          ])),
        )),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Audit settings group'));
    await tester.pumpAndSettle();
    final origin = sectionKey.currentState!;
    await tester.tap(find.text('Audit splash section'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(origin.mounted, isTrue);
    await tester.pump(const Duration(milliseconds: 500));
    expect(origin.mounted, isFalse);
    final visibleSwitch = find.byType(SwitchListTile).hitTestable();
    expect(visibleSwitch, findsOneWidget);
    expect(tester.widget<SwitchListTile>(visibleSwitch).value, isFalse);
    await tester.tap(visibleSwitch);
    await tester.pumpAndSettle();
    if (parentInsideGroup) {
      final failure = tester.takeException();
      expect(failure, isA<StateError>());
      expect(failure.toString(), contains('after the widget was disposed'));
      expect(container.read(splashVideoEnabledProvider), isFalse);
      expect(prefs.getBool('splash_video_enabled_v1'), isFalse);
      print('AUDIT_MORE_SECTION_INSIDE: callback uses disposed Consumer ref; '
        'switch cannot save; exception=$failure');
    } else {
    expect(container.read(splashVideoEnabledProvider), isTrue);
    expect(prefs.getBool('splash_video_enabled_v1'), isTrue);
    expect(tester.widget<SwitchListTile>(visibleSwitch).value, isFalse);
    await tester.tap(visibleSwitch);
    await tester.pumpAndSettle();
    expect(container.read(splashVideoEnabledProvider), isTrue);
    print('AUDIT_MORE_SECTION: original section disposed after 450ms; '
      'persistent provider=true but visible switch=false; second tap cannot toggle off.');
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
  }
}
