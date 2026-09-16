import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/makharij.dart';
import '../widgets/makharij_diagram.dart';

/// «مخارج الحروف» — the diagram, the seventeen points, and what the book says
/// about the one you touched.
///
/// The screen holds one controller and lends it to both halves, so the point
/// on the drawing and the card under it breathe together instead of drifting
/// apart the way two independent tickers do.
class MakharijScreen extends StatefulWidget {
  const MakharijScreen({super.key});

  @override
  State<MakharijScreen> createState() => _MakharijScreenState();
}

class _MakharijScreenState extends State<MakharijScreen>
    with TickerProviderStateMixin {
  /// The mouth taking up the position: it plays once per pick and holds.
  late final AnimationController _articulation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );

  /// The air, which keeps moving after the mouth has arrived.
  late final AnimationController _flow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  Makhraj? _selected;

  @override
  void dispose() {
    _articulation.dispose();
    _flow.dispose();
    super.dispose();
  }

  void _pick(Makhraj m) {
    setState(() => _selected = m);
    // From zero every time, so picking the same one again replays the
    // movement rather than doing nothing.
    _articulation.forward(from: 0);
  }

  MakhrajRegionInfo _infoFor(MakhrajRegion r) =>
      makhrajRegions.firstWhere((i) => i.region == r);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _selected;
    return Scaffold(
      appBar: AppBar(title: Text('makharij.title'.tr())),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Text(
            'makharij.subtitle'.tr(),
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 10),
          // «الحروف بعيدة عن الرسم يعني اضغط على الحرف تحت وفين وفين على ما
          // اطلع فوق واضغط على الحرف» — so the drawing is capped at two fifths
          // of the screen and the letters sit **directly under it**. Tapping a
          // letter has to move something you can already see, or the diagram
          // is just decoration you scroll past.
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.40,
            ),
            child: Card(
              elevation: 0,
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: MakharijDiagram(
                  selected: selected,
                  onPick: _pick,
                  articulation: CurvedAnimation(
                    parent: _articulation,
                    curve: Curves.easeOutCubic,
                  ),
                  flow: _flow,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Every letter, in the book's order, within a thumb of the drawing.
          _LetterStrip(selected: selected, onPick: _pick),
          const SizedBox(height: 12),
          // The detail card grows into place rather than appearing, so the
          // list does not jump under the finger that just picked a point.
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: selected == null
                ? const SizedBox(width: double.infinity)
                : _Detail(
                    makhraj: selected,
                    info: _infoFor(selected.region),
                    key: ValueKey(selected.id),
                  ),
          ),
          const SizedBox(height: 18),
          Text(
            'makharij.general'.tr(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          // The definitions, read out of the book. The letters themselves are
          // up beside the drawing now, so these rows are for reading, not for
          // reaching.
          for (final info in makhrajRegions) _RegionDefinition(info: info),
          const SizedBox(height: 16),
          Text(
            '${'makharij.source'.tr()}: $makharijSourceLabel',
            style: TextStyle(
              fontSize: 12,
              height: 1.7,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          // CC0 requires no attribution at all. It is here because crediting
          // the people whose drawing this is costs nothing and is right.
          Text(
            'makharij.drawing_credit'.tr(),
            style: TextStyle(
              fontSize: 12,
              height: 1.7,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// A region's name and what the book says it is. No chips: the letters live
/// beside the drawing.
class _RegionDefinition extends StatelessWidget {
  final MakhrajRegionInfo info;

  const _RegionDefinition({required this.info});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.gold,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                info.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'makharij.page'.tr(namedArgs: {'page': '${info.page}'}),
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            info.definition,
            style: TextStyle(
              fontSize: 13,
              height: 1.8,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// All seventeen, in the book's order, in one strip under the drawing.
///
/// Grouped by region with a thin gold rule between groups rather than a
/// heading each, because a heading per group is what pushed the letters a
/// screen away from the thing they move.
class _LetterStrip extends StatelessWidget {
  final Makhraj? selected;
  final ValueChanged<Makhraj> onPick;

  const _LetterStrip({required this.selected, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final children = <Widget>[];
    MakhrajRegion? last;
    for (final m in makharij) {
      if (last != null && m.region != last) {
        children.add(Container(
          width: 1.5,
          height: 26,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          color: AppColors.gold.withValues(alpha: 0.45),
        ));
      }
      last = m.region;
      children.add(_LetterChip(
        makhraj: m,
        on: selected?.id == m.id,
        onTap: () => onPick(m),
      ));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      ),
    );
  }
}

class _LetterChip extends StatelessWidget {
  final Makhraj makhraj;
  final bool on;
  final VoidCallback onTap;

  const _LetterChip({
    required this.makhraj,
    required this.on,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: on
              ? AppColors.gold.withValues(alpha: 0.22)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: on ? AppColors.gold : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Text(
          makhraj.letters.join(' '),
          style: const TextStyle(
            fontFamily: 'AmiriQuran',
            fontSize: 19,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

/// What the book says about the picked makhraj — its place, its letters, and
/// the page it was read from, so the claim can be checked.
class _Detail extends StatelessWidget {
  final Makhraj makhraj;
  final MakhrajRegionInfo info;

  const _Detail({required this.makhraj, required this.info, super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            info.name,
            style: const TextStyle(
              color: AppColors.gold,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            makhraj.place,
            style: const TextStyle(fontSize: 15, height: 1.9),
          ),
          const SizedBox(height: 12),
          Text(
            'makharij.letters'.tr(),
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Text(
            makhraj.letters.join('  '),
            style: const TextStyle(
              fontFamily: 'AmiriQuran',
              fontSize: 30,
              height: 1.6,
            ),
          ),
          if (makhraj.ayahExample != null) ...[
            const SizedBox(height: 8),
            Text(
              makhraj.ayahExample!,
              style: const TextStyle(
                fontFamily: 'AmiriQuran',
                fontSize: 18,
                height: 1.9,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'makharij.page'.tr(namedArgs: {'page': '${makhraj.page}'}),
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
