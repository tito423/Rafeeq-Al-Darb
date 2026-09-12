import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/islamic_action_card.dart';
import '../../../downloads/presentation/screens/downloads_screen.dart';
import '../../../new_muslim/presentation/screens/new_muslim_guide_screen.dart';
import '../../../quran_audio/presentation/quran_audio_screen.dart';
import '../../../ruqyah/presentation/screens/ruqyah_audio_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../tutorial/presentation/widgets/tutorial_entry_card.dart';

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
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('nav.more'.tr())),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          SectionLabel('more.section_more'.tr()),

          // The guided tour, first in the section: it is the thing a reader
          // who is lost comes here looking for, and it carries its own
          // every-launch switch rather than sending them down to Settings.
          const TutorialEntryCard(),

          // «انشئ في المزيد قسم جديد سميه تحميل تلاوات القرآن … عبارة عن
          // music player احترافي». First, because it is the one he asked for.
          IslamicActionCard(
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

          IslamicActionCard(
            icon: Icons.healing_outlined,
            accent: AppColors.goldSoft,
            title: 'ruqyah.audio_title'.tr(),
            subtitle: 'ruqyah.audio_intro'.tr(),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const RuqyahAudioScreen(),
              ),
            ),
          ),

          // The Islamic-channels card used to sit here as well as in the
          // Library's own "القنوات" tab — two routes to the same screen, which
          // the owner found while using it. The Library is where the app
          // already keeps its directories of external content (books, hadith,
          // channels, websites), so the duplicate here is the one that goes.
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

          IslamicActionCard(
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

          const SizedBox(height: 14),
          SectionLabel('more.section_settings'.tr()),

          // Everything that is genuinely a setting, below the destinations.
          const SettingsBody(),
        ],
      ),
    );
  }
}
