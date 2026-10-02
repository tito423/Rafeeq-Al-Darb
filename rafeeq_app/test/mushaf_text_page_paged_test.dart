import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/db/models.dart';
import 'package:rafeeq_app/features/quran/data/mushaf_theme.dart';
import 'package:rafeeq_app/features/quran/data/text_layout_provider.dart';
import 'package:rafeeq_app/features/quran/presentation/widgets/mushaf_text_page.dart';

/// A text page laid out the way the Qur'an tab lays it out — on its own,
/// in its own scroll view (`SliverFillRemaining`), NOT embedded — must draw
/// its verses. On 2026-10-02 the kashida's `LayoutBuilder` inside the verse
/// paragraph threw under `SliverFillRemaining`'s intrinsic-height query and
/// the page came up blank on emulator-5554, while every embedded-page test
/// passed.
Future<void> _font(String family, String path) async {
  final bytes = File(path).readAsBytesSync();
  await (FontLoader(family)..addFont(Future.value(ByteData.view(bytes.buffer))))
      .load();
}

void main() {
  for (final layout in QuranTextLayout.values) {
    for (final fill in [true, false]) {
      testWidgets('page 303, ${layout.name}, full screen $fill', (t) async {
        await _font('KFGQPCHafs', 'assets/fonts/KFGQPC-HAFS-Uthmanic-Script-v18.ttf');
        final ayahs = <Ayah>[
          // al-Kahf 84-98, page 303, from the bundled database.
          for (final r in _page303()) r,
        ];
        t.view.devicePixelRatio = 3.25;
        t.view.physicalSize = const Size(1224, 2700);
        addTearDown(t.view.reset);
        await t.pumpWidget(ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MushafTextPage(
                layout: layout,
                pageFillScreen: fill,
                mushafTheme: resolveMushafTheme(null, Brightness.light),
                ayahs: ayahs,
                surahNameOf: (_) => 'الكهف',
                onAyahLongPress: (_) {},
              ),
            ),
          ),
        ));
        await t.pump();
        expect(t.takeException(), isNull);
        // The verses are drawn: a paragraph in the Qur'an font, with height.
        final paras = t.allRenderObjects.whereType<RenderParagraph>().where(
            (p) => p.text.toPlainText().contains('ٱلۡأَرۡضِ'));
        expect(paras, isNotEmpty);
        expect(paras.first.size.height, greaterThan(40));
        // The flowing layouts fill their lines by kashida one frame later.
        if (layout != QuranTextLayout.cards) {
          await t.pump();
          final source = ayahs.map((a) => a.textUthmani).join();
          final drawn = t.allRenderObjects
              .whereType<RenderParagraph>()
              .map((p) => p.text.toPlainText())
              .join();
          expect('\u0640'.allMatches(drawn).length,
              greaterThan('\u0640'.allMatches(source).length),
              reason: 'no kashida drawn');
        }
      });
    }
  }
}

List<Ayah> _page303() {
  final d = jsonDecode(File('test/fixtures/page_303.json').readAsStringSync())
      as List;
  return [
    for (final r in d.cast<Map<String, dynamic>>())
      Ayah(
        id: r['id'] as int,
        surahId: r['s'] as int,
        ayahNumber: r['a'] as int,
        textUthmani: r['t'] as String,
        pageNumber: r['p'] as int,
        juzNumber: r['j'] as int,
      ),
  ];
}
