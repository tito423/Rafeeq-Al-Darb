import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// One toolbar action — icon + a short caption underneath, with a small
/// scale-down "press" animation instead of a plain flat `IconButton`.
/// [active] highlights it gold for a toggle-style action (e.g. "tashkeel
/// is currently shown", "this page is bookmarked") without needing a
/// second widget. Originally built for the Quran tab's toolbar (P3‑34),
/// pulled out to a shared location so `book_text_reader_screen.dart`
/// (P3‑29) can reuse the exact same look instead of a second copy.
class ToolbarAction extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool active;

  const ToolbarAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
  });

  @override
  State<ToolbarAction> createState() => _ToolbarActionState();
}

class _ToolbarActionState extends State<ToolbarAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = widget.active ? AppColors.gold : scheme.onSurface;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.86 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 22, color: color),
              const SizedBox(height: 3),
              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: widget.active ? AppColors.gold : scheme.onSurfaceVariant,
                  fontWeight: widget.active ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
