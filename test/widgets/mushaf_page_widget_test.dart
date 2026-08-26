import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rafeeq_app/features/quran/presentation/widgets/mushaf_page_widget.dart';
import 'package:rafeeq_app/features/quran/domain/models/ayah.dart';
import 'package:rafeeq_app/core/models/mushaf_style.dart';
import 'package:rafeeq_app/features/quran/presentation/providers/page_verse_provider.dart';

void main() {
  testWidgets('MushafPageWidget scaling and rendering test', (WidgetTester tester) async {
    // Create dummy coordinate data
    final Map<int, List<MushafAyahCoord>> coords = {
      2: [
        MushafAyahCoord(
          surah: 1,
          ayah: 2,
          part: 1,
          x: 100,
          y: 200,
          w: 300,
          h: 50,
        )
      ]
    };

    final styleInfo = MushafStyleInfo(
      style: MushafStyle.medina1,
      id: 'Medina1',
      nameAr: 'المدينة 1',
      nameEn: 'Medina 1',
      description: '',
      riwayah: '',
      totalPages: 604,
      category: '',
      localThumbCover: '',
      localThumbPage1: '',
      localThumbPage2: '',
      githubUrl: '',
      s3FallbackUrl: '',
      baseWidth: 800,
      baseHeight: 1200,
    );

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 400, // half width
            height: 600, // half height
            child: MushaafPageWidget(
              pageNumber: 1,
              styleInfo: styleInfo,
              coordsByAyah: coords,
              onAyahTapped: (ayahId) {},
              highlightedAyahId: 2, // highlight ayah 2
              isDarkMode: false,
            ),
          ),
        ),
      ),
    )));

    // Allow UI to settle
    await tester.pumpAndSettle();

    // Verify the highlight box exists (AnimatedContainer with decoration)
    final highlightFinder = find.byType(AnimatedContainer);
    expect(highlightFinder, findsWidgets);

    // Get the Positioned widget wrapping the AnimatedContainer
    final Positioned positioned = tester.widget<Positioned>(
      find.ancestor(
        of: highlightFinder.first,
        matching: find.byType(Positioned),
      ).first
    );

    // Assert coordinates are scaled correctly (scale = 0.5)
    // Original x=100, y=200, w=300, h=50
    // Expected x=50, y=100, w=150, h=25
    expect(positioned.left, 50.0);
    expect(positioned.top, 100.0);
    expect(positioned.width, 150.0);
    expect(positioned.height, 25.0);
  });
}
