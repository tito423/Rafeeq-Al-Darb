import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/services/ayah_audio_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/islamic_pattern.dart';
import '../../../quran/data/mushaf_data_provider.dart';

/// The headline card of the recitations tab: download this reciter's **whole**
/// recitation in one action.
///
/// The 114-surah loop runs in `AyahAudioService`, not in this widget — an
/// earlier version drove it from here with an `if (!mounted) return;` inside,
/// so leaving the Downloads screen aborted the download halfway. This card is
/// a thin `ValueListenableBuilder` over the service's live `fullJob` state:
/// real-time progress that keeps ticking whether or not the widget is on
/// screen, and reattaches to the same run when it comes back.
///
/// Public (rather than private to the screen) so first-run onboarding can
/// offer the exact same real download.
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

  /// Seed the live state from disk for this reciter (no-op while a run for
  /// this edition is already in progress). Does NOT cancel another reciter's
  /// run — switching reciters just shows the other one's live state; the
  /// previous download keeps going in the service.
  void _seed() {
    _audio.refreshFullJob(widget.edition, widget.data.surahs, widget.data.repo);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<FullRecitationState>(
      valueListenable: _audio.fullJob(widget.edition),
      builder: (context, state, _) {
        final complete = state.isComplete;
        final running = state.running;
        final currentSurah = state.currentSurahId == null
            ? null
            : widget.data.surahs
                  .where((s) => s.id == state.currentSurahId)
                  .firstOrNull;

        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
          child: IslamicPatternPanel(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            radius: 20,
            colors: complete
                ? const [AppColors.goldContainer, AppColors.nightSurface]
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: (complete ? AppColors.success : AppColors.gold)
                            .withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        complete
                            ? Icons.offline_pin_rounded
                            : Icons.download_for_offline_rounded,
                        color: complete ? AppColors.success : AppColors.gold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'downloads.download_all_recitation'.tr(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.textHigh,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            complete
                                ? 'downloads.offline_ready'.tr()
                                : '${state.doneSurahs} / ${state.totalSurahs} '
                                      '${'quran.surah'.tr()}',
                            style: const TextStyle(
                              color: AppColors.textMedium,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!complete)
                      running
                          ? IconButton(
                              tooltip: 'downloads.cancel'.tr(),
                              icon: const Icon(
                                Icons.stop_circle_rounded,
                                color: AppColors.error,
                              ),
                              onPressed: () =>
                                  _audio.cancelFullDownload(widget.edition),
                            )
                          : FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.gold,
                                foregroundColor: AppColors.night,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () async {
                                await _audio.startFullDownload(
                                  edition: widget.edition,
                                  surahs: widget.data.surahs,
                                  repo: widget.data.repo,
                                );
                                widget.onFinished();
                              },
                              icon: const Icon(Icons.download_rounded, size: 18),
                              label: Text('downloads.download'.tr()),
                            ),
                  ],
                ),
                if (running) ...[
                  const SizedBox(height: 12),
                  GoldProgressBar(value: state.fraction),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.gold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          currentSurah == null
                              ? 'downloads.preparing'.tr()
                              : 'downloads.now_downloading'.tr(
                                  args: [currentSurah.nameAr],
                                ),
                          style: const TextStyle(
                            color: AppColors.textMedium,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
