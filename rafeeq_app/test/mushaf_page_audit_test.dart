@Tags(['audit'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/db/models.dart';
import 'package:rafeeq_app/features/quran/data/mushaf_theme.dart';
import 'package:rafeeq_app/features/quran/data/text_layout_provider.dart';
import 'package:rafeeq_app/features/quran/presentation/widgets/mushaf_text_page.dart';

/// Every page of the text mushaf, laid out by the app's own `MushafTextPage`
/// with the real fonts at the owner's phone width (Honor, 1224 px at density
/// 3.25 = 376.6 dp), measured line by line (owner, 2026-10-02: «تشيك على
/// المصحف النصي صفحة صفحة … كلمة كلمة حرف حرف … ومسافات مظبوطة»).
///
/// For each justified line it records how far the justification stretched
/// the spaces between words, against the font's own space; and any text box
/// outside the paragraph. Writes build/audit/`lines_LAYOUT.json` and, with
/// RAFEEQ_AUDIT_PNG=1, a picture of each page.
///
/// Needs build/audit/quran.json (exported from quran_local.db). Run with:
///   RAFEEQ_AUDIT=1 flutter test test/mushaf_page_audit_test.dart
Future<void> _font(String family, String path) async {
  final bytes = File(path).readAsBytesSync();
  await (FontLoader(family)..addFont(Future.value(ByteData.view(bytes.buffer))))
      .load();
}

void main() {
  final run = Platform.environment['RAFEEQ_AUDIT'] == '1';
  final png = Platform.environment['RAFEEQ_AUDIT_PNG'] == '1';
  final only = Platform.environment['RAFEEQ_AUDIT_PAGES'];

  testWidgets('every text page, line by line', (tester) async {
    await _font('KFGQPCHafs', 'assets/fonts/KFGQPC-HAFS-Uthmanic-Script-v18.ttf');
    await _font('AmiriQuran', 'assets/fonts/AmiriQuran-Regular.ttf');
    final data = jsonDecode(File('build/audit/quran.json').readAsStringSync())
        as Map<String, dynamic>;
    final names = (data['names'] as Map<String, dynamic>)
        .map((k, v) => MapEntry(int.parse(k), v as String));
    final byPage = <int, List<Ayah>>{};
    for (final r in (data['ayahs'] as List).cast<Map<String, dynamic>>()) {
      final a = Ayah(
        id: r['id'] as int,
        surahId: r['s'] as int,
        ayahNumber: r['a'] as int,
        textUthmani: r['t'] as String,
        pageNumber: r['p'] as int,
        juzNumber: r['j'] as int,
      );
      byPage.putIfAbsent(a.pageNumber, () => []).add(a);
    }
    final pages = only == null
        ? [for (var p = 1; p <= 604; p++) p]
        : [for (final s in only.split(',')) int.parse(s)];

    tester.view.devicePixelRatio = 3.25;
    // Tall enough for a whole page laid out at once (embedded, no scroll).
    tester.view.physicalSize = const Size(1224, 9000);
    addTearDown(tester.view.reset);
    Directory('build/audit/png').createSync(recursive: true);

    for (final layout in [QuranTextLayout.page, QuranTextLayout.reading]) {
      final out = <Map<String, Object?>>[];
      for (final page in pages) {
        final shot = GlobalKey();
        await tester.pumpWidget(ProviderScope(
          child: MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: SingleChildScrollView(
                  child: RepaintBoundary(
                    key: shot,
                    child: MushafTextPage(
                      embedded: true,
                      layout: layout,
                      pageFillScreen: true,
                      mushafTheme:
                          resolveMushafTheme(null, Brightness.light),
                      ayahs: byPage[page]!,
                      surahNameOf: (s) => names[s] ?? '$s',
                      onAyahLongPress: (_) {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        ));
        await tester.pump();

        // The verse paragraphs: justified, in the Qur'an font.
        final paras = tester.allRenderObjects
            .whereType<RenderParagraph>()
            .where((p) => p.textAlign == TextAlign.justify)
            .toSet()
            .toList();
        for (var pi = 0; pi < paras.length; pi++) {
          final p = paras[pi];
          final text = p.text.toPlainText();
          TextStyle? style;
          p.text.visitChildren((span) {
            if (span is TextSpan &&
                span.style?.fontFamily == 'KFGQPCHafs') {
              style = span.style;
              return false;
            }
            return true;
          });
          // Not a verse paragraph (no Qur'an-font span in it).
          if (style == null) continue;
          // The font's own space at this size, unjustified.
          final natural = (TextPainter(
            text: TextSpan(text: ' ', style: style),
            textDirection: TextDirection.rtl,
          )..layout())
              .width;
          final lines = <double, List<double>>{};
          for (var i = 0; i < text.length; i++) {
            if (text[i] != ' ') continue;
            for (final b in p.getBoxesForSelection(
                TextSelection(baseOffset: i, extentOffset: i + 1))) {
              lines
                  .putIfAbsent(b.top.roundToDouble(), () => [])
                  .add(b.right - b.left);
            }
          }
          final tops = lines.keys.toList()..sort();
          // Ink outside the paragraph: a word cut off at either edge.
          var outside = 0;
          for (var i = 0; i < text.length; i++) {
            if (text[i] == ' ') continue;
            for (final b in p.getBoxesForSelection(
                TextSelection(baseOffset: i, extentOffset: i + 1))) {
              if (b.left < -1 || b.right > p.size.width + 1) outside++;
            }
          }
          for (var li = 0; li < tops.length; li++) {
            final gaps = lines[tops[li]]!;
            gaps.sort();
            out.add({
              'page': page,
              'para': pi,
              'line': li,
              'last': li == tops.length - 1,
              'spaces': gaps.length,
              'max': gaps.last / natural,
              'median': gaps[gaps.length ~/ 2] / natural,
              'outside': outside,
            });
          }
        }
        if (png) {
          final boundary =
              shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final img = await boundary.toImage(pixelRatio: 1.6);
            final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
            File('build/audit/png/${layout.name}_${page.toString().padLeft(3, '0')}.png')
                .writeAsBytesSync(bytes!.buffer.asUint8List());
          });
        }
      }
      File('build/audit/lines_${layout.name}.json')
          .writeAsStringSync(jsonEncode(out));
    }
  }, skip: !run, timeout: const Timeout(Duration(minutes: 60)));
}
