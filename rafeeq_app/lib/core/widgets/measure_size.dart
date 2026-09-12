/// Reports the size its child actually laid out at.
///
/// WHY THIS EXISTS, AND IT IS NOT A NICETY.
/// `AppBar.bottom` takes a `PreferredSize`, which demands a height BEFORE the
/// child is laid out. The Qur'an toolbar's was the constant `116` — two rows
/// of `ToolbarAction.captionedHeight` (55) plus padding. On the owner's phone
/// those twelve captioned actions wrap into **four** rows, so the last two sat
/// outside the app bar's box.
///
/// Flutter paints what overflows a box but **hit-tests only inside it**. So
/// «وضع المصحف», the last action in the list, was fully visible and completely
/// untappable — and the taps fell through to the page underneath, which
/// toggles full screen, which is why it looked like «ساعة يشتغل وساعة لأ»
/// rather than like a dead button. He filmed fourteen taps doing nothing.
///
/// A constant cannot be right here: the number of rows depends on the screen
/// width, the language (Arabic captions are not English captions), and the
/// reader's font-scale setting. So the toolbar is measured and the app bar is
/// told, one frame later.
library;

import 'package:flutter/material.dart';

class MeasureSize extends StatefulWidget {
  final Widget child;

  /// Called after layout, and again whenever the size changes.
  final ValueChanged<Size> onChange;

  const MeasureSize({super.key, required this.onChange, required this.child});

  @override
  State<MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<MeasureSize> {
  final _key = GlobalKey();
  Size? _last;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
  }

  @override
  void didUpdateWidget(MeasureSize oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
  }

  /// Always off the frame: reporting a size DURING layout would be a setState
  /// inside build for whoever is listening.
  void _report() {
    if (!mounted) return;
    final box = _key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    if (box.size == _last) return;
    _last = box.size;
    widget.onChange(box.size);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
    return KeyedSubtree(key: _key, child: widget.child);
  }
}
