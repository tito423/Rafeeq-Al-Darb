import 'dart:convert';

import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/theme/app_colors.dart';
import 'package:rafeeq_app/core/theme/app_theme.dart';
import 'package:rafeeq_app/core/widgets/toolbar_action.dart';
import 'package:rafeeq_app/features/quran/presentation/widgets/ayah_sciences/sciences_common.dart';

const contrastLocales = ['ar', 'en', 'fr', 'es', 'pt', 'ru', 'ur'];
const contrastThemes = ['light', 'dark', 'rgb'];

Future<void> verifyActionContrast(
  WidgetTester tester,
  String locale,
  String themeName,
) async {
  // Large translation assets decode in an isolate outside widget fake time.
  final source = await tester.runAsync(
    () => rootBundle.loadString('assets/translations/$locale.json'),
  );
  final values = jsonDecode(source!) as Map<String, dynamic>;
  Localization.load(Locale(locale), translations: Translations(values));
  String label(String group, String key) =>
      (values[group] as Map<String, dynamic>)[key] as String;
  final cancel = label('common', 'cancel');
  final save = label('common', 'save');
  final page = label('quran', 'page');
  final theme = switch (themeName) {
    'light' => AppTheme.light(),
    'dark' => AppTheme.dark(),
    'rgb' => AppTheme.rgb(),
    _ => throw ArgumentError.value(themeName),
  };
  final ground = theme.colorScheme.surface.withAlpha(255);
  const textKey = ValueKey('text-action');
  const outlineKey = ValueKey('outline-action');
  const tabsKey = ValueKey('tabs');
  const toolbarKey = ValueKey('toolbar');
  const sourceKey = ValueKey('source');
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: ColoredBox(
          color: ground,
          child: Directionality(
            textDirection: locale == 'ar' || locale == 'ur'
                ? TextDirection.rtl
                : TextDirection.ltr,
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TextButton(
                    key: textKey,
                    onPressed: _noop,
                    child: Text(cancel),
                  ),
                  OutlinedButton(
                    key: outlineKey,
                    onPressed: _noop,
                    child: Text(save),
                  ),
                  TabBar(
                    key: tabsKey,
                    tabs: [
                      Tab(text: page),
                      Tab(text: save),
                    ],
                  ),
                  ToolbarAction(
                    key: toolbarKey,
                    icon: Icons.bookmark,
                    label: save,
                    active: true,
                    onPressed: _noop,
                  ),
                  KeyedSubtree(
                    key: sourceKey,
                    child: SourceBlock(
                      title: page,
                      subtitle: cancel,
                      body: save,
                      direction: TextDirection.ltr,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  for (final (key, text, background) in [
    (textKey, cancel, ground),
    (outlineKey, save, ground),
    (tabsKey, page, ground),
    (
      toolbarKey,
      save,
      Color.alphaBlend(AppColors.gold.withValues(alpha: 0.14), ground),
    ),
    (sourceKey, page, ground),
    (sourceKey, cancel, ground),
  ]) {
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: find.byKey(key), matching: find.text(text)),
    );
    final style = paragraph.text.style!;
    final color = style.color ?? style.foreground!.color;
    final ratio = contrastRatio(
      Color.alphaBlend(color, background),
      background,
    );
    if (locale == 'ar') {
      debugPrint('ACTION_CONTRAST $themeName/${key.value}: $ratio');
    }
    expect(
      ratio,
      greaterThanOrEqualTo(4.5),
      reason: '$themeName/$locale/${key.value}: $ratio',
    );
  }
  for (final (kind, style) in [
    ('text', theme.textButtonTheme.style!),
    ('outlined', theme.outlinedButtonTheme.style!),
  ]) {
    verifyActionStateContrast(style, ground, '$themeName/$locale/$kind');
  }
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox.shrink());
}

void _noop() {}

void verifyActionStateContrast(ButtonStyle style, Color ground, String label) {
  for (final state in [
    WidgetState.pressed,
    WidgetState.focused,
    WidgetState.hovered,
  ]) {
    final states = {state};
    final foreground = style.foregroundColor!.resolve(states)!;
    final overlay = style.overlayColor!.resolve(states)!;
    final background = Color.alphaBlend(overlay, ground);
    final ratio = contrastRatio(foreground, background);
    expect(ratio, greaterThanOrEqualTo(4.5), reason: '$label/$state: $ratio');
  }
}
