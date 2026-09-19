part of 'tasbeeh_screen.dart';

// The long-dhikr («المأثور») cards, split out of tasbeeh_screen.dart to
// keep it under the 800-line ceiling; `part` keeps them private to it.

/// The card that opens the picker. Deliberately quiet when nothing is
/// selected and gold-edged once one of the five is being counted, so the
/// screen always says which list the number on it belongs to.
class _MathurEntryCard extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _MathurEntryCard({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: active
              ? AppColors.gold.withValues(alpha: 0.10)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active
                ? AppColors.gold.withValues(alpha: 0.6)
                : scheme.outlineVariant.withValues(alpha: 0.4),
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.auto_stories_outlined,
                color: active ? AppColors.gold : scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'azkar.tasbeeh_mathur_title'.tr(),
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'azkar.tasbeeh_mathur_desc'.tr(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            // Trap #7: `chevron_left` auto-mirrors in RTL and `chevron_right`
            // does not — a disclosure chevron has to point the same way in
            // both directions.
            Icon(Icons.chevron_right,
                color: active ? AppColors.gold : scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// The picker: the five, each in full, each tappable.
class _MathurPickerSheet extends StatelessWidget {
  final int? selected;
  const _MathurPickerSheet({required this.selected});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'azkar.tasbeeh_mathur_pick'.tr(),
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: tasbeehLongAdhkar.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final option = tasbeehLongAdhkar[i];
                  final isSelected = selected == i;
                  return InkWell(
                    onTap: () => Navigator.of(context).pop(i),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Color.alphaBlend(
                          option.color.withValues(alpha: 0.12),
                          scheme.surfaceContainerHighest
                              .withValues(alpha: 0.45),
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: option.color
                              .withValues(alpha: isSelected ? 0.9 : 0.35),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Text(
                        option.textKey.tr(),
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontFamily: 'AmiriQuran',
                          fontSize: 17,
                          height: 1.9,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The selected long dhikr, counting. Same gesture as the circle — a tap
/// anywhere on it is one count — with the Azkar screen's own counter shape
/// underneath it: the number, its target, and a gold bar filling toward it.
class _MathurCounterCard extends StatelessWidget {
  final DhikrOption option;
  final int count;
  final int? target;
  final VoidCallback onTap;

  const _MathurCounterCard({
    required this.option,
    required this.count,
    required this.target,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = target;
    // SIZED TO THE SCREEN, not to a number somebody typed. «لما بختار ذكر
    // طويل في المسبحة صغّر شكل الكارت لأنه لازم أحرّك الشاشة لتحت عشان أوصل
    // لآخره» - the longest of the five is 88 characters, and at a fixed 19pt
    // over a 2.0 line height plus a 44pt counter the card ran past the bottom
    // of a phone, so the count you are tapping for was off screen. Both type
    // sizes now come from the viewport, with floors so a small phone still
    // gets something readable rather than something tiny.
    final h = MediaQuery.sizeOf(context).height;
    final dhikrSize = (h * 0.0195).clamp(14.0, 19.0);
    final countSize = (h * 0.032).clamp(26.0, 44.0);
    return GestureDetector(
      onTap: onTap,
      child: IslamicPatternPanel(
        padding: EdgeInsets.fromLTRB(18, h * 0.012, 18, h * 0.010),
        colors: [
          Color.alphaBlend(
            option.color.withValues(alpha: 0.28),
            AppColors.primaryContainer,
          ),
          AppColors.nightSurface,
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              option.textKey.tr(),
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: 'AmiriQuran',
                fontSize: dhikrSize,
                height: 1.75,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            // Same rule as the circle above: the "how to say it" line is for
            // a reader who cannot read the script, so it is absent in Arabic.
            if (context.locale.languageCode != 'ar') ...[
              const SizedBox(height: 8),
              Text(
                '${option.textKey}_ph'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
            ],
            SizedBox(height: h * 0.010),
            Container(
              height: 1,
              width: 90,
              color: AppColors.gold.withValues(alpha: 0.45),
            ),
            SizedBox(height: h * 0.010),
            // The count springs on every tap, so the card visibly answers the
            // finger rather than silently swapping a digit.
            TweenAnimationBuilder<double>(
              key: ValueKey<int>(count),
              tween: Tween(begin: 0.82, end: 1.0),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Text(
                t == null ? '$count' : localizeDigits(ratio(count, t), uiLanguageCode),
                style: TextStyle(
                  fontSize: countSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            if (t != null) ...[
              SizedBox(height: h * 0.009),
              GoldProgressBar(value: (count / t).clamp(0.0, 1.0)),
            ],
            const SizedBox(height: 12),
            Text(
              'azkar.tap_to_count'.tr(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
