import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The one error-state widget every `AsyncValue.when(error: ...)` branch
/// should render — a message plus a real "Retry" button that calls
/// [onRetry] (almost always `() => ref.invalidate(someProvider)`).
///
/// Before this existed, error branches across the app were bare
/// `Center(child: Text('errors.generic'.tr()))` with no way to recover
/// short of leaving the screen and coming back — a real gap against the
/// P2‑10 usability acceptance ("every screen has loading / empty /
/// error+retry states"). Use this instead of writing that by hand again.
class ErrorRetry extends StatelessWidget {
  final VoidCallback onRetry;
  final String? message;

  const ErrorRetry({super.key, required this.onRetry, this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 32, color: scheme.onSurfaceVariant),
            const SizedBox(height: 10),
            Text(
              message ?? 'errors.generic'.tr(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text('common.retry'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
