import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../settings/presentation/screens/settings_screen.dart';

/// P3‑54: the "المزيد" (More) bottom-nav tab. Real-device feedback asked for
/// the app's settings/options to live behind a proper tab rather than a lone
/// gear icon crammed into the Home header card — so every option that used to
/// sit on `SettingsScreen` now surfaces here, under a tab of its own at the
/// end of the bottom bar (visually left-most under RTL).
///
/// The body is the shared [SettingsBody] — the single source of truth for the
/// list of options — so this tab and the stand-alone `SettingsScreen` can
/// never drift apart. This screen only supplies the "المزيد" AppBar title and
/// its own `Scaffold`, since `AppShell` hosts it inside an `IndexedStack`
/// (each tab is expected to bring its own scaffolding).
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('nav.more'.tr())),
      body: const SettingsBody(),
    );
  }
}
