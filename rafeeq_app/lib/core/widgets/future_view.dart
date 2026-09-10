import 'package:flutter/material.dart';

import 'error_retry.dart';

/// Renders a `FutureBuilder` snapshot without turning a failure into a
/// permanent spinner.
///
/// THE BUG THIS EXISTS FOR. Five screens wrote:
///
///     if (!snapshot.hasData) return const CircularProgressIndicator();
///
/// `hasData` is false in three different situations — still waiting, completed
/// with an **error**, and completed with null — and that line renders all three
/// as "loading". A query that throws therefore spins for ever, with no message,
/// no retry, and nothing in the UI to say anything went wrong. The owner hit
/// exactly that and described it as «لما بفتح سنن النسائي بتحمل على الفاضي ومش
/// بتنزل حاجة»: from the outside a failure and an infinite load are the same
/// picture.
///
/// All five of those screens are on the hadith/library path, which is the one
/// he was in.
///
/// [empty] is optional and separate on purpose: an empty list is a legitimate
/// answer ("this chapter has no hadiths"), not an error, and should not be
/// dressed as one — but it should not look like loading either.
class FutureView<T> extends StatelessWidget {
  final AsyncSnapshot<T> snapshot;
  final Widget Function(T data) builder;

  /// Re-runs the future. Required: a failure the user cannot retry is a dead
  /// end, which is the state this widget exists to remove.
  final VoidCallback onRetry;

  /// Shown when the future succeeded but produced nothing to display.
  final Widget? empty;

  /// Decides whether [empty] applies — e.g. `(list) => list.isEmpty`.
  final bool Function(T data)? isEmpty;

  const FutureView({
    super.key,
    required this.snapshot,
    required this.builder,
    required this.onRetry,
    this.empty,
    this.isEmpty,
  });

  @override
  Widget build(BuildContext context) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError) {
      return ErrorRetry(onRetry: onRetry);
    }
    final data = snapshot.data;
    // Completed, no error, and still nothing: not a state this app's futures
    // are supposed to reach, so it is reported rather than shown as loading.
    if (data == null) {
      return ErrorRetry(onRetry: onRetry);
    }
    if (empty != null && (isEmpty?.call(data) ?? false)) {
      return empty!;
    }
    return builder(data);
  }
}
