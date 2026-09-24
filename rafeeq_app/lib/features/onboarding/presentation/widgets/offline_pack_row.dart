import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/digits.dart' show percentOf;

/// Where one offline pack stands right now.
class PackState {
  final bool done;
  final bool busy;

  /// 0..1 while [busy]; null when the total is not known yet.
  final double? progress;

  /// Still finding out what to offer (measuring hosts): a spinner, no action.
  final bool loading;

  const PackState({
    this.done = false,
    this.busy = false,
    this.progress,
    this.loading = false,
  });

  static const idle = PackState();
  static const installed = PackState(done: true);
  static const measuring = PackState(loading: true);
}

/// One row of «التحميلات المبدئية»: what the pack is, its measured size,
/// and download / progress + cancel / installed in ONE fixed-width slot.
///
/// The fixed slot is the fix for the row that jumped: the percentage used to
/// sit at its natural width, so «٩٪» → «١٠٪» → «١٠٠٪» narrowed the text
/// column, the hint re-wrapped, and the whole row changed height as the
/// download ran - the owner reported it twice. Fixed width + tabular
/// figures: nothing beside the slot moves while the number changes.
class OfflinePackRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String hint;
  final PackState state;
  final VoidCallback? onDownload;
  final VoidCallback? onCancel;

  /// Shown under the hint, e.g. a «تغيير» button for a choice of reciter.
  final Widget? footer;

  const OfflinePackRow({
    super.key,
    required this.icon,
    required this.title,
    required this.hint,
    required this.state,
    this.onDownload,
    this.onCancel,
    this.footer,
  });

  static const double trailingWidth = 104;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: goldText(context), size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(
                  hint,
                  style:
                      TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                ),
                ?footer,
                if (state.busy) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: state.progress,
                    color: AppColors.gold,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: trailingWidth,
            height: 40,
            child: Center(child: _trailing(context)),
          ),
        ],
      ),
    );
  }

  Widget _trailing(BuildContext context) {
    if (state.loading) {
      return const SizedBox.square(
        dimension: 22,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    }
    if (state.done) {
      return Icon(Icons.check_circle_rounded, color: goldText(context));
    }
    if (state.busy) {
      return Row(
        children: [
          Expanded(
            child: Text(
              state.progress == null ? '' : percentOf(state.progress!),
              textAlign: TextAlign.center,
              maxLines: 1,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          IconButton(
            tooltip: 'common.cancel'.tr(),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close_rounded),
            onPressed: onCancel,
          ),
        ],
      );
    }
    return FittedBox(
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.night,
        ),
        onPressed: onDownload,
        icon: const Icon(Icons.download_rounded, size: 18),
        label: Text('downloads.download'.tr()),
      ),
    );
  }
}
