import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/theme/app_theme.dart';
import 'package:rafeeq_app/core/widgets/arrow_scrollbar.dart';

void main() {
  testWidgets('audit: visible rail arrows have small unlabeled tap nodes', (tester) async {
    final semantics = tester.ensureSemantics();
    final controller = ScrollController();
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      scrollBehavior: const MaterialScrollBehavior().copyWith(scrollbars: false),
      home: Scaffold(body: ArrowScrollbar(controller: controller,
        child: ListView.builder(controller: controller, itemCount: 60,
          itemBuilder: (_, i) => SizedBox(height: 70, child: Text('Row $i'))))),
    ));
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
    for (final icon in [Icons.keyboard_arrow_up_rounded, Icons.keyboard_arrow_down_rounded]) {
      final finder = find.ancestor(of: find.byIcon(icon), matching: find.byType(GestureDetector)).first;
      final size = tester.getSize(finder);
      final node = tester.getSemantics(finder);
      final data = node.getSemanticsData();
      print('AUDIT_RAIL: icon=${icon.codePoint} size=$size semanticRect=${node.rect} label=${data.label} tap=${data.hasAction(SemanticsAction.tap)}');
      expect(size, const Size(22, 26));
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(data.label, isEmpty);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    semantics.dispose();
  });
}
