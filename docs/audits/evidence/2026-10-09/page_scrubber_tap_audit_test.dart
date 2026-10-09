import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rafeeq_app/features/quran/presentation/widgets/mushaf/fast_page_scroll_bar.dart';

class _AuditTranslations extends AssetLoader {
  const _AuditTranslations();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => {};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  setUpAll(EasyLocalization.ensureInitialized);
  testWidgets('audit: a single tap keeps the thumb pinned after page changes', (tester) async {
    var page = 1;
    late StateSetter changePage;
    await tester.pumpWidget(EasyLocalization(
      supportedLocales: const [Locale('en')],
      startLocale: const Locale('en'),
      path: '.', assetLoader: const _AuditTranslations(),
      child: Builder(builder: (context) => MaterialApp(
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        home: StatefulBuilder(builder: (context, setState) {
          changePage = setState;
          return Scaffold(body: Center(child: SizedBox(width: 400,
            child: FastPageScrollBar(currentPage: page, totalPages: 604,
              onChanged: (value) => setState(() => page = value)),
          )));
        }),
      )),
    ));
    await tester.pumpAndSettle();
    final track = find.byType(FastPageScrollBar);
    final origin = tester.getTopLeft(track);
    final thumb = find.byIcon(Icons.drag_indicator);
    await tester.tapAt(origin + const Offset(120, 16));
    await tester.pumpAndSettle();
    expect(page, 182);
    final tappedX = tester.getCenter(thumb).dx - origin.dx;
    changePage(() => page = 604);
    await tester.pumpAndSettle();
    final afterPageChangeX = tester.getCenter(thumb).dx - origin.dx;
    print('AUDIT_SCRUBBER_TAP: tappedPage=182 newPage=$page tappedX=$tappedX afterPageChangeX=$afterPageChangeX expectedLastPageX=387');
    expect(afterPageChangeX, closeTo(tappedX, 0.01));
    expect(afterPageChangeX, lessThan(200));
  });
}
