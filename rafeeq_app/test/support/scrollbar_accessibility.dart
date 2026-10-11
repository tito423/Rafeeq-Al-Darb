import 'dart:convert';

import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/widgets/arrow_scrollbar.dart';

const scrollbarLocales = ['ar', 'en', 'fr', 'es', 'pt', 'ru', 'ur'];

Future<void> verifyScrollbarAccessibility(
  WidgetTester tester,
  String locale,
) async {
  final source = await tester.runAsync(
    () => rootBundle.loadString('assets/translations/$locale.json'),
  );
  final values = jsonDecode(source!) as Map<String, dynamic>;
  Localization.load(Locale(locale), translations: Translations(values));
  final semantics = tester.ensureSemantics();
  final controller = ScrollController();
  var rowTaps = 0;
  void perform(Finder finder, SemanticsAction action) {
    tester.binding.performSemanticsAction(
      SemanticsActionEvent(
        type: action,
        nodeId: tester.getSemantics(finder).id,
        viewId: tester.view.viewId,
      ),
    );
  }

  await tester.pumpWidget(
    MaterialApp(
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        scrollbars: false,
      ),
      home: Scaffold(
        body: Directionality(
          textDirection: locale == 'ar' || locale == 'ur'
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: ArrowScrollbar(
            controller: controller,
            child: ListView.builder(
              controller: controller,
              itemCount: 60,
              itemBuilder: (_, i) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => rowTaps++,
                child: SizedBox(height: 70, child: Text('Row $i')),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
  final listRect = tester.getRect(find.byType(ListView));
  final railEdge = locale == 'ar' || locale == 'ur'
      ? listRect.left + 4
      : listRect.right - 4;
  // The hidden overlay must leave taps to the list beneath it.
  await tester.tapAt(Offset(railEdge, listRect.top + 28));
  expect(rowTaps, 1);
  // Cold Android layout may outlast the idle fade. Wake only after layout,
  // and wait for a visible rail before measuring its unchanged requirements.
  final visibleArrow = find.byIcon(Icons.keyboard_arrow_up_rounded);
  for (
    var attempt = 0;
    attempt < 20 && visibleArrow.evaluate().isEmpty;
    attempt++
  ) {
    controller.jumpTo(200 + attempt % 2);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
  }
  expect(visibleArrow, findsOneWidget);
  for (final (icon, labelKey, hintKey) in [
    (Icons.keyboard_arrow_up_rounded, 'scroll_up', 'scroll_to_start'),
    (Icons.keyboard_arrow_down_rounded, 'scroll_down', 'scroll_to_end'),
  ]) {
    final iconFinder = find.byIcon(icon);
    final node = tester.getSemantics(iconFinder);
    expect(node.rect.size.width, greaterThanOrEqualTo(48));
    expect(node.rect.size.height, greaterThanOrEqualTo(48));
    final common = values['common'] as Map<String, dynamic>;
    final data = node.getSemanticsData();
    expect(data.label, common[labelKey]);
    expect(data.hint, common[hintKey]);
    expect(data.label, isNotEmpty);
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    expect(data.hasAction(SemanticsAction.longPress), isTrue);
  }
  final up = find.byIcon(Icons.keyboard_arrow_up_rounded);
  final down = find.byIcon(Icons.keyboard_arrow_down_rounded);
  // Hit the added space, outside the old 22 x 26 visual arrow.
  final downRect = tester.getRect(
    find.ancestor(of: down, matching: find.byType(InkWell)).first,
  );
  final corner = downRect.topLeft + const Offset(3, 3);
  final before = controller.offset;
  await tester.tapAt(corner);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 340));
  expect(controller.offset, greaterThan(before));
  perform(up, SemanticsAction.tap);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 340));
  expect(controller.offset, closeTo(before, 0.01));
  perform(down, SemanticsAction.longPress);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 470));
  expect(controller.offset, controller.position.maxScrollExtent);
  perform(up, SemanticsAction.longPress);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 470));
  expect(controller.offset, 0);
  Focus.of(tester.element(down)).requestFocus();
  await tester.pump();
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 340));
  expect(controller.offset, greaterThan(0));
  await tester.pump(const Duration(seconds: 2));
  expect(down, findsOneWidget);
  Focus.of(tester.element(down)).unfocus();
  await tester.pump();
  perform(down, SemanticsAction.didGainAccessibilityFocus);
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
  expect(down, findsOneWidget);
  perform(down, SemanticsAction.didLoseAccessibilityFocus);
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
  await tester.pump(const Duration(milliseconds: 400));
  expect(down, findsNothing);
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox.shrink());
  controller.dispose();
  semantics.dispose();
}
