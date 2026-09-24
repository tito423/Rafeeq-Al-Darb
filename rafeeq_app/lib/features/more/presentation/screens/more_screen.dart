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
import '../../../hifz/presentation/hifz_screen.dart';
import '../../../tajweed/presentation/screens/tajweed_levels_screen.dart';
import '../../../../app/shell/tab_request_provider.dart';
import '../../../tutorial/data/tutorial_anchors.dart';
import '../../../tutorial/presentation/widgets/tutorial_entry_card.dart';
import '../widgets/more_group.dart';
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
          // «خلّي كل قسم كولابسد في المزيد يبقى له كروت بنفس شكل القرآن
          // والعبادات … وخلّي كل شيء كولابسد حتى شرح التطبيق» (2026-09-19):
          // each group is one card that opens onto its own cards. The
          // new-Muslim guide moved into worship when «التعلّم والإرشاد»
          // became «شرح ميزات واستخدام التطبيق» - it is not about the app.
          // «خلي كل كارت رئيسي لون مختلف عن اللي تحتيه ... وكل الكروت
          // الفرعية في كل قسم تاخد نفس لون الكارت الرئيسي» (2026-09-24):
          // gold, info, primarySoft, error, info, gold top to bottom - no
          // two neighbours alike. Children inherit through MoreGroupAccent.
          MoreGroup(
            title: 'more.group_worship'.tr(),
            accent: AppColors.gold,
            subtitle: _names([
              'quran_audio.title',
              'tajweed.title',
              'hajj.title',
              'ruqyah.audio_title',
              'dedication.title',
              'new_muslim.title',
            ]),
            icon: Icons.auto_awesome_rounded,
            children: [
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
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const HajjScreen()),
                ),
              ),

              // «ممكن نعمل قسم لتحفيظ القرآن الكريم وتسميعه» (2026-09-22).
              IslamicActionCard(
                icon: Icons.school_outlined,
                accent: AppColors.gold,
                title: 'hifz.title'.tr(),
                subtitle: 'hifz.card_subtitle'.tr(),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const HifzScreen()),
                ),
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
            ],
          ),
          // «افصل التنزيلات عن الادوات وحط شرح ميزات التطبيق مكان التنزيلات
          // في الادوات». Downloads is a place you go to manage half a
          // gigabyte; it is not a tool you reach for beside focus mode. So it
          // is a card of its own, and the tour - which IS a tool, and was
          // taking a whole group to hold one card - takes the seat it left.
          // «التنزيلات كارتين فوق بعض نفس المهمة» - giving it a `MoreGroup`
          // of its own put its title and subtitle on the group header AND on
          // the one card inside it, one directly under the other. It is a
          // destination, not a group: a single card that opens the screen.
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
          MoreGroup(
            title: 'more.group_tools'.tr(),
            subtitle: _names(['focus.title', 'tutorial.card_title']),
            icon: Icons.handyman_rounded,
            accent: AppColors.primarySoft,
            children: [
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
              const TutorialEntryCard(),
            ],
          ),
          MoreGroup(
            title: 'more.group_reminders'.tr(),
            subtitle: _names([
              'sunan_suwar.reminders_section_title',
              'tasbih.section_title',
              'fasting.section_title',
              'quotes.section_title',
            ]),
            icon: Icons.notifications_active_rounded,
            accent: AppColors.error,
            children: const [SettingsBody(part: SettingsPart.reminders)],
          ),
          MoreGroup(
            title: 'more.section_settings'.tr(),
            subtitle: _names([
              'settings.language',
              'settings.theme',
              'settings.splash_section',
              'home.clock_section',
              'mushaf_theme.title',
              'settings.permissions',
              'library.voice_section_title',
            ]),
            icon: Icons.tune_rounded,
            accent: AppColors.info,
            // «حط الحساب والمزامنة في الاعدادات». It had a group of its own
            // holding one card, between the settings and «عن التطبيق», which
            // is where a setting belongs anyway.
            children: const [SettingsBody(), SyncAccountCard()],
          ),
          MoreGroup(
            title: 'settings.about'.tr(),
            subtitle: _names([
              'support.title',
              'settings.credits',
              'settings.privacy_policy',
            ]),
            icon: Icons.info_outline_rounded,
            children: [
              IslamicActionCard(
                icon: Icons.volunteer_activism_outlined,
                accent: AppColors.gold,
                title: 'support.title'.tr(),
                subtitle: 'support.entry_sub'.tr(),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SupportScreen(),
                  ),
                ),
              ),

              const SettingsBody(part: SettingsPart.about),
            ],
          ),
        ],
      ),
    );
  }
}

/// A closed group's subtitle: the names of what it holds.
String _names(List<String> keys) => keys.map((k) => k.tr()).join(' · ');
