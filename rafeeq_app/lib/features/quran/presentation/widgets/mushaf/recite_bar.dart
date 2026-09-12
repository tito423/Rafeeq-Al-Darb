/// The bar that runs under the page while a continuous recitation is
/// playing: which ayah is sounding, and the transport controls.
library;


import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/services/ayah_audio_service.dart';

/// Quran tab — a real mushaf browser.
///  • Text mode: real Uthmani ayahs laid out by their real Madani page
///    boundaries from the bundled database (works fully offline).
///  • Image mode: the authentic KFQC mushaf pages as vector art, cached on
///    device, with the real ayah polygons layered on top for tap/highlight.

/// The compact transport shown under the page while continuous recitation is
/// running: which verse is sounding, and the three controls a listener
/// actually reaches for.
class ReciteBar extends StatelessWidget {
  final ContinuousRecitation state;
  final String reciterName;
  final VoidCallback onPickReciter;
  const ReciteBar({
    super.key,
    required this.state,
    required this.reciterName,
    required this.onPickReciter,
  });

  @override
  Widget build(BuildContext context) {
    final audio = AyahAudioService.instance;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
      child: Material(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
          child: Row(
            children: [
              Icon(
                state.stalled
                    ? Icons.play_circle_outline_rounded
                    : state.buffering
                        ? Icons.hourglass_top_rounded
                        : Icons.graphic_eq_rounded,
                size: 18,
                color: AppColors.gold,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  state.stalled
                      ? 'quran.recite_stalled'.tr()
                      : state.buffering
                      ? 'quran.recite_loading'.tr()
                      : 'quran.recite_now'.tr(
                          args: [
                            '${state.surahId ?? ''}',
                            '${state.ayahNumber ?? ''}',
                          ],
                        ) + (reciterName.isEmpty ? '' : '  ·  $reciterName'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: scheme.onSurface),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'quran.recite_choose_reciter'.tr(),
                icon: const Icon(Icons.record_voice_over_rounded,
                    color: AppColors.gold),
                onPressed: onPickReciter,
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'quran.recite_previous'.tr(),
                icon: const Icon(Icons.skip_previous_rounded),
                onPressed: audio.continuousPrevious,
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: (state.stalled
                        ? 'quran.recite_resume'
                        : 'quran.recite_pause')
                    .tr(),
                icon: Icon(state.stalled
                    ? Icons.play_circle_outline_rounded
                    : Icons.pause_circle_outline_rounded),
                onPressed: audio.continuousPauseResume,
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'quran.recite_next'.tr(),
                icon: const Icon(Icons.skip_next_rounded),
                onPressed: audio.continuousNext,
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'quran.recite_stop'.tr(),
                icon: Icon(Icons.stop_circle_outlined, color: scheme.error),
                onPressed: audio.stopContinuous,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// P3‑43 #7: a real printed mushaf's running header — page number bottom
/// centre, surah name top-right, juz name top-left — kept on screen
/// regardless of toolbar visibility or full-screen mode (it's reading
/// context, not an "option"). Fixed physical corners, not RTL `start`/
/// `end`: a real mushaf page's own running headers don't mirror with the
/// *app's* locale, they're a property of the page itself. `IgnorePointer`
/// throughout so it never steals the background tap that toggles the
/// toolbar or exits full-screen.
