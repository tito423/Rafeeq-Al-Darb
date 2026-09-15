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
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  Makhraj? _selected;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _pick(Makhraj m) => setState(() => _selected = m);

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
          Card(
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
                pulse: _pulse,
              ),
            ),
          ),
          const SizedBox(height: 14),
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
          for (final info in makhrajRegions) _RegionBlock(
            info: info,
            selected: selected,
            onPick: _pick,
          ),
          const SizedBox(height: 16),
          Text(
            '${'makharij.source'.tr()}: $makharijSourceLabel',
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

/// One general region and the specific makharij inside it.
class _RegionBlock extends StatelessWidget {
  final MakhrajRegionInfo info;
  final Makhraj? selected;
  final ValueChanged<Makhraj> onPick;

  const _RegionBlock({
    required this.info,
    required this.selected,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final inside = makharij.where((m) => m.region == info.region).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
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
            ],
          ),
          const SizedBox(height: 6),
          Text(
            info.definition,
            style: TextStyle(
              fontSize: 13,
              height: 1.8,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in inside)
                _LetterChip(
                  makhraj: m,
                  on: selected?.id == m.id,
                  onTap: () => onPick(m),
                ),
            ],
          ),
        ],
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
            'ص${makhraj.page}',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
