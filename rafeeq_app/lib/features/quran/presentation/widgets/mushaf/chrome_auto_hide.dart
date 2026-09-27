import 'dart:async';

import 'package:flutter/widgets.dart';

/// Hides the mushaf's floating controls by themselves: «خلي شريط الخيارات
/// يختفي لوحده بعد خمس ثواني هو والرقم اللي تحت» (owner, 2026-09-27). Each
/// time [visible] turns true a timer starts; when it runs out [onHide] is
/// called. A tap on the page shows them again for another [delay].
class ChromeAutoHide extends StatefulWidget {
  const ChromeAutoHide({
    super.key,
    required this.visible,
    required this.onHide,
    required this.child,
    this.delay = const Duration(seconds: 5),
  });

  final bool visible;
  final VoidCallback onHide;
  final Widget child;
  final Duration delay;

  @override
  State<ChromeAutoHide> createState() => _ChromeAutoHideState();
}

class _ChromeAutoHideState extends State<ChromeAutoHide> {
  Timer? _timer;

  void _arm() {
    _timer?.cancel();
    if (widget.visible) _timer = Timer(widget.delay, widget.onHide);
  }

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void didUpdateWidget(ChromeAutoHide old) {
    super.didUpdateWidget(old);
    if (old.visible != widget.visible) _arm();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
