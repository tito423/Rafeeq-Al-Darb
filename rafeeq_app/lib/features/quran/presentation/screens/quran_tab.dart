import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../tutorial/data/tutorial_anchors.dart';
import '../../../tutorial/data/tutorial_state.dart';
import '../../data/quran_fullscreen_provider.dart';
import '../../data/quran_jump_provider.dart';
import 'quran_hub_screen.dart';
import 'quran_screen.dart';

/// The Quran tab: its hub first, the mushaf one tap away (owner,
/// 2026-11-14). The mushaf is kept alive under the hub, so it keeps its
/// page, its recitation and its own listeners while the hub is up.
///
/// The mushaf comes forward by itself when anything asks it for a page
/// (`quranJumpRequestProvider`: the khatma's «اقرأ», «متابعة القراءة», the
/// assistant) and while the guided tour runs, whose Quran chapter points
/// at the mushaf's own toolbar. Back from the mushaf, or a tap on the
/// Quran tab while in it, returns to the hub (`AppShell`).
class QuranTab extends ConsumerWidget {
  const QuranTab({super.key});

  /// The tour stops that frame a card on the Quran page.
  static const _hubAnchors = {
    TourAnchor.continueReading,
    TourAnchor.khatmaCard,
    TourAnchor.sunanCard,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<int?>(quranJumpRequestProvider, (_, page) {
      if (page != null) ref.read(quranHubShownProvider.notifier).state = false;
    });
    // While the tour runs: the page for the stops on its own cards, the
    // mushaf for the rest (they point at the mushaf's toolbar).
    final hub = ref.watch(tutorialRunningProvider)
        ? _hubAnchors.contains(ref.watch(tutorialAnchorProvider))
        : ref.watch(quranHubShownProvider);
    return IndexedStack(
      index: hub ? 0 : 1,
      children: const [QuranHubScreen(), QuranScreen()],
    );
  }
}
