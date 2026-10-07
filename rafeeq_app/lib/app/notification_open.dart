import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/db/azkar_repository.dart';
import '../features/azkar/data/adhkar_recitations.dart';
import '../features/azkar/data/azkar_categories.dart';
import '../features/azkar/data/azkar_settings_provider.dart';
import '../features/azkar/presentation/screens/adhkar_listen_screen.dart';
import '../features/azkar/presentation/screens/azkar_section_screen.dart';
import '../features/azkar/presentation/screens/tasbeeh_screen.dart';
import '../features/khatma/presentation/khatma_screen.dart';
import '../features/library/data/my_shelves.dart';
import '../features/library/presentation/my_library/shelf_screen.dart';
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
      final container = ProviderScope.containerOf(navigator.context);
      // A reciter chosen for this reminder: open that recording, playing.
      final settings = container.read(azkarSettingsProvider);
      final voice = switch (what) {
        'azkar_morning' => settings.morningVoice,
        'azkar_evening' => settings.eveningVoice,
        _ => null,
      };
      if (voice != null && adhkarRecitations.any((r) => r.id == voice)) {
        screen = AdhkarListenScreen(
          time: what == 'azkar_evening'
              ? AdhkarTime.evening
              : AdhkarTime.morning,
          autoplay: voice,
        );
        break;
      }
      final repo = await container.read(azkarRepositoryProvider.future);
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
    case final String w when w.startsWith('shelf:'):
      // A «مكتبتي» reading reminder: that shelf, if it still exists.
      final id = int.tryParse(w.substring('shelf:'.length));
      if (id == null) return;
      final container = ProviderScope.containerOf(navigator.context);
      if (container.read(shelvesProvider.notifier).byId(id) == null) return;
      screen = ShelfScreen(shelfId: id);
    case 'khatma':
      screen = const KhatmaScreen();
    case 'tasbih':
      screen = const TasbeehScreen();
  }
  final target = screen;
  if (target == null) return; // an older build's payload: stay where it is
  await navigator.push(MaterialPageRoute<void>(builder: (_) => target));
}
