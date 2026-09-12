/// The three cards «وضع التركيز» offers before it locks the app down.
///
/// «لما نضغط عليه يديني كارت للقرآن فيفتح القرآن ويقفل عليه، وكارت لوضع
/// للأذكار ويقفل عليه، وكارت للمسبحة ويقفل عليها، بس هما دول».
///
/// A sheet rather than a screen: choosing is one tap and the thing you chose
/// is what you get, with nothing in between.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/focus_mode_provider.dart';

/// Icon and accent per destination, kept beside the sheet that draws them
/// rather than on the enum: they are how this one picker looks, not facts
/// about focus mode.
const _look = <FocusTarget, (IconData, Color)>{
  FocusTarget.quran: (Icons.menu_book_rounded, AppColors.gold),
  FocusTarget.azkar: (Icons.spa_rounded, Color(0xFF2E9D6F)),
  FocusTarget.tasbeeh: (Icons.radio_button_checked, Color(0xFFD4785A)),
};

Future<void> showFocusModePicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _FocusModeSheet(),
  );
}

class _FocusModeSheet extends ConsumerWidget {
  const _FocusModeSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'focus.pick_title'.tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'focus.pick_body'.tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            for (final target in FocusTarget.values) ...[
              _FocusTargetCard(target: target),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _FocusTargetCard extends ConsumerWidget {
  final FocusTarget target;

  const _FocusTargetCard({required this.target});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final (icon, accent) = _look[target]!;
    return Material(
      color: accent.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          ref.read(focusModeProvider.notifier).enter(target);
          Navigator.of(context).pop();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      target.titleKey.tr(),
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      target.bodyKey.tr(),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              // chevron_right, not chevron_left: this one must NOT mirror in
              // RTL (trap #7).
              Icon(Icons.chevron_right, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}
