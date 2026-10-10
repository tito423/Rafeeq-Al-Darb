import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rafeeq_app/features/tajweed/data/makharij.dart';
import 'package:rafeeq_app/features/tajweed/presentation/widgets/makharij_diagram.dart';

class _Translations extends AssetLoader {
  const _Translations();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('assets/translations/en.json').readAsStringSync())
          as Map<String, dynamic>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  setUpAll(EasyLocalization.ensureInitialized);
  testWidgets('actual zoomed diagram picks qaf when tapping displayed kaf', (tester) async {
    Makhraj? picked;
    final selected = makharij.firstWhere((m) => m.id == 'shafa_bmw');
    await tester.pumpWidget(EasyLocalization(
      supportedLocales: const [Locale('en')], startLocale: const Locale('en'),
      path: '.', assetLoader: const _Translations(),
      child: Builder(builder: (context) => MaterialApp(
        locale: context.locale, supportedLocales: context.supportedLocales,
        localizationsDelegates: context.localizationDelegates,
        home: Scaffold(body: Center(child: SizedBox(width: 300,
          child: MakharijDiagram(selected: selected, onPick: (m) => picked = m,
            articulation: const AlwaysStoppedAnimation(1),
            flow: const AlwaysStoppedAnimation(0)),
        ))),
      )),
    ));
    await tester.pumpAndSettle();
    final stack = find.descendant(of: find.byType(MakharijDiagram), matching: find.byType(Stack));
    final box = tester.renderObject<RenderBox>(stack);
    final kaf = MakharijDiagram.points['lisan_aqsa_kaf']!;
    // localToGlobal applies the production Transform; this is the point
    // actually painted on screen, not the unscaled data coordinate.
    final paintedKaf = box.localToGlobal(Offset(kaf.dx * box.size.width, kaf.dy * box.size.height));
    await tester.tapAt(paintedKaf);
    await tester.pump();
    expect(picked?.id, 'lisan_aqsa_qaf');
    print('AUDIT_MAKHARIJ_HIT: selected=${selected.id}; '
      'tap displayed kaf at $paintedKaf; actual onPick=${picked?.id}; '
      'diagram=${box.size}; articulation=1');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
