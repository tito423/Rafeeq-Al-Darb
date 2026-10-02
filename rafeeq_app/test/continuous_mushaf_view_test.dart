import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/db/models.dart';
import 'package:rafeeq_app/core/utils/digits.dart';
import 'package:rafeeq_app/features/quran/presentation/widgets/mushaf/continuous_mushaf_view.dart';

/// The reading layout is one endless scroll, and it must stay INDEXED
/// (owner, 2026-10-02: «لما أضغط الى سورة كذا ينقلني في وضع الانفينيت
/// سكرولينج للسورة كذا … عشان ما يحصلش تعارض»): a jump lands on the page
/// asked for — or on the mark inside it — whatever was built before, and
/// the page it reports is the page on screen.
///
/// The pages here are plain boxes of different heights, so nothing can
/// line up by accident.
void main() {
  double heightOf(int page) => 300.0 + (page % 7) * 90;

  Future<(GlobalKey<ContinuousMushafViewState>, List<int>)> pump(
    WidgetTester tester, {
    int initial = 1,
    bool autoScroll = false,
  }) async {
    final key = GlobalKey<ContinuousMushafViewState>();
    final reported = <int>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ContinuousMushafView(
          key: key,
          firstPage: 1,
          lastPage: 604,
          initialPage: initial,
          autoScroll: autoScroll,
          autoScrollSpeed: 2000,
          ayahsOf: (_) async => const <Ayah>[],
          ayahsIfLoaded: (_) => const <Ayah>[],
          onPageChanged: reported.add,
          pageBuilder: (context, page, _) => SizedBox(
            key: ValueKey('page-$page'),
            height: heightOf(page),
            child: Column(
              children: [
                SizedBox(height: heightOf(page) / 2),
                // A surah opening halfway down the page.
                ContinuousMark(
                  id: continuousSurahMark(page),
                  child: SizedBox(
                      key: ValueKey('mark-$page'), height: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return (key, reported);
  }

  double topOf(WidgetTester tester, String key) =>
      tester.getTopLeft(find.byKey(ValueKey(key))).dy;

  /// A page starts with its number rule; its text is right under it, and
  /// nothing of the page before is left on screen.
  void startsAtTop(WidgetTester tester, int page) {
    final rule = tester.getTopLeft(find.text(localizeDigits('$page', uiLanguageCode))).dy;
    expect(rule, inInclusiveRange(0, 20), reason: 'page $page rule');
    expect(topOf(tester, 'page-$page'), lessThan(50));
    final before = find.byKey(ValueKey('page-${page - 1}'));
    if (before.evaluate().isNotEmpty) {
      expect(tester.getBottomLeft(before).dy, lessThanOrEqualTo(0));
    }
  }

  testWidgets('a jump to a page never built lands on that page', (t) async {
    final (view, reported) = await pump(t);
    view.currentState!.jumpToPage(300);
    await t.pumpAndSettle();
    startsAtTop(t, 300);
    expect(reported.last, 300);
    expect(view.currentState!.currentPage, 300);
  });

  testWidgets('a jump with a mark lands on the mark, mid-page', (t) async {
    final (view, reported) = await pump(t, initial: 40);
    view.currentState!.jumpToPage(520, mark: continuousSurahMark(520));
    await t.pumpAndSettle();
    expect(topOf(t, 'mark-520'), 0);
    expect(reported.last, 520);
  });

  testWidgets('a jump to a page already on screen scrolls to it', (t) async {
    final (view, reported) = await pump(t, initial: 10);
    view.currentState!.jumpToPage(11);
    await t.pumpAndSettle();
    startsAtTop(t, 11);
    expect(reported.last, 11);
  });

  testWidgets('the pages before the anchor are there, in order', (t) async {
    final (_, reported) = await pump(t, initial: 200);
    // Drag down: the previous page comes in above, not some other one.
    await t.drag(find.byType(CustomScrollView), const Offset(0, 500));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('page-199')), findsOneWidget);
    expect(reported.last, 199);
  });

  testWidgets('auto-scroll runs on through the page ends', (t) async {
    final (view, reported) = await pump(t, initial: 5, autoScroll: true);
    for (var i = 0; i < 60; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    // 3 s at 2000 px/s is several pages; no page turn stopped it.
    expect(view.currentState!.currentPage, greaterThan(8));
    expect(reported, isNotEmpty);
  });
}
