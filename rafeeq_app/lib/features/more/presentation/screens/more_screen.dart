import 'package:easy_localization/easy_localization.dart';
import '../../../dedications/presentation/dedications_screen.dart';
import '../../../ruqyah/data/ruqyah_catalog.dart';
import '../../../../core/utils/digits.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/islamic_action_card.dart';
import '../../../downloads/presentation/screens/downloads_screen.dart';
import '../../../new_muslim/presentation/screens/new_muslim_guide_screen.dart';
import '../../../quran_audio/presentation/quran_audio_screen.dart';
import '../../../ruqyah/presentation/screens/ruqyah_audio_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../settings/presentation/widgets/focus_mode_picker.dart';
import '../../../hajj/presentation/hajj_screen.dart';
import '../../../tajweed/presentation/screens/tajweed_levels_screen.dart';
import '../../../../app/shell/tab_request_provider.dart';
import '../../../tutorial/data/tutorial_anchors.dart';
import '../../../tutorial/presentation/widgets/tutorial_entry_card.dart';
import '../widgets/sync_account_card.dart';
import '../../../support/presentation/screens/support_screen.dart';

/// The "المزيد" tab.
///
/// Ordered the way the owner asked for it: a **المزيد** section of destinations
/// first — listening to the ruqyah, the New Muslim guide, downloads — and then
/// **الإعدادات** with every actual setting underneath. Before this the tab
/// opened straight onto the language chips, which buried the three things
/// people came here to reach among controls they set once and never touch
/// again.
///
/// The whole tab is one scroll view: [SettingsBody] contributes a `Column`
/// rather than a `ListView` of its own, because a list inside a list scrolls
/// against itself and there is no reason for two of them here.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The one-time support sheet, asked for here and nowhere else: «تظهر مرة
    // واحدة في الأول». Not on Home, not over the mushaf, not during the adhan
    // — the More tab is where the reader is already looking at the app rather
    // than using it.
    //
    // **Which is not the same as building this screen.** `AppShell` keeps every
    // tab alive in an `IndexedStack`, so `MoreScreen` is built on the app's
    // very first frame whatever tab is showing — the same property trap #43 is
    // about. Posting the sheet from that first build put it on top of Home, and
    // on a fresh install on top of the welcome tour as well: two sheets stacked
    // over each other before the reader had touched anything. Seen on the
    // emulator, not reasoned about.
    //
    // So it waits for the tab to actually be on screen, and for the tour to be
    // over. `showSupportIntro` returns immediately once it has been seen, so
    // this costs one boolean read per build after that.
    final onThisTab = ref.watch(activeTabProvider) == AppTab.more;
    final tourRunning = ref.watch(tutorialRunningProvider);
    if (onThisTab && !tourRunning) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) showSupportIntro(context, ref);
      });
    }

    return Scaffold(
      appBar: AppBar(title: Text('nav.more'.tr())),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          // «عايزك ترتب قسم المزيد بشكل أحسن … يبقى فيه تقسيمات منطقية
          // للمتشابهات» (2026-09-19). Seven groups, each under its own
          // header: what the reader does with the Qur'an and worship, what
          // teaches, the tools, the reminders (out of the settings - they are
          // not set once and forgotten), the settings proper, the account,
          // and «عن التطبيق» at the very foot.
          _GroupHeader('more.group_worship'.tr(), Icons.auto_awesome_rounded),
          TutorialAnchor(
            id: TourAnchor.moreQuranAudio,
            child: IslamicActionCard(
              icon: Icons.library_music_outlined,
              accent: AppColors.gold,
              title: 'quran_audio.title'.tr(),
              subtitle: 'quran_audio.subtitle'.tr(),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const QuranAudioScreen(),
                ),
              ),
            ),
          ),

          TutorialAnchor(
            id: TourAnchor.moreTajweed,
            child: IslamicActionCard(
              icon: Icons.record_voice_over_outlined,
              accent: AppColors.gold,
              title: 'tajweed.title'.tr(),
              subtitle: 'tajweed.card_subtitle'.tr(),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const TajweedLevelsScreen(),
                ),
              ),
            ),
          ),

          IslamicActionCard(
            icon: Icons.mosque_outlined,
            accent: AppColors.gold,
            title: 'hajj.title'.tr(),
            subtitle: 'hajj.card_subtitle'.tr(),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const HajjScreen())),
          ),

          IslamicActionCard(
            icon: Icons.healing_outlined,
            accent: AppColors.goldSoft,
            title: 'ruqyah.audio_title'.tr(),
            subtitle: trn(
              'ruqyah.audio_intro',
              args: [
                pluralN('ruqyah.recordings_count', ruqyahRecordings.length),
              ],
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const RuqyahAudioScreen(),
              ),
            ),
          ),

          IslamicActionCard(
            icon: Icons.volunteer_activism,
            accent: AppColors.primarySoft,
            title: 'dedication.title'.tr(),
            subtitle: 'dedication.card_subtitle'.tr(),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const DedicationsScreen(),
              ),
            ),
          ),

          _GroupHeader('more.group_learning'.tr(), Icons.school_rounded),
          const TutorialEntryCard(),
          IslamicActionCard(
            icon: Icons.auto_stories_outlined,
            accent: AppColors.primarySoft,
            title: 'new_muslim.title'.tr(),
            subtitle: 'home.tap_to_open'.tr(),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const NewMuslimGuideScreen(),
              ),
            ),
          ),

          _GroupHeader('more.group_tools'.tr(), Icons.handyman_rounded),
          TutorialAnchor(
            id: TourAnchor.moreFocus,
            child: IslamicActionCard(
              icon: Icons.center_focus_strong_outlined,
              accent: AppColors.primarySoft,
              title: 'focus.title'.tr(),
              subtitle: 'focus.subtitle'.tr(),
              onTap: () => showFocusModePicker(context),
            ),
          ),

          TutorialAnchor(
            id: TourAnchor.moreDownloads,
            child: IslamicActionCard(
              icon: Icons.download_for_offline_outlined,
              accent: AppColors.info,
              title: 'downloads.title'.tr(),
              subtitle: 'downloads.offline_ready'.tr(),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DownloadsScreen(),
                ),
              ),
            ),
          ),

          _GroupHeader(
            'more.group_reminders'.tr(),
            Icons.notifications_active_rounded,
          ),
          const SettingsBody(part: SettingsPart.reminders),

          _GroupHeader('more.section_settings'.tr(), Icons.tune_rounded),
          const SettingsBody(),

          _GroupHeader('more.group_account'.tr(), Icons.cloud_sync_rounded),
          const SyncAccountCard(),

          _GroupHeader('settings.about'.tr(), Icons.info_outline_rounded),
          IslamicActionCard(
            icon: Icons.volunteer_activism_outlined,
            accent: AppColors.gold,
            title: 'support.title'.tr(),
            subtitle: 'support.entry_sub'.tr(),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SupportScreen()),
            ),
          ),

          const SettingsBody(part: SettingsPart.about),
        ],
      ),
    );
  }
}

/// A group's heading in «المزيد»: a gold badge, the name, and a hairline that
/// fades out - so seven groups read as seven places, not one long list.
class _GroupHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _GroupHeader(this.title, this.icon);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 22, 2, 10),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.gold, AppColors.gold.withValues(alpha: 0.7)],
              ),
            ),
            child: Icon(icon, size: 17, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.gold.withValues(alpha: 0.55),
                    AppColors.gold.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
