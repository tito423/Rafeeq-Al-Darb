/// Choosing where to memorize — on the session screen itself.
///
/// «لازم الاية تتحرك معايا بالتنقل بالاصبع وادّيني في نفس الشاشة قايمة
/// منسدلة بالاية وسلايدر لاي ايه وبوكس ادخل فيه رقم الاية … وقايمة منسدلة
/// باسماء السور … كل ده في نفس الشاشة» (2026-09-23, «ده مهم جدا»).
///
/// The jump used to sit behind an icon in the app bar that opened a sheet;
/// the owner never found it («لسه مش قادر اغير الاية»). Everything is here
/// now, above the ayah: a searchable surah list, the ayah list, a slider
/// across the surah, and a box for a number. [SwipeableAyah] makes the ayah
/// card follow the finger between ayahs.
library;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import '../../../../core/db/models.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/arabic_normalize.dart' show surahNamePlain;
import '../../../../core/utils/digits.dart';

class HifzNavigator extends StatefulWidget {
  final List<Surah> surahs;
  final int surah;
  final int ayah;
  final void Function(int surah, int ayah) onGo;

  const HifzNavigator({
    super.key,
    required this.surahs,
    required this.surah,
    required this.ayah,
    required this.onGo,
  });

  @override
  State<HifzNavigator> createState() => _HifzNavigatorState();
}

class _HifzNavigatorState extends State<HifzNavigator> {
  final _number = TextEditingController();

  /// The slider's own position while it is being dragged, so the label
  /// follows the thumb and the session moves only when it is let go.
  double? _dragging;

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  int get _count =>
      widget.surahs.firstWhere((s) => s.id == widget.surah).ayahsCount;

  String _n(int v) => localizeDigits('$v', uiLanguageCode);

  void _goNumber() {
    final v = int.tryParse(asciiDigits(_number.text.trim()));
    if (v == null || v < 1 || v > _count) {
      _number.clear();
      return;
    }
    FocusScope.of(context).unfocus();
    _number.clear();
    widget.onGo(widget.surah, v);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final count = _count;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The surah — typing filters the list, so «البقرة» is three
          // letters away rather than a long scroll.
          LayoutBuilder(
            builder: (context, c) => DropdownMenu<int>(
              key: ValueKey('surah-${widget.surah}'),
              width: c.maxWidth,
              initialSelection: widget.surah,
              label: Text('hifz.plan_surah'.tr()),
              enableFilter: true,
              requestFocusOnTap: true,
              menuHeight: 360,
              leadingIcon: const Icon(
                Icons.menu_book_rounded,
                color: AppColors.gold,
                size: 20,
              ),
              dropdownMenuEntries: [
                for (final s in widget.surahs)
                  DropdownMenuEntry(
                    value: s.id,
                    label: '${_n(s.id)}. ${surahNamePlain(s.nameAr)}',
                  ),
              ],
              onSelected: (id) {
                if (id != null && id != widget.surah) widget.onGo(id, 1);
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // The ayah, from a list.
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) => DropdownMenu<int>(
                    key: ValueKey('ayah-${widget.surah}-${widget.ayah}'),
                    width: c.maxWidth,
                    initialSelection: widget.ayah,
                    label: Text('hifz.plan_ayah'.tr()),
                    menuHeight: 320,
                    dropdownMenuEntries: [
                      for (var i = 1; i <= count; i++)
                        DropdownMenuEntry(value: i, label: _n(i)),
                    ],
                    onSelected: (v) {
                      if (v != null && v != widget.ayah) {
                        widget.onGo(widget.surah, v);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // …or typed.
              // Wide enough for «رقم الآية» in full: at 110 it read «رقم …».
              SizedBox(
                width: 150,
                child: TextField(
                  controller: _number,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => _goNumber(),
                  decoration: InputDecoration(
                    labelText: 'hifz.nav_number'.tr(),
                    isDense: true,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: 'hifz.nav_go'.tr(),
                      icon: const Icon(Icons.arrow_circle_left_rounded),
                      onPressed: _goNumber,
                    ),
                  ),
                ),
              ),
            ],
          ),
          // …or slid to. A one-ayah surah has nothing to slide across.
          if (count > 1)
            Slider(
              value: (_dragging ?? widget.ayah.toDouble()).clamp(
                1,
                count.toDouble(),
              ),
              min: 1,
              max: count.toDouble(),
              divisions: count - 1,
              label: _n((_dragging ?? widget.ayah.toDouble()).round()),
              activeColor: AppColors.gold,
              onChanged: (v) => setState(() => _dragging = v),
              onChangeEnd: (v) {
                setState(() => _dragging = null);
                final a = v.round();
                if (a != widget.ayah) widget.onGo(widget.surah, a);
              },
            ),
        ],
      ),
    );
  }
}

/// The ayah card, following the finger sideways.
///
/// The card moves with the drag; let go past a third of its width (or with
/// a flick) and it slides out and the neighbouring ayah slides in — the
/// «تتحرك معايا بالتنقل بالاصبع» the owner asked for. Right-to-left, as a
/// mushaf turns: dragging towards the right brings the NEXT ayah.
class SwipeableAyah extends StatefulWidget {
  final Widget child;
  final VoidCallback? onNext;
  final VoidCallback? onPrev;

  const SwipeableAyah({
    super.key,
    required this.child,
    this.onNext,
    this.onPrev,
  });

  @override
  State<SwipeableAyah> createState() => _SwipeableAyahState();
}

class _SwipeableAyahState extends State<SwipeableAyah>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  double _dx = 0;
  double _from = 0;
  double _to = 0;

  @override
  void initState() {
    super.initState();
    _c.addListener(
      () => setState(
        () => _dx = _from + (_to - _from) * Curves.easeOut.transform(_c.value),
      ),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _animate(double to) async {
    _from = _dx;
    _to = to;
    await _c.forward(from: 0);
  }

  Future<void> _end(DragEndDetails d, double width) async {
    final v = d.primaryVelocity ?? 0;
    final forward = _dx > width / 3 || v > 700;
    final back = _dx < -width / 3 || v < -700;
    if (forward && widget.onNext != null) {
      await _animate(width);
      widget.onNext!();
      _dx = -width; // the new ayah comes in from the other side
      await _animate(0);
    } else if (back && widget.onPrev != null) {
      await _animate(-width);
      widget.onPrev!();
      _dx = width;
      await _animate(0);
    } else {
      await _animate(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (d) {
          if (_c.isAnimating) return;
          setState(() => _dx += d.delta.dx);
        },
        onHorizontalDragEnd: (d) => _end(d, c.maxWidth),
        child: Transform.translate(
          offset: Offset(_dx, 0),
          child: Opacity(
            opacity: (1 - (_dx.abs() / (c.maxWidth * 1.4))).clamp(0.3, 1.0),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
