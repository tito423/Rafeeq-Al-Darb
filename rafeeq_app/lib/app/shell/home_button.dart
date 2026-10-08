import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tab_request_provider.dart';

/// One tap back to the Home tab from deep inside a pushed screen.
///
/// Owner, 2026-10-08: from the recitation player it took five back presses
/// to reach Home (player, reciter, reciter list, the «المزيد» group, the
/// tab). This unwinds every pushed screen down to the shell and selects
/// Home; playback is not touched, so the mini player carries on.
class HomeButton extends ConsumerWidget {
  final Color? color;
  const HomeButton({super.key, this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
    tooltip: 'nav.home'.tr(),
    color: color,
    icon: const Icon(Icons.home_outlined),
    onPressed: () {
      Navigator.of(context).popUntil((r) => r.isFirst);
      ref.read(requestedTabProvider.notifier).state = AppTab.home;
    },
  );
}
