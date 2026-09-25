import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/widgets/paired_list_view.dart';

// Sideways, card lists stand two a row. The index arithmetic (header, footer,
// an odd last card) is where such a list silently drops or repeats an item,
// so every item is checked present once, in reading order, both ways.
void main() {
  Future<void> pump(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PairedListView.builder(
          header: const Text('HEAD'),
          footer: const Text('FOOT'),
          itemCount: 5,
          itemBuilder: (_, i) => SizedBox(height: 40, child: Text('c$i')),
        ),
      ),
    ));
  }

  testWidgets('upright: one a row, header first, footer last', (tester) async {
    await pump(tester, const Size(400, 900));
    final ys = [
      for (final t in ['HEAD', 'c0', 'c1', 'c2', 'c3', 'c4', 'FOOT'])
        tester.getTopLeft(find.text(t)).dy,
    ];
    for (var i = 1; i < ys.length; i++) {
      expect(ys[i], greaterThan(ys[i - 1]));
    }
  });

  testWidgets('sideways: two a row in reading order, odd card alone',
      (tester) async {
    await pump(tester, const Size(900, 400));
    for (final t in ['HEAD', 'c0', 'c1', 'c2', 'c3', 'c4', 'FOOT']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    double y(String t) => tester.getTopLeft(find.text(t)).dy;
    double x(String t) => tester.getTopLeft(find.text(t)).dx;
    expect(y('c0'), y('c1'));
    expect(y('c2'), y('c3'));
    expect(y('c2'), greaterThan(y('c0')));
    expect(y('c4'), greaterThan(y('c2')));
    expect(x('c0'), lessThan(x('c1')), reason: 'LTR: first card on the left');
    expect(y('HEAD'), lessThan(y('c0')));
    expect(y('FOOT'), greaterThan(y('c4')));
  });
}
