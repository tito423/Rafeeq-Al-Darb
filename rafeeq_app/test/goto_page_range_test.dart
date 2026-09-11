import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/utils/byte_formatter.dart' show ltr;
import 'package:rafeeq_app/features/quran/presentation/widgets/mushaf_nav_sheets.dart';

/// «الانتقال إلى» used to accept any page from 1 to a hard-coded 604.
///
/// Three of the nine printings do not have 604 pages — Shamarly has 521,
/// Indo-Pak 564, Nastaleeq 611 — so the number the reader typed was checked
/// against a different mushaf's length: pages 605–611 of the Nastaleeq were
/// refused with no message, and page 600 of the Shamarly was accepted and
/// scrolled to nothing.
///
/// The 611 case is the one that proves the fix: it fails on the old code.
Future<void> _open(
  WidgetTester tester, {
  required int totalPages,
  required void Function(int) onSelect,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => showGotoPageSheet(
              context,
              current: 1,
              totalPages: totalPages,
              onSelect: onSelect,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('page 607 is reachable in a 611-page printing', (tester) async {
    int? picked;
    await _open(tester, totalPages: 611, onSelect: (p) => picked = p);

    await tester.enterText(find.byType(TextField), '607');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(picked, 607);
  });

  testWidgets('page 600 is refused in a 521-page printing', (tester) async {
    int? picked;
    await _open(tester, totalPages: 521, onSelect: (p) => picked = p);

    await tester.enterText(find.byType(TextField), '600');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(picked, isNull);
  });

  testWidgets('the range is written where the reader can see it, and it '
      'reads left to right', (tester) async {
    await _open(tester, totalPages: 521, onSelect: (_) {});

    // Trap #16: «1 – 521» is bidi-weak and rendered «521 – 1» in the Arabic
    // dialog on the emulator. It is wrapped in U+2066 … U+2069, so the plain
    // string is deliberately NOT what is on screen.
    expect(find.text('1 – 521'), findsNothing);
    expect(find.text(ltr('1 – 521')), findsOneWidget);
  });
}
