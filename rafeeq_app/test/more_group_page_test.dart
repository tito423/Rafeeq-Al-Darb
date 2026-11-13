import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/more/presentation/widgets/more_group.dart';
import 'package:rafeeq_app/features/more/presentation/widgets/more_group_page.dart';

/// Owner, 2026-11-13 (phone sideways): a «المزيد» group opened in place
/// squeezed its cards into a third of the screen. Three a row it now opens
/// as a page across the whole width; upright on a phone it still opens in
/// place.
void main() {
  Widget app() => ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: ListView(
          children: const [
            MoreGroup(
              title: 'Group',
              subtitle: 'inside',
              icon: Icons.settings,
              children: [Text('child card')],
            ),
          ],
        ),
      ),
    ),
  );

  testWidgets('sideways a group opens as its own page', (tester) async {
    tester.view.physicalSize = const Size(900, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.tap(find.text('Group'));
    await tester.pumpAndSettle();
    expect(find.byType(MoreGroupPage), findsOneWidget);
    expect(find.text('child card'), findsOneWidget);
  });

  testWidgets('upright on a phone a group opens in place', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.tap(find.text('Group'));
    await tester.pumpAndSettle();
    expect(find.byType(MoreGroupPage), findsNothing);
    expect(find.text('child card'), findsOneWidget);
  });
}
