import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/theme/app_colors.dart';
import 'package:rafeeq_app/core/theme/app_theme.dart';
void main() {
  testWidgets('audit: default light action labels rendered below body contrast floor', (tester) async {
    final theme = AppTheme.light();
    await tester.pumpWidget(MaterialApp(theme: theme, home: Scaffold(body: DefaultTabController(length: 2, child: Column(children: [
      TextButton(onPressed: () {}, child: const Text('Audit text action')),
      OutlinedButton(onPressed: () {}, child: const Text('Audit outlined action')),
      const TabBar(tabs: [Tab(text: 'Audit selected tab'), Tab(text: 'Other')]),
    ])))));
    await tester.pump();
    for (final label in ['Audit text action','Audit outlined action','Audit selected tab']) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
      final style = paragraph.text.style!;
      final color = style.color ?? style.foreground!.color;
      final ratio = contrastRatio(color, theme.colorScheme.surface);
      print('AUDIT_CONTRAST: $label color=$color font=${style.fontSize} weight=${style.fontWeight} ground=${theme.colorScheme.surface} ratio=$ratio');
      expect(ratio, lessThan(4.5));
      expect(style.fontSize!, lessThan(18.66));
    }
  });
}
