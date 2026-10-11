import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/quran/presentation/widgets/mushaf/fast_page_scroll_bar.dart';

const scrubLocales = ['ar', 'en', 'fr', 'es', 'pt', 'ru', 'ur'];

enum ScrubEnd { tap, tapCancel, dragEnd, dragCancel }

class _NoTextAssets extends AssetLoader {
  const _NoTextAssets();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => {};
}

Future<void> verifyPageScrub(
  WidgetTester tester,
  String locale,
  ScrubEnd end,
) async {
  var page = 1;
  late StateSetter changePage;
  await tester.pumpWidget(
    EasyLocalization(
      key: ValueKey('$locale/$end'),
      supportedLocales: [for (final code in scrubLocales) Locale(code)],
      startLocale: Locale(locale),
      saveLocale: false,
      path: '.',
      assetLoader: const _NoTextAssets(),
      child: Builder(
        builder: (context) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: StatefulBuilder(
            builder: (context, setState) {
              changePage = setState;
              return Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 400,
                    child: FastPageScrollBar(
                      currentPage: page,
                      totalPages: 604,
                      onChanged: (value) => setState(() => page = value),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final track = find.byType(FastPageScrollBar);
  expect(tester.element(track).locale.languageCode, locale);
  final origin = tester.getTopLeft(track);
  final width = tester.getSize(track).width;
  final point = origin + Offset(width * 0.3, 16);
  if (end == ScrubEnd.tap) {
    await tester.tapAt(point);
  } else {
    final gesture = await tester.startGesture(point);
    await tester.pump(const Duration(milliseconds: 150));
    if (end == ScrubEnd.dragEnd || end == ScrubEnd.dragCancel) {
      await gesture.moveBy(Offset(width * 0.25, 0));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveBy(Offset(-width * 0.08, 0));
      await tester.pump(const Duration(milliseconds: 100));
      expect(page, inInclusiveRange(2, 603));
      expect(page, isNot(locale == 'ar' ? 423 : 182));
    }
    if (end == ScrubEnd.dragEnd) {
      await gesture.up();
    } else {
      await gesture.cancel();
    }
  }
  await tester.pumpAndSettle();
  if (end == ScrubEnd.tap || end == ScrubEnd.tapCancel) {
    expect(page, locale == 'ar' ? 423 : 182);
  }
  changePage(() => page = 604);
  await tester.pumpAndSettle();
  final thumb = find.byIcon(Icons.drag_indicator);
  var x = tester.getCenter(thumb).dx - origin.dx;
  // Keep the existing direction mapping; this fix concerns gesture lifetime.
  expect(x, closeTo(locale == 'ar' ? 13 : width - 13, 0.01));
  changePage(() => page = 1);
  await tester.pumpAndSettle();
  x = tester.getCenter(thumb).dx - origin.dx;
  expect(x, closeTo(locale == 'ar' ? width - 13 : 13, 0.01));
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox.shrink());
}
