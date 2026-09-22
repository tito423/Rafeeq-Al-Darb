import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/widgets/accordion.dart';

/// The owner's two rules for cards that open in place (2026-09-22): one
/// open at a time, and back closes the open one before it leaves.
void main() {
  Widget tile(String name) => AccordionTile(
    builder: (controller, onChanged) => ExpansionTile(
      controller: controller,
      onExpansionChanged: onChanged,
      title: Text(name),
      children: [SizedBox(height: 80, child: Text('$name body'))],
    ),
  );

  Future<void> pumpList(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const Scaffold(body: Text('home')),
        routes: {
          '/list': (_) => Scaffold(
            body: ListView(children: [tile('A'), tile('B')]),
          ),
        },
      ),
    );
    tester.state<NavigatorState>(find.byType(Navigator)).pushNamed('/list');
    await tester.pumpAndSettle();
  }

  testWidgets('opening one card closes the other', (tester) async {
    await pumpList(tester);
    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();
    expect(find.text('A body'), findsOneWidget);

    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();
    expect(find.text('B body'), findsOneWidget);
    expect(find.text('A body'), findsNothing);
  });

  testWidgets('back closes the open card, and only then leaves', (
    tester,
  ) async {
    await pumpList(tester);
    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('A body'), findsNothing, reason: 'the card closed');
    expect(find.text('A'), findsOneWidget, reason: 'the screen stayed');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget, reason: 'now it leaves');
  });
}
