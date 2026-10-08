import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../azkar/presentation/screens/adhkar_listen_row.dart';
import '../../../caravan/presentation/caravan_screen.dart';
import '../../../dedications/presentation/dedications_screen.dart';
import '../../../dorar/presentation/dorar_hub_screen.dart';
import '../../../downloads/presentation/screens/downloads_screen.dart';
import '../../../hajj/presentation/hajj_screen.dart';
import '../../../hifz/presentation/hifz_screen.dart';
import '../../../kids/presentation/journey_screen.dart';
import '../../../kids/presentation/kids_corner_screen.dart';
import '../../../quiz/presentation/quiz_home_screen.dart';
import '../../../quran_audio/presentation/quran_audio_screen.dart';
import '../../../ruqyah/presentation/screens/ruqyah_audio_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../settings/presentation/widgets/focus_mode_picker.dart';
import '../../../tajweed/presentation/screens/tajweed_levels_screen.dart';

/// «كارت كبير في وصلات سريعة للحاجة اللي في كارت القرآن والعبادات من
/// المزيد» (owner, 2026-10-01). The same destinations as the «القرآن
/// والعبادات» group in More, in the same order, one tap from Home instead of
/// three. Icons and accents match the More cards so a tile looks like the
/// card it leads to. Renamed «الوصول السريع» and given «استمع إلى الأذكار»
/// first (owner, 2026-10-03).
///
/// A third row (owner, 2026-10-08: «زود اسم اللعبة في الوصول السريع بشكل
/// يخلي الكارت متنسق او ممكن تزود صف ايقونات سريع من المزيد»): one tile
/// for the game alone would have stood by itself on a row, so a whole row
/// of five: the game, al-Durar al-Saniyya, the reminders, focus mode and
/// downloads. Not the khatma: Home already has its card a little further
/// down («خد بالك عشان ميبقاش فيه حاجة مكررة في الشاشة الرئيسية»).
/// Labels are the keys the cards they open already use, so a tile reads
/// exactly as its card, in every language.
class WorshipQuickLinks extends StatelessWidget {
  const WorshipQuickLinks({super.key});

  // «خلي الوان الوصول السريع … كل لون مختلف عن التاني» (owner, 2026-10-05):
  // ten hues spaced round the wheel, all bright enough for the dark theme.
  static final _links = <_Link>[
    _Link(Icons.headphones_rounded, 'home.ql_azkar_listen', const Color(0xFFD35400), (_) => const AdhkarListenHubScreen()),
    _Link(Icons.library_music_outlined, 'home.ql_player', AppColors.gold, (_) => const QuranAudioScreen()),
    _Link(Icons.record_voice_over_outlined, 'home.ql_tajweed', const Color(0xFF00A896), (_) => const TajweedLevelsScreen()),
    _Link(Icons.school_outlined, 'home.ql_hifz', const Color(0xFF0984E3), (_) => const HifzScreen()),
    _Link(Icons.mosque_outlined, 'home.ql_hajj', const Color(0xFF7CB342), (_) => const HajjScreen()),
    _Link(Icons.healing_outlined, 'home.ql_ruqyah', const Color(0xFF78909C), (_) => const RuqyahAudioScreen()),
    _Link(Icons.child_care_rounded, 'home.ql_kids', const Color(0xFFD63384), (_) => const KidsCornerScreen()),
    _Link(Icons.emoji_events_rounded, 'home.ql_journey', const Color(0xFF8854D0), (_) => const JourneyScreen()),
    _Link(Icons.quiz_rounded, 'home.ql_quiz', const Color(0xFF4834D4), (_) => const QuizHomeScreen()),
    _Link(Icons.volunteer_activism, 'home.ql_dedications', const Color(0xFFE74C3C), (_) => const DedicationsScreen()),
    _Link(Icons.route_rounded, 'caravan.title', const Color(0xFFE1A623), (_) => const CaravanScreen()),
    _Link(Icons.fact_check_outlined, 'dorar.hub_title', const Color(0xFF16A085), (_) => const DorarHubScreen()),
    _Link(Icons.notifications_active_outlined, 'more.group_reminders', const Color(0xFFC0392B), (_) => const _RemindersPage()),
    const _Link(Icons.center_focus_strong_outlined, 'focus.title', Color(0xFF5D6D7E), null, onTap: showFocusModePicker),
    _Link(Icons.download_for_offline_outlined, 'downloads.title', const Color(0xFF2E86C1), (_) => const DownloadsScreen()),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8),
              child: Row(children: [
                const Icon(Icons.auto_awesome_rounded, color: AppColors.gold, size: 20),
                const SizedBox(width: 8),
                Text('home.quick_access'.tr(), style: theme.textTheme.titleMedium),
              ]),
            ),
            LayoutBuilder(builder: (context, box) {
              // Five a row: three full rows on a phone; wider screens keep
              // five a row too, so fifteen never leaves a short last row.
              const cols = 5;
              final w = box.maxWidth / cols;
              return Wrap(
                children: [
                  for (final l in _links) SizedBox(width: w, child: _Tile(link: l)),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _Link {
  final IconData icon;
  final String labelKey;
  final Color color;

  /// The screen it opens, or null when [onTap] does something else
  /// (focus mode opens its own picker).
  final WidgetBuilder? page;
  final Future<void> Function(BuildContext)? onTap;
  const _Link(this.icon, this.labelKey, this.color, this.page, {this.onTap});
}

/// «التذكيرات» on a page of its own - the same section More shows.
class _RemindersPage extends StatelessWidget {
  const _RemindersPage();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('more.group_reminders'.tr())),
    body: const SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: SettingsBody(part: SettingsPart.reminders),
    ),
  );
}

class _Tile extends StatelessWidget {
  final _Link link;
  const _Tile({required this.link});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      onTap: () {
        final page = link.page;
        if (page != null) {
          Navigator.of(context).push(MaterialPageRoute<void>(builder: page));
        } else {
          link.onTap?.call(context);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Column(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: link.color.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(link.icon, color: link.color, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            link.labelKey.tr(),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(height: 1.25),
          ),
        ]),
      ),
    );
  }
}
