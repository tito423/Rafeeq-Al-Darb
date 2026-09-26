import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/accordion.dart';
import '../../../../core/widgets/islamic_action_card.dart';
import '../../../tutorial/data/tutorial_state.dart';
import '../../../../core/utils/screen_class.dart';

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
/// The accent a [MoreGroup] hands down to the cards inside it.
///
/// «الكارت الذي تحته كروت يأخذ لونًا مميزًا، والكروت التي تحته تأخذ لونه
/// وتكون أقصر عرضًا، وبشكل كروت المصادر والمراجع». Each nested card used to
/// carry its own accent, so an opened group was a row of unrelated colours
/// under one heading. Rather than edit twenty call sites — and rather than
/// take the accent away from a card that is used outside a group too — the
/// group publishes its colour here and [IslamicActionCard] prefers it when
/// there is one.
class MoreGroupAccent extends InheritedWidget {
  final Color accent;

  const MoreGroupAccent({
    super.key,
    required this.accent,
    required super.child,
  });

  static Color? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<MoreGroupAccent>()
      ?.accent;

  @override
  bool updateShouldNotify(MoreGroupAccent old) => old.accent != accent;
}

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

class _MoreGroupState extends ConsumerState<MoreGroup>
    with AccordionMember<MoreGroup> {
  bool _open = false;

  @override
  bool get accordionIsOpen => _open;

  @override
  void accordionCollapse() => setState(() => _open = false);

  void _toggle() {
    setState(() => _open = !_open);
    if (_open) {
      // «قائمة واحدة مفتوحة فقط - فتح قائمة يغلق المفتوحة وتظهر الجديدة
      // بملء الشاشة» (owner, 2026-09-25). The group that closes above this
      // one shrinks for 240 ms and drags this one up while it does; the old
      // reveal chased it and the list jumped. Once both have settled, this
      // group's own header is brought to the top of the screen, once.
      accordionOpened(reveal: false);
      Future<void>.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        Scrollable.ensureVisible(
          context,
          alignment: 0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      });
    } else {
      accordionClosed();
    }
  }

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
          // Three a row, the descriptions made the cards every height from
          // two lines to six, out of line with each other (owner's photo,
          // 2026-09-26: «شيل الكلام ... يبقوا متناسقين مش واحد كبير والتاني
          // صغير»). In a grid the title says it; the list upright keeps
          // the description, where it has the width to be read.
          subtitle: ScreenClass.twoColumns(context) ? '' : widget.subtitle,
          singleLineTitle: ScreenClass.twoColumns(context),
          onTap: _toggle,
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
                  // Inset on BOTH sides, so an opened group reads as a
                  // narrower column stepped in under its own card rather
                  // than as more cards of the same width.
                  padding: const EdgeInsetsDirectional.only(
                      start: 26, end: 12, bottom: 8),
                  child: MoreGroupAccent(
                    accent: widget.accent,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: widget.children,
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
