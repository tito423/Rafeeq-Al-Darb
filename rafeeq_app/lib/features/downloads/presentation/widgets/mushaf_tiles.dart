import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/error_retry.dart';
import '../../../quran/data/mushaf_edition.dart';
import 'mushaf_download_tile.dart';

/// The printings, at the foot of the overview rather than behind a tab of
/// their own - there is one of them.
class MushafTiles extends ConsumerWidget {
  const MushafTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editions = ref.watch(mushafEditionsProvider);
    return editions.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) =>
          ErrorRetry(onRetry: () => ref.invalidate(mushafEditionsProvider)),
      data: (list) => Column(
        children: [
          for (final e in list) ...[
            MushafDownloadTile(edition: e),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
