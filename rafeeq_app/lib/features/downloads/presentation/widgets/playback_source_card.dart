import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/byte_formatter.dart';
import '../../data/playback_source.dart';
import '../../data/reciters_provider.dart';

/// Which reciters are on the device, and where playback should come from.
///
/// «ولو أكتر من قارئ يقوللي فلان وفلان ويحطهم في قايمة وأنا أختار أشغّل من
/// التلاوة المحملة ولا من الـ API عشان أقدر أستخدم التطبيق مباشر مش أقعد لحد
/// ما يحمّل التلاوة الأول».
///
/// Two questions on one card, because they are the same question asked twice:
/// *whose* recitation, and *from where*.
class PlaybackSourceCard extends ConsumerWidget {
  const PlaybackSourceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final source = ref.watch(playbackSourceProvider);
    final downloaded = ref.watch(downloadedRecitersProvider);
    final selected = ref.watch(selectedReciterProvider);
    final arabic = context.locale.languageCode == 'ar';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.graphic_eq_rounded, size: 20, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'downloads.play_from'.tr(),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SegmentedButton<PlaybackSource>(
              segments: [
                ButtonSegment(
                  value: PlaybackSource.auto,
                  label: Text('downloads.play_auto'.tr()),
                ),
                ButtonSegment(
                  value: PlaybackSource.stream,
                  label: Text('downloads.play_stream'.tr()),
                ),
                ButtonSegment(
                  value: PlaybackSource.downloaded,
                  label: Text('downloads.play_offline'.tr()),
                ),
              ],
              selected: {source},
              showSelectedIcon: false,
              onSelectionChanged: (s) =>
                  ref.read(playbackSourceProvider.notifier).set(s.first),
            ),
            const SizedBox(height: 6),
            Text(
              switch (source) {
                PlaybackSource.auto => 'downloads.play_auto_desc'.tr(),
                PlaybackSource.stream => 'downloads.play_stream_desc'.tr(),
                PlaybackSource.downloaded => 'downloads.play_offline_desc'.tr(),
              },
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            downloaded.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (list) {
                if (list.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Text(
                      'downloads.on_this_device'.tr(),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: scheme.primary,
                          ),
                    ),
                    // `RadioGroup` rather than the deprecated per-tile
                    // `groupValue`/`onChanged` pair.
                    RadioGroup<String>(
                      groupValue: selected,
                      onChanged: (v) {
                        if (v != null) {
                          ref.read(selectedReciterProvider.notifier).select(v);
                        }
                      },
                      child: Column(
                        children: [
                    for (final r in list)
                      RadioListTile<String>(
                        value: r.edition,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(arabic ? r.nameAr : r.nameEn),
                        // A count, not a bar: "112 of 114" is the thing worth
                        // knowing, and it is also how an interrupted download
                        // makes itself visible.
                        subtitle: Text(
                          r.isWhole
                              ? 'downloads.whole_recitation'.tr()
                              : 'downloads.surahs_complete'.tr(args: [
                                  ltr('${r.completeSurahs}'),
                                  ltr('${r.totalSurahs}'),
                                ]),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
