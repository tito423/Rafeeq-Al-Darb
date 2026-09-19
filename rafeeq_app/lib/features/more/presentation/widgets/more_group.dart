import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/islamic_action_card.dart';
import '../../../tutorial/data/tutorial_state.dart';

/// One group of «المزيد» as a single card that opens onto its contents.
///
/// «خلّي كل قسم كولابسد في المزيد يبقى له كروت بنفس شكل القرآن والعبادات …
/// وخلّي كل شيء كولابسد حتى شرح التطبيق» (2026-09-19). The header is an
/// [IslamicActionCard] - the same card the worship entries use - whose
/// subtitle names what is inside, so a closed group still says what it holds.
///
/// Every group starts closed, and every group is open while the guided tour
/// runs: the tour frames cards inside these groups, and a card in a closed
/// group has no size to frame.
class MoreGroup extends ConsumerStatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final List<Widget> children;

  const MoreGroup({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
    this.accent = AppColors.gold,
  });

  @override
  ConsumerState<MoreGroup> createState() => _MoreGroupState();
}

class _MoreGroupState extends ConsumerState<MoreGroup> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final open = _open || ref.watch(tutorialRunningProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IslamicActionCard(
          icon: widget.icon,
          accent: widget.accent,
          title: widget.title,
          subtitle: widget.subtitle,
          onTap: () => setState(() => _open = !_open),
          trailing: AnimatedRotation(
            turns: open ? 0.25 : 0,
            duration: const Duration(milliseconds: 200),
            // chevron_right: the left one mirrors in RTL (trap #7).
            child: Icon(
              Icons.chevron_right,
              color: widget.accent.withValues(alpha: 0.85),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: open
              ? Padding(
                  padding: const EdgeInsetsDirectional.only(
                      start: 14, bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: widget.children,
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
