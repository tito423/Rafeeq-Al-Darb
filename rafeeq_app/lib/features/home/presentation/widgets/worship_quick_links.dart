import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../dedications/presentation/dedications_screen.dart';
import '../../../hajj/presentation/hajj_screen.dart';
import '../../../hifz/presentation/hifz_screen.dart';
import '../../../kids/presentation/journey_screen.dart';
import '../../../kids/presentation/kids_corner_screen.dart';
import '../../../quiz/presentation/quiz_home_screen.dart';
import '../../../quran_audio/presentation/quran_audio_screen.dart';
import '../../../ruqyah/presentation/screens/ruqyah_audio_screen.dart';
import '../../../tajweed/presentation/screens/tajweed_levels_screen.dart';

/// «كارت كبير في وصلات سريعة للحاجة اللي في كارت القرآن والعبادات من
/// المزيد» (owner, 2026-10-01). The same destinations as the «القرآن
/// والعبادات» group in More, in the same order, one tap from Home instead of
/// three. Icons and accents match the More cards so a tile looks like the
/// card it leads to.
class WorshipQuickLinks extends StatelessWidget {
  const WorshipQuickLinks({super.key});

  static final _links = <_Link>[
    _Link(Icons.library_music_outlined, 'home.ql_player', AppColors.gold, (_) => const QuranAudioScreen()),
    _Link(Icons.record_voice_over_outlined, 'home.ql_tajweed', AppColors.gold, (_) => const TajweedLevelsScreen()),
    _Link(Icons.school_outlined, 'home.ql_hifz', AppColors.gold, (_) => const HifzScreen()),
    _Link(Icons.mosque_outlined, 'home.ql_hajj', AppColors.gold, (_) => const HajjScreen()),
    _Link(Icons.healing_outlined, 'home.ql_ruqyah', AppColors.goldSoft, (_) => const RuqyahAudioScreen()),
    _Link(Icons.child_care_rounded, 'home.ql_kids', const Color(0xFFF79F1F), (_) => const KidsCornerScreen()),
    _Link(Icons.emoji_events_rounded, 'home.ql_journey', const Color(0xFF8854D0), (_) => const JourneyScreen()),
    _Link(Icons.quiz_rounded, 'home.ql_quiz', const Color(0xFF4834D4), (_) => const QuizHomeScreen()),
    _Link(Icons.volunteer_activism, 'home.ql_dedications', AppColors.primarySoft, (_) => const DedicationsScreen()),
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
                Text('more.group_worship'.tr(), style: theme.textTheme.titleMedium),
              ]),
            ),
            LayoutBuilder(builder: (context, box) {
              // five a row on a phone held upright (two rows), all nine in
              // one row once there is room for it - a tablet, sideways, a TV
              final cols = box.maxWidth >= 640 ? 9 : 5;
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
  final WidgetBuilder page;
  const _Link(this.icon, this.labelKey, this.color, this.page);
}

class _Tile extends StatelessWidget {
  final _Link link;
  const _Tile({required this.link});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: link.page)),
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
