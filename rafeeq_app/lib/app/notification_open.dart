import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/db/azkar_repository.dart';
import '../features/azkar/data/azkar_categories.dart';
import '../features/azkar/presentation/screens/azkar_section_screen.dart';
import '../features/azkar/presentation/screens/tasbeeh_screen.dart';
import '../features/khatma/presentation/khatma_screen.dart';
import 'navigation.dart';

/// Where a reminder's `open:<what>` payload lands (`NotificationRouter`).
///
/// The adhkar, khatma and tasbih reminders carried no payload, so a tap
/// only brought the app to its Home tab and the reader had to find the
/// morning adhkar themselves (audit, 2026-09-24).
Future<void> openScreenFromPayload(String what) async {
  final navigator = rootNavigatorKey.currentState;
  if (navigator == null) return;
  Widget? screen;
  switch (what) {
    case 'azkar_morning' || 'azkar_evening' || 'azkar_sleep':
      final category = switch (what) {
        'azkar_morning' => AzkarCategory.morning,
        'azkar_evening' => AzkarCategory.evening,
        _ => AzkarCategory.sleep,
      };
      final repo = await ProviderScope.containerOf(navigator.context)
          .read(azkarRepositoryProvider.future);
      // The same filter the Adhkar hub applies when its card is tapped.
      final sections = (await repo.sections()).where((s) {
        final cats =
            azkarSectionCategories[s.id] ?? const [AzkarCategory.narrated];
        return cats.contains(category) && s.title != 'المقدمة';
      }).toList();
      if (sections.isEmpty) return;
      screen = AzkarSectionScreen(
        section: sections.first,
        accent: azkarCategoryInfo[category]!.gradient.last,
      );
    case 'khatma':
      screen = const KhatmaScreen();
    case 'tasbih':
      screen = const TasbeehScreen();
  }
  final target = screen;
  if (target == null) return; // an older build's payload: stay where it is
  await navigator.push(MaterialPageRoute<void>(builder: (_) => target));
}
