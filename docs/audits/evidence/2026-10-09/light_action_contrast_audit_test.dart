import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/theme/app_colors.dart';
import 'package:rafeeq_app/core/theme/app_theme.dart';
import 'package:rafeeq_app/core/widgets/toolbar_action.dart';
import 'package:rafeeq_app/features/quran/presentation/widgets/ayah_sciences/sciences_common.dart';
void main() {
  testWidgets('audit: default light action labels rendered below body contrast floor', (tester) async {
    final theme = AppTheme.light();
    await tester.pumpWidget(MaterialApp(theme: theme, home: Scaffold(body: DefaultTabController(length: 2, child: Column(children: [
      TextButton(onPressed: () {}, child: const Text('Audit text action')),
      OutlinedButton(onPressed: () {}, child: const Text('Audit outlined action')),
      const TabBar(tabs: [Tab(text: 'Audit selected tab'), Tab(text: 'Other')]),
      const ToolbarAction(icon: Icons.bookmark, label: 'Audit active caption', active: true, onPressed: _noop),
      const SourceBlock(title: 'Audit source title', body: 'Body', direction: TextDirection.ltr),
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
    for (final label in ['Audit active caption', 'Audit source title']) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
      final style = paragraph.text.style!;
      final color = style.color!;
      final background = label == 'Audit active caption'
          ? Color.alphaBlend(AppColors.gold.withValues(alpha: 0.14), theme.colorScheme.surface)
          : theme.colorScheme.surface;
      final ratio = contrastRatio(color, background);
      print('AUDIT_GOLD_CONTRAST: $label color=$color font=${style.fontSize} ground=$background ratio=$ratio');
      expect(ratio, lessThan(3));
    }
  });
}
void _noop() {}
