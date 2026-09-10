import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Times each step of `main()` and prints the result once, before the first
/// frame.
///
/// WHY THIS EXISTS. An ANR was caught twice on this app —
/// `Waited 5007ms for MotionEvent`, the UI frozen on Home — and the tools that
/// would normally answer it do not work here: `dumpsys gfxinfo` reports zero
/// frames for a Flutter app because it renders on its own thread,
/// `dumpsys SurfaceFlinger --latency` returned no rows on Android 16, and
/// `flutter run --trace-startup` produced no `start_up_info.json` on this
/// machine. Reading the code and guessing was the alternative, and this
/// project has a rule against that (§1.5: numbers are measured).
///
/// `main()` awaits a dozen plugin round-trips before `runApp`, and every one
/// of them is on the UI isolate — anything slow in there is a frozen app with
/// nothing on screen yet. This says which one, in milliseconds.
///
/// It costs nothing in a release build: every method compiles away behind
/// `kReleaseMode`, and the strings are never built.
class StartupTrace {
  StartupTrace._();

  static final Stopwatch _sw = Stopwatch();
  static final List<(String, int)> _steps = [];
  static int _last = 0;

  static bool get _on => !kReleaseMode;

  static void begin() {
    if (!_on) return;
    _sw.start();
    _last = 0;
  }

  /// Records that [label] finished, and how long it took on its own.
  static void step(String label) {
    if (!_on) return;
    final now = _sw.elapsedMilliseconds;
    _steps.add((label, now - _last));
    _last = now;
  }

  /// Prints the whole table, slowest first, plus the total.
  ///
  /// Goes through `developer.log` rather than `print` so it survives a release
  /// -mode toolchain untouched and is greppable in logcat under one tag.
  static void report() {
    if (!_on || _steps.isEmpty) return;
    final total = _sw.elapsedMilliseconds;
    final sorted = [..._steps]..sort((a, b) => b.$2.compareTo(a.$2));
    final buffer = StringBuffer('startup: ${total}ms total\n');
    for (final (label, ms) in sorted) {
      final share = total == 0 ? 0 : (100 * ms / total).round();
      buffer.writeln('  ${ms.toString().padLeft(5)}ms  ${share.toString()
          .padLeft(3)}%  $label');
    }
    developer.log(buffer.toString(), name: 'RafeeqStartup');
    // Also on the plain channel, because `developer.log` is filtered out of
    // logcat by some Android versions in profile builds.
    debugPrint('[RafeeqStartup] $buffer');
  }
}
