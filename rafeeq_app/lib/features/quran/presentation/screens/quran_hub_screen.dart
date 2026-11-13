import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/islamic_action_card.dart';
import '../../../../core/widgets/mosque_backdrop.dart' show MosquePhotos;
import '../../../../core/widgets/mosque_page_backdrop.dart';
import '../../../../core/widgets/paired_list_view.dart';
import '../../../hifz/presentation/hifz_screen.dart';
import '../../../khatma/presentation/khatma_card.dart';
import '../../../quran_audio/presentation/quran_audio_screen.dart';
import '../../../sunan_suwar/presentation/selected_surahs_card.dart';
import '../../../sunan_suwar/presentation/sunan_suwar_card.dart';
import '../../../tajweed/presentation/screens/tajweed_levels_screen.dart';
import '../../../tutorial/data/tutorial_anchors.dart';
import '../../data/quran_fullscreen_provider.dart';
import '../widgets/continue_reading_card.dart';
import 'sciences_pack_screen.dart';

/// The Quran tab's own page: everything about the Qur'an in one place, on a
/// calm mosque photograph (owner, 2026-11-14: «صفحة جديدة للقرآن يكون فيها
/// كل حاجة تخصه أقدر أروح منها للختمة وأي حاجة تخصه … وخلفية مسجد إسلامي
/// هادية جميلة»).
///
/// Top to bottom: the way into the mushaf (where the reader stopped, or
/// simply open it), the khatma, then what is read, listened to and learned, then
/// the surahs with a virtue. Sideways the cards go two a row.
class QuranHubScreen extends ConsumerWidget {
  const QuranHubScreen({super.key});

  void _push(BuildContext context, Widget screen) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    Widget heading(String key) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(
        key.tr(),
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: goldText(context),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('quran_hub.title'.tr()),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: MosquePageBackdrop(
        photo: MosquePhotos.vakil,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              // The way in: the mushaf itself, first and largest.
              IslamicActionCard(
                icon: Icons.menu_book_rounded,
                title: 'quran_hub.open_mushaf'.tr(),
                subtitle: 'quran_hub.open_mushaf_sub'.tr(),
                onTap: () =>
                    ref.read(quranHubShownProvider.notifier).state = false,
              ),
              const SizedBox(height: 12),
              // The khatma once only: its own card carries the progress and
              // opens the khatma screen (owner, 2026-11-14: «ختمة متكررة»).
              const PairedColumn(
                columnGap: 16,
                equalHeights: false,
                children: [
                  TutorialAnchor(
                    id: TourAnchor.continueReading,
                    child: ContinueReadingCard(),
                  ),
                  TutorialAnchor(
                    id: TourAnchor.khatmaCard,
                    child: KhatmaCard(),
                  ),
                ],
              ),
              heading('quran_hub.section_learn'),
              PairedColumn(
                columnGap: 16,
                children: [
                  IslamicActionCard(
                    icon: Icons.auto_stories_outlined,
                    accent: AppColors.info,
                    title: 'quran.sciences_pack'.tr(),
                    subtitle: 'quran_hub.sciences_sub'.tr(),
                    onTap: () => _push(context, const SciencesPackScreen()),
                  ),
                  IslamicActionCard(
                    icon: Icons.library_music_outlined,
                    accent: AppColors.primarySoft,
                    title: 'quran_audio.title'.tr(),
                    subtitle: 'quran_audio.subtitle'.tr(),
                    onTap: () => _push(context, const QuranAudioScreen()),
                  ),
                  IslamicActionCard(
                    icon: Icons.record_voice_over_outlined,
                    accent: AppColors.primarySoft,
                    title: 'tajweed.title'.tr(),
                    subtitle: 'tajweed.card_subtitle'.tr(),
                    onTap: () => _push(context, const TajweedLevelsScreen()),
                  ),
                  IslamicActionCard(
                    icon: Icons.school_outlined,
                    accent: AppColors.primarySoft,
                    title: 'hifz.title'.tr(),
                    subtitle: 'hifz.card_subtitle'.tr(),
                    onTap: () => _push(context, const HifzScreen()),
                  ),
                ],
              ),
              heading('quran_hub.section_surahs'),
              const PairedColumn(
                columnGap: 16,
                equalHeights: false,
                children: [
                  SelectedSurahsCard(),
                  TutorialAnchor(
                    id: TourAnchor.sunanCard,
                    child: SunanSuwarCard(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
