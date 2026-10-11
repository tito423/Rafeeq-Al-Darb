import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/db/models.dart';
import 'package:rafeeq_app/features/quran/data/mushaf_edition.dart';
import 'package:rafeeq_app/features/quran/data/quran_zoom_provider.dart';
import 'package:rafeeq_app/features/quran/data/text_layout_provider.dart';
import 'package:rafeeq_app/features/quran/presentation/widgets/mushaf_page_view.dart';
import 'package:rafeeq_app/features/quran/presentation/widgets/mushaf_text_page.dart';

const zoomModes = ['cards', 'page', 'reading', 'image'];

/// Synthetic geometric image: no religious content is created or modified.
Future<void> prepareZoomImage(Directory documents) async {
  final dir = Directory('${documents.path}/mushaf/audit_A26');
  await dir.create(recursive: true);
  await File('${dir.path}/001.svg').writeAsString(
    '<svg xmlns="http://www.w3.org/2000/svg" width="345" height="550">'
    '<rect width="345" height="550" fill="white"/>'
    '${List.filled(600, '<!-- lifecycle fixture -->').join()}'
    '</svg>',
  );
}

List<Ayah> zoomAyahs(String json) => [
  for (final row in (jsonDecode(json) as List).cast<Map<String, dynamic>>())
    Ayah(
      id: row['id'] as int,
      surahId: row['s'] as int,
      ayahNumber: row['a'] as int,
      textUthmani: row['t'] as String,
      pageNumber: row['p'] as int,
      juzNumber: row['j'] as int,
    ),
];

Widget _page(String mode, List<Ayah> ayahs) => mode == 'image'
    ? MushafPageView(
        edition: const MushafEdition(
          id: 'audit_A26',
          sourcePath: 'unused',
          nameAr: '',
          nameEn: '',
          riwayahAr: '',
          riwayahEn: '',
          polygonsAsset: '',
          pages: 1,
          ayahs: 0,
          sciencesAligned: false,
          divergingSurahs: {},
          isDefault: false,
        ),
        page: 1,
        highlight: null,
        onAyahLongPress: (_) {},
      )
    : MushafTextPage(
        ayahs: ayahs,
        layout: QuranTextLayout.fromName(mode),
        surahNameOf: (_) => '',
        onAyahLongPress: (_) {},
      );

Future<void> _ready(WidgetTester tester) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 30));
    if (find.byType(InteractiveViewer).evaluate().isNotEmpty) return;
  }
  fail('The actual reader did not create its InteractiveViewer');
}

Future<void> verifyZoomExit(
  WidgetTester tester,
  String mode,
  List<Ayah> ayahs, {
  required bool destroyScope,
  bool zoomed = true,
}) async {
  final container = destroyScope ? null : ProviderContainer();
  StateController<bool>? zoomState;
  final pageController = PageController();
  Widget body = Consumer(
    builder: (context, ref, _) {
      zoomState = ref.read(quranPageZoomedProvider.notifier);
      return PageView(
        controller: pageController,
        physics: ref.watch(quranPageZoomedProvider)
            ? const NeverScrollableScrollPhysics()
            : null,
        children: [_page(mode, ayahs), const SizedBox()],
      );
    },
  );
  Widget root(Widget child) {
    final app = MaterialApp(home: Scaffold(body: child));
    return container == null
        ? ProviderScope(child: app)
        : UncontrolledProviderScope(container: container, child: app);
  }

  try {
    await tester.pumpWidget(root(body));
    await _ready(tester);
    expect(tester.takeException(), isNull);
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    if (zoomed) {
      viewer.transformationController!.value = Matrix4.diagonal3Values(2, 2, 1);
      await tester.pump();
    }
    expect(zoomState!.state, zoomed);
    expect(
      tester.widget<PageView>(find.byType(PageView)).physics
          is NeverScrollableScrollPhysics,
      zoomed,
    );
    await tester.pumpWidget(
      destroyScope ? const SizedBox() : root(const SizedBox()),
    );
    await tester.pump();
    expect(
      tester.takeException(),
      isNull,
      reason: 'Leaving a reader must not access a disposed ref or notifier',
    );
    if (destroyScope) {
      expect(zoomState!.mounted, isFalse);
    } else {
      expect(container!.read(quranPageZoomedProvider), isFalse);
      await tester.pumpWidget(root(body));
      await _ready(tester);
      expect(
        tester.widget<PageView>(find.byType(PageView)).physics
            is NeverScrollableScrollPhysics,
        isFalse,
      );
      await tester.pumpAndSettle();
      final bounds = tester.getRect(find.byType(PageView));
      expect(pageController.position.viewportDimension, bounds.width);
      // Keep the entire swipe inside the device's actual viewport. A fixed
      // 600px displacement can leave a narrow phone's hit-test surface.
      await tester.timedDragFrom(
        Offset(bounds.right - bounds.width * .1, bounds.center.dy),
        Offset(-bounds.width * .8, 0),
        const Duration(milliseconds: 500),
      );
      await tester.pumpAndSettle();
      expect(
        pageController.page,
        1,
        reason:
            'viewport=${bounds.width}, axis=${pageController.position.axisDirection}',
      );
      expect(tester.takeException(), isNull);
    }
  } finally {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    pageController.dispose();
    container?.dispose();
  }
}
