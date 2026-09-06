import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/models.dart';
import '../../../../core/db/sciences_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/azkar_repeat.dart';

/// One section's adhkar, one full-screen card at a time (P3‑54 redesign).
///
/// Each dhikr is its own page in a horizontal [PageView] — the user swipes
/// right/left (honouring the app's reading direction automatically, since a
/// horizontal `PageView` follows the ambient `Directionality`) to move between
/// adhkar. The card is a layered `Stack`: an Islamic gradient ground with the
/// app's own ornamental mark as a faint watermark, a dark overlay for
/// legibility, and the white [AmiriQuran] dhikr text on top. A large,
/// tappable **countdown** shows the repeats left for the current dhikr; when
/// it reaches zero the reader auto-advances to the next card. A page indicator
/// at the bottom shows which card of the section is showing.
///
/// The counter still works exactly as before (P3‑11): each dhikr's real repeat
/// count is parsed from its own text (`azkar_repeat.dart`), counted on the
/// very first tap, per-card counts are remembered when swiping back and forth,
/// and a trailing "section done" card closes the flow.
///
/// The background is deliberately a themed gradient + first-party watermark
/// rather than a stock photo: the app ships no real Islamic background image,
/// and the project's zero-placeholder rule forbids inventing/bundling an
/// unverified one. Swapping in a real image later is a single `Image.asset`
/// change in [_CardBackground].
class AzkarSectionScreen extends ConsumerStatefulWidget {
  final AzkarSection section;

  /// Accent colour for the countdown ring and the active page dot — passed by
  /// the hub so a card opened from, say, the "أذكار المساء" group carries that
  /// group's colour through. Falls back to the app gold when not supplied.
  final Color? accent;

  const AzkarSectionScreen({super.key, required this.section, this.accent});

  @override
  ConsumerState<AzkarSectionScreen> createState() => _AzkarSectionScreenState();
}

class _AzkarSectionScreenState extends ConsumerState<AzkarSectionScreen> {
  final PageController _pageController = PageController();
  List<AzkarItem>? _items;
  int _index = 0;

  /// Per-card tap count, keyed by card index so swiping back and forth keeps
  /// each dhikr's own progress rather than resetting it.
  final Map<int, int> _counts = {};

  @override
  void initState() {
    super.initState();
    ref.read(sciencesRepositoryProvider.future).then((repo) async {
      final items = await repo.azkarItems(widget.section.id);
      if (mounted) setState(() => _items = items);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Color get _accent => widget.accent ?? AppColors.gold;

  int _targetFor(int i) =>
      _items == null ? 1 : parseAzkarRepeatCount(_items![i].body);

  void _tapCount() {
    final items = _items;
    if (items == null || _index >= items.length) return;
    final target = _targetFor(_index);
    final current = _counts[_index] ?? 0;
    if (current >= target) return; // already complete — swipe to advance
    setState(() => _counts[_index] = current + 1);
    // Auto-advance once this dhikr's real repeat count is reached.
    if ((_counts[_index] ?? 0) >= target) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        if (_index < items.length) {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.section.title),
        elevation: 0,
      ),
      body: items == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                const Positioned.fill(child: _CardBackground()),
                Column(
                  children: [
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: items.length + 1, // +1 → "section done"
                        onPageChanged: (i) => setState(() => _index = i),
                        itemBuilder: (context, i) {
                          if (i == items.length) {
                            return _DonePage(
                              onBack: () => Navigator.of(context).pop(),
                            );
                          }
                          return _DhikrPage(
                            item: items[i],
                            isFirst: i == 0,
                          );
                        },
                      ),
                    ),
                    // Bottom controls belong to the *current* dhikr, so they
                    // live outside the PageView and read `_index` — hidden on
                    // the trailing "done" card, which has its own layout.
                    if (_index < items.length)
                      _BottomControls(
                        accent: _accent,
                        count: _counts[_index] ?? 0,
                        target: _targetFor(_index),
                        index: _index,
                        total: items.length,
                        onTap: _tapCount,
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

/// The layered Islamic ground shared by every card: a deep gradient, the app's
/// own ornamental mark as a low-opacity centred watermark, and a dark scrim so
/// the white dhikr text always stays readable.
class _CardBackground extends StatelessWidget {
  const _CardBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0B3D2E), // deep emerald
            Color(0xFF0E5A43),
            Color(0xFF0A1F19), // near-black green
          ],
        ),
      ),
      child: Stack(
        children: [
          // First-party watermark — the app's own mark, faint and centred.
          Center(
            child: Opacity(
              opacity: 0.05,
              child: Image.asset(
                'assets/branding/app_mark.png',
                width: 320,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
          // Extra scrim toward the bottom for the controls' legibility.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0x66000000)],
              ),
            ),
            child: SizedBox.expand(),
          ),
        ],
      ),
    );
  }
}

/// One dhikr's full-screen card — just the scrollable text + source, drawn
/// transparently over the shared [_CardBackground].
class _DhikrPage extends StatelessWidget {
  final AzkarItem item;
  final bool isFirst;
  const _DhikrPage({required this.item, required this.isFirst});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              item.body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'AmiriQuran',
                fontSize: 24,
                height: 2.0,
                color: Colors.white,
              ),
            ),
            if (item.footnote.isNotEmpty) ...[
              const SizedBox(height: 20),
              Divider(color: Colors.white.withValues(alpha: 0.25)),
              const SizedBox(height: 8),
              Text(
                '${'azkar.source'.tr()}: ${item.footnote}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
            ],
            if (isFirst) ...[
              const SizedBox(height: 20),
              Text(
                'azkar.swipe_hint'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The fixed bottom bar: a tappable countdown for the current dhikr's repeats
/// plus the section's page indicator.
class _BottomControls extends StatelessWidget {
  final Color accent;
  final int count;
  final int target;
  final int index;
  final int total;
  final VoidCallback onTap;

  const _BottomControls({
    required this.accent,
    required this.count,
    required this.target,
    required this.index,
    required this.total,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = (target - count).clamp(0, target);
    final done = remaining == 0;
    final progress = target == 0 ? 0.0 : (count / target).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tappable countdown ring — shows repeats *remaining* (counts down),
          // with a check once complete. Tapping anywhere on it counts.
          GestureDetector(
            onTap: onTap,
            child: SizedBox(
              width: 108,
              height: 108,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 108,
                    height: 108,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    ),
                  ),
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: done ? 0.9 : 0.18),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.8),
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: done
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 40)
                        : Text(
                            '$remaining',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            target > 1
                ? '${'azkar.repeat'.tr()}: $count / $target'
                : 'azkar.tap_to_count'.tr(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          _PageIndicator(index: index, total: total, accent: accent),
        ],
      ),
    );
  }
}

/// Page indicator: elongated-active dots when the section is short enough to
/// show them all, a compact "n / total" pill otherwise. Always paired with the
/// exact count so the position is unambiguous either way.
class _PageIndicator extends StatelessWidget {
  final int index;
  final int total;
  final Color accent;
  const _PageIndicator({
    required this.index,
    required this.total,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final label = Text(
      '${index + 1} / $total',
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.7),
        fontSize: 12,
      ),
    );

    if (total > 21) {
      // Too many to show as dots without crowding — the numeric pill alone.
      return label;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < total; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: i == index ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == index
                      ? accent
                      : Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        label,
      ],
    );
  }
}

/// The trailing card, reached by swiping past the last dhikr — the same
/// "أتممت أذكار هذا القسم" completion the reader has always shown, redrawn to
/// sit over the shared dark ground.
class _DonePage extends StatelessWidget {
  final VoidCallback onBack;
  const _DonePage({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 84, color: AppColors.success),
            const SizedBox(height: 16),
            Text(
              'azkar.section_done'.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onBack,
              child: Text('azkar.back_to_sections'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
