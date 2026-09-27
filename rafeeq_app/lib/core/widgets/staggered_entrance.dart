import 'dart:async';

import 'package:flutter/material.dart';

/// A list item that rises and fades in, a beat after the one above it
/// (owner, 2026-09-27: «انيميشنز تحسسك انك فعلا بتتعامل مع مكتبة مودرن»).
///
/// Only the first [maxAnimated] rows animate - the ones on screen when a
/// list opens; rows built later by scrolling appear at once, so a fast
/// scroll never waits on an animation. Honours the system's «remove
/// animations» setting.
class StaggeredEntrance extends StatefulWidget {
  const StaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
    this.maxAnimated = 8,
  });

  final int index;
  final Widget child;
  final int maxAnimated;

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _t =
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  Timer? _start;

  bool get _animates => widget.index < widget.maxAnimated;

  @override
  void initState() {
    super.initState();
    if (!_animates) {
      _c.value = 1;
      return;
    }
    // A Timer, not Future.delayed: cancelled with the row, so a row that
    // scrolls away (or a widget test that ends) leaves nothing pending.
    _start = Timer(Duration(milliseconds: 45 * widget.index), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) _c.value = 1;
  }

  @override
  void dispose() {
    _start?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_animates) return widget.child;
    return AnimatedBuilder(
      animation: _t,
      builder: (context, child) => Opacity(
        opacity: _t.value,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - _t.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}
