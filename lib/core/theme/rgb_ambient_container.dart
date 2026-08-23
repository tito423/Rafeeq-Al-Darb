import 'dart:math';
import 'package:flutter/material.dart';

/// Wraps widgets with a subtle, ambient shifting RGB glow when the RGB theme is enabled.
class RgbAmbientContainer extends StatefulWidget {
  final Widget child;
  final bool isRgb;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? baseColor;

  const RgbAmbientContainer({
    super.key,
    required this.child,
    this.isRgb = false,
    this.borderRadius = 16,
    this.padding,
    this.margin,
    this.baseColor,
  });

  @override
  State<RgbAmbientContainer> createState() => _RgbAmbientContainerState();
}

class _RgbAmbientContainerState extends State<RgbAmbientContainer>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;

  @override
  void initState() {
    super.initState();
    if (widget.isRgb) {
      _startAnim();
    }
  }

  void _startAnim() {
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void didUpdateWidget(RgbAmbientContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRgb && _ctrl == null) {
      _startAnim();
    } else if (!widget.isRgb && _ctrl != null) {
      _ctrl?.dispose();
      _ctrl = null;
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isRgb || _ctrl == null) {
      return Container(
        margin: widget.margin,
        padding: widget.padding,
        decoration: BoxDecoration(
          color: widget.baseColor,
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
        child: widget.child,
      );
    }

    return AnimatedBuilder(
      animation: _ctrl!,
      builder: (context, child) {
        final t = _ctrl!.value;
        final c1 = HSLColor.fromAHSV(1.0, (t * 360) % 360, 0.75, 0.65).toColor();
        final c2 = HSLColor.fromAHSV(1.0, ((t * 360) + 120) % 360, 0.75, 0.65).toColor();
        final c3 = HSLColor.fromAHSV(1.0, ((t * 360) + 240) % 360, 0.75, 0.65).toColor();

        return Container(
          margin: widget.margin,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: SweepGradient(
              center: Alignment.center,
              startAngle: 0.0,
              endAngle: 2 * pi,
              transform: GradientRotation(t * 2 * pi),
              colors: [c1, c2, c3, c1],
            ),
            boxShadow: [
              BoxShadow(
                color: c1.withValues(alpha: 0.25),
                blurRadius: 14,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Container(
            margin: const EdgeInsets.all(1.5), // Animated border width
            padding: widget.padding,
            decoration: BoxDecoration(
              color: widget.baseColor ?? const Color(0xFF0D121F),
              borderRadius: BorderRadius.circular(widget.borderRadius - 1.5),
            ),
            child: widget.child,
          ),
        );
      },
    );
  }
}
