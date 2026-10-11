import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Owns one microphone attempt. Native start/stop/routing operations share a
/// queue, so an old panel finishes cleanup before a new one opens its mic.
class TasmeeRecordingLease {
  static TasmeeRecordingLease? _owner;
  static Future<void>? _pending;
  static final _flags = Expando<TasmeeRecordingLease>();
  final StateController<bool> _flag;
  final void Function() _replaced;
  bool _active = true;

  TasmeeRecordingLease(this._flag, this._replaced) {
    _owner?._replaced();
    _owner = this;
    _flags[_flag] = this;
    if (_flag.mounted) _flag.state = true;
  }

  bool get current => _active && identical(_owner, this) && _flag.mounted;

  void invalidate() => _active = false;

  /// Defer provider notification beyond widget disposal/build, and never
  /// overwrite a newer lease's flag or write into a disposed provider scope.
  void releaseFlag() {
    scheduleMicrotask(() {
      if (!identical(_flags[_flag], this)) return;
      _flags[_flag] = null;
      if (_flag.mounted) _flag.state = false;
    });
  }

  void finish() {
    invalidate();
    if (identical(_owner, this)) _owner = null;
    releaseFlag();
  }

  static Future<void> run(Future<void> Function() work) {
    final previous = _pending;
    final next = () async {
      if (previous != null) {
        try {
          await previous;
        } catch (_) {
          // The original caller reports failure; it must not block cleanup.
        }
      }
      await work();
    }();
    _pending = next;
    void clear() {
      if (identical(_pending, next)) _pending = null;
    }

    unawaited(
      next.then((_) => clear(), onError: (Object _, StackTrace _) => clear()),
    );
    return next;
  }
}
