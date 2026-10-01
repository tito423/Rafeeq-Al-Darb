import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/quran_fullscreen_provider.dart';

/// Hides the mushaf's floating controls by themselves: «خلي شريط الخيارات
/// يختفي لوحده بعد خمس ثواني هو والرقم اللي تحت» (owner, 2026-09-27). Each
/// time [visible] turns true a timer starts; when it runs out [onHide] is
/// called. A tap on the page shows them again for another [delay].
///
/// It also tells the shell whether they are showing
/// (`quranChromeShownProvider`), so the tabs come back with them, and that
/// they are gone when full screen ends and this leaves the tree.
class ChromeAutoHide extends ConsumerStatefulWidget {
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
  ConsumerState<ChromeAutoHide> createState() => _ChromeAutoHideState();
}

class _ChromeAutoHideState extends ConsumerState<ChromeAutoHide> {
  Timer? _timer;
  late final StateController<bool> _shown =
      ref.read(quranChromeShownProvider.notifier);

  /// After the frame: a provider may not change while widgets build.
  void _report(bool v) => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_shown.state != v) _shown.state = v;
      });

  void _arm() {
    _report(widget.visible);
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
    _report(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
