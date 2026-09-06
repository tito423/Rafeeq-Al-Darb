import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/services/ayah_audio_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../quran/data/mushaf_data_provider.dart';

/// P3‑27: a small card right under the reciter dropdown offering to download
/// the reciter's **whole** recitation in one action.
///
/// P3‑54 rewrite: the 114-surah loop used to run *inside this widget*, with an
/// `if (!mounted) return;` in it — so leaving the Downloads screen aborted the
/// whole download. It now runs in `AyahAudioService` (survives navigation,
/// protected by the foreground service), and this card is a thin
/// `ValueListenableBuilder` over the service's live `fullJob` state: real-time
/// progress that keeps ticking whether or not this widget is on screen.
///
/// Still a public widget (P3‑21) so first-run onboarding can reuse the exact
/// same real "essential recitation download" (G5).
class FullRecitationCard extends StatefulWidget {
  final String edition;
  final MushafData data;
  final VoidCallback onFinished;
  const FullRecitationCard({
    super.key,
    required this.edition,
    required this.data,
    required this.onFinished,
  });

  @override
  State<FullRecitationCard> createState() => _FullRecitationCardState();
}

class _FullRecitationCardState extends State<FullRecitationCard> {
  final _audio = AyahAudioService.instance;

  @override
  void initState() {
    super.initState();
    _seed();
  }

  @override
  void didUpdateWidget(covariant FullRecitationCard old) {
    super.didUpdateWidget(old);
    if (old.edition != widget.edition) _seed();
  }

  /// Seed the live state from disk for this reciter (no-op while a run for this
  /// edition is already in progress). Does NOT cancel another reciter's run —
  /// switching reciters now just shows the other one's live state; the previous
  /// download, if any, keeps going in the background in the service.
  void _seed() {
    _audio.refreshFullJob(widget.edition, widget.data.surahs, widget.data.repo);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ValueListenableBuilder<FullRecitationState>(
      valueListenable: _audio.fullJob(widget.edition),
      builder: (context, state, _) {
        final complete = state.isComplete;
        final running = state.running;
        return Card(
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  complete
                      ? Icons.offline_pin
                      : Icons.download_for_offline_outlined,
                  color: complete ? AppColors.success : AppColors.gold,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('downloads.download_all_recitation'.tr(),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      if (running) ...[
                        LinearProgressIndicator(
                          value: state.fraction,
                          color: AppColors.gold,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${state.doneSurahs} / ${state.totalSurahs} '
                          '${'quran.surah'.tr()}',
                          style: TextStyle(
                              color: scheme.onSurfaceVariant, fontSize: 12),
                        ),
                      ] else
                        Text(
                          complete
                              ? 'downloads.offline_ready'.tr()
                              : '${state.doneSurahs} / ${state.totalSurahs} '
                                  '${'quran.surah'.tr()}',
                          style: TextStyle(
                              color: scheme.onSurfaceVariant, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                if (!complete)
                  running
                      ? IconButton(
                          tooltip: 'downloads.cancel'.tr(),
                          icon: const Icon(Icons.stop_circle_outlined),
                          onPressed: () =>
                              _audio.cancelFullDownload(widget.edition),
                        )
                      : FilledButton.tonal(
                          onPressed: () async {
                            await _audio.startFullDownload(
                              edition: widget.edition,
                              surahs: widget.data.surahs,
                              repo: widget.data.repo,
                            );
                            widget.onFinished();
                          },
                          child: Text('downloads.download'.tr()),
                        ),
              ],
            ),
          ),
        );
      },
    );
  }
}
