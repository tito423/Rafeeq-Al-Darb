import 'dart:ui' as ui;

import 'dart:math' as math;
import '../../../core/utils/arabic_normalize.dart';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/arabic_text.dart';
import '../../hadeethenc/data/hadeethenc_providers.dart';
import '../../hadeethenc/presentation/screens/hadeethenc_detail_screen.dart';
import '../data/daily_hadith_provider.dart';

/// Home, bottom card (P2‑13) — one full hadith (complete text, narrator,
/// book/number, grade line), re-rolled every app launch, with a manual
/// "حديث آخر" re-roll and a tap-through to the full detail screen. Sits
/// just above the bottom nav bar per the Home redesign's own ordering.
///
/// P3‑4: wrapped in an ornamental frame (gold corner flourishes, a gold
/// hairline border, small stars flanking the title) — the owner sent a
/// real reference (`design_refs/round2_2026-09-04/ref_hadith_card.jpg`) of
/// the old app's own "حديث شريف" card. Followed its *structure* (corner
/// ornament, gold border, star accents), not its literal near-black-green
/// palette — this uses the app's own navy/gold theme instead, same
/// adaptation rule already applied to P3‑29's Shamela reference.
class DailyHadithCard extends StatelessWidget {
  const DailyHadithCard({super.key});

  @override
  Widget build(BuildContext context) =>
      const _OrnateFrame(child: _PickedHadith());
}

/// The ornamental frame itself — a gold hairline border, a subtle navy→gold
/// gradient fill (this app's own night palette, not the reference's
/// near-black-green), and a gold quarter-circle flourish mirrored into all
/// four corners.
class _OrnateFrame extends StatelessWidget {
  final Widget child;
  const _OrnateFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.55)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [AppColors.nightElevated, AppColors.night]
              : [AppColors.lightScaffold, Colors.white],
        ),
      ),
      child: Stack(
        children: [
          const Positioned(top: 6, left: 6, child: _CornerFlourish()),
          Positioned(
            top: 6,
            right: 6,
            child: Transform.flip(flipX: true, child: const _CornerFlourish()),
          ),
          Positioned(
            bottom: 6,
            left: 6,
            child: Transform.flip(flipY: true, child: const _CornerFlourish()),
          ),
          Positioned(
            bottom: 6,
            right: 6,
            child: Transform.flip(
              flipX: true,
              flipY: true,
              child: const _CornerFlourish(),
            ),
          ),
          Padding(padding: const EdgeInsets.all(18), child: child),
        ],
      ),
    );
  }
}

class _CornerFlourish extends StatelessWidget {
  const _CornerFlourish();
  @override
  Widget build(BuildContext context) => CustomPaint(
        size: const Size(26, 26),
        painter: _FlourishPainter(),
      );
}

/// Two nested quarter-circle arcs, echoing the reference card's own corner
/// ornament without trying to pixel-match its specific artwork.
class _FlourishPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = AppColors.gold.withValues(alpha: 0.65);
    canvas.drawArc(
      Rect.fromLTWH(-size.width * 0.35, -size.height * 0.35,
          size.width * 1.35, size.height * 1.35),
      0,
      math.pi / 2,
      false,
      paint,
    );
    canvas.drawArc(
      Rect.fromLTWH(size.width * 0.05, size.height * 0.05,
          size.width * 0.7, size.height * 0.7),
      0,
      math.pi / 2,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _FlourishPainter old) => false;
}

/// A small gold star, used to flank the title text the same way the
/// reference's "★ حديث شريف ★" banner does.
class _TitleStar extends StatelessWidget {
  const _TitleStar();
  @override
  Widget build(BuildContext context) =>
      Icon(Icons.star, size: 12, color: AppColors.gold.withValues(alpha: 0.8));
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 60,
        child: Center(child: CircularProgressIndicator()),
      );
}

class _ErrorState extends StatelessWidget {
  final ThemeData theme;
  const _ErrorState({required this.theme});
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(child: Text('errors.generic'.tr())),
        ],
      );
}

class _PickedHadith extends ConsumerStatefulWidget {
  const _PickedHadith();

  @override
  ConsumerState<_PickedHadith> createState() => _PickedHadithState();
}

class _PickedHadithState extends ConsumerState<_PickedHadith> {
  /// Opens the Encyclopaedia's own screen — word meanings, hints, the full
  /// explanation and the source link.
  Future<void> _openDetail(DailyHadith daily) async {
    final catalog = ref.read(hadeethEncCatalogProvider).valueOrNull;
    final pack = ref.read(hadeethEncPackProvider).valueOrNull;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HadeethEncDetailScreen(
          item: daily.encyclopaedia,
          sourceName: catalog?.nameFor(pack?.lang ?? 'ar') ?? '',
          sourceUrl: catalog?.sourceUrl ?? '',
          rtl: pack?.isRtl ?? true,
        ),
      ),
    );
  }

  // P3‑36: local, layout-invisible "in flight" flag for the reroll button's
  // own spinner — deliberately NOT derived from the provider's AsyncValue
  // (see the doc on `DailyHadithNotifier.reroll`), so a reroll can never
  // collapse the card itself, only swap this one small icon.
  bool _rerolling = false;

  Future<void> _reroll() async {
    setState(() => _rerolling = true);
    await ref.read(dailyHadithProvider.notifier).reroll();
    if (mounted) setState(() => _rerolling = false);
  }

  /// Forward by swipe. Same path as the button, minus its spinner: a swipe
  /// that already moved the card should not then flash a loading state on it.
  Future<void> _swipeNext() async {
    await ref.read(dailyHadithProvider.notifier).next();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(dailyHadithProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return async.when(
      loading: () => const _Loading(),
      error: (_, _) => _ErrorState(theme: theme),
      data: (daily) {
        if (daily == null) {
          // The bundled pack would not open — a real failure, shown as one.
          return Text('errors.generic'.tr());
        }

        return GestureDetector(
          // Swipe to move between hadiths, which is what the owner asked for.
          // The direction follows the text: in Arabic (RTL) a swipe to the
          // RIGHT goes forward, the way a page turns in an Arabic book, and
          // in the six LTR locales it is the other way round. Hard-coding one
          // of the two would feel backwards in the other.
          onHorizontalDragEnd: (details) {
            final v = details.primaryVelocity ?? 0;
            if (v.abs() < 120) return;
            // `TextDirection` is ambiguous here: easy_localization re-exports
            // intl's, which is a different type from dart:ui's.
            final rtl = Directionality.of(context) == ui.TextDirection.rtl;
            final forward = rtl ? v > 0 : v < 0;
            if (forward) {
              _swipeNext();
            } else {
              ref.read(dailyHadithProvider.notifier).previous();
            }
          },
          child: InkWell(
          onTap: () => _openDetail(daily),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.menu_book_outlined, color: scheme.primary, size: 20),
                  const SizedBox(width: 8),
                  const _TitleStar(),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'hadith_daily.title'.tr(),
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const _TitleStar(),
                  // P3‑41: a real device screenshot showed this row
                  // overflowing by 16px on a narrower/scaled-font phone —
                  // the plain `IconButton`'s default 48×48 tap target was
                  // the fixed-width cost this Row couldn't always afford
                  // alongside two star glyphs + the book icon. Shrinking
                  // its own footprint (not the touch target's visual
                  // affordance, just the padding around it) removes that
                  // margin without changing what it does.
                  // A swipe with no visible affordance is a feature nobody
                  // finds. These two say the card moves, and the back one
                  // greys out at the start of the history so it is honest
                  // about when there is nothing to go back to.
                  IconButton(
                    tooltip: 'hadith_daily.previous'.tr(),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 30, minHeight: 30),
                    // `chevron_right` for "back" is not a typo: Flutter
                    // auto-mirrors `chevron_left` in RTL (trap #7), and this
                    // arrow has to point at the previous card in both
                    // directions.
                    icon: const Icon(Icons.chevron_left, size: 22),
                    onPressed:
                        ref.read(dailyHadithProvider.notifier).hasPrevious
                            ? () => ref
                                .read(dailyHadithProvider.notifier)
                                .previous()
                            : null,
                  ),
                  IconButton(
                    tooltip: 'hadith_daily.another'.tr(),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    icon: const Icon(Icons.chevron_right, size: 22),
                    onPressed: _swipeNext,
                  ),
                  IconButton(
                    tooltip: 'hadith_daily.another'.tr(),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    icon: _rerolling
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 20),
                    onPressed: _rerolling ? null : _reroll,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // ArabicText, not Text: this card sits under the app's own
              // Directionality, which is LTR in six of the seven locales. An
              // Arabic paragraph laid out in an LTR box puts its trailing
              // neutrals — the closing quote, the full stop — at the wrong
              // end of the last line. Bukhari 4543 was photographed on the
              // Portuguese build with its full stop flung to the right of
              // «كِبْرَهُ}» instead of ending the sentence after «سَلُولَ».
              // stripBidiControls removes the source's RLMs; only an RTL
              // paragraph puts what is left in the right place.
              ArabicText(
                stripBidiControls(daily.arabic),
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.justify,
                style: const TextStyle(
                  fontFamily: 'AmiriQuran',
                  fontSize: 17,
                  height: 1.9,
                ),
              ),
              const SizedBox(height: 10),
              // The Encyclopaedia's takhrij and grading, with its named source.
              ...[
                Text(
                  [
                    if (daily.encyclopaedia.attributionAr.isNotEmpty)
                      daily.encyclopaedia.attributionAr,
                    if (daily.encyclopaedia.gradeAr.isNotEmpty)
                      daily.encyclopaedia.gradeAr,
                  ].join(' · '),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                // «خلي كارت الحديث يعرض بس الأحاديث منها على أساس إنها
                // مشروحة». The explanation is the reason this corpus is
                // preferred, so it is on the card, not one tap away.
                Text(
                  'hadeethenc.explanation'.tr(),
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: scheme.primary),
                ),
                const SizedBox(height: 4),
                ArabicText(
                  stripBidiControls(daily.explanation),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.start,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.7),
                ),
              ],
            ],
          ),
          ),
        );
      },
    );
  }
}
