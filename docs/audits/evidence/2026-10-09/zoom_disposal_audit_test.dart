import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/db/models.dart';
import 'package:rafeeq_app/features/quran/data/quran_zoom_provider.dart';
import 'package:rafeeq_app/features/quran/data/text_layout_provider.dart';
import 'package:rafeeq_app/features/quran/presentation/widgets/mushaf_text_page.dart';

void main() {
  testWidgets('audit: leaving zoomed text page reads disposed ref and leaves zoom true', (tester) async {
    final rows = jsonDecode(File('test/fixtures/page_303.json').readAsStringSync()) as List;
    final ayahs = [for (final r in rows) Ayah(id: r['id'], surahId: r['s'], ayahNumber: r['a'], textUthmani: r['t'], pageNumber: r['p'], juzNumber: r['j'])];
    final container = ProviderContainer();
    addTearDown(container.dispose);
    Widget root(Widget body) => UncontrolledProviderScope(container: container, child: MaterialApp(home: Scaffold(body: body)));
    await tester.pumpWidget(root(MushafTextPage(ayahs: ayahs, layout: QuranTextLayout.cards, surahNameOf: (_) => 'الكهف', onAyahLongPress: (_) {})));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final viewer = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    viewer.transformationController!.value = Matrix4.diagonal3Values(2, 2, 1);
    await tester.pump();
    expect(container.read(quranPageZoomedProvider), isTrue);
    await tester.pumpWidget(root(const SizedBox()));
    final error = tester.takeException();
    print('AUDIT_ZOOM_DISPOSAL: error=$error zoom=${container.read(quranPageZoomedProvider)}');
    expect(error.toString(), contains('Cannot use "ref" after the widget was disposed'));
    expect(container.read(quranPageZoomedProvider), isTrue);
  });
}
