/// What a reader is told when a recitation gives him nothing — plainly.
///
/// A technical «تشخيص التلاوة» screen (devices, volumes, per-host fetches)
/// was built on 2026-09-23 and removed the same evening by the owner: «انا
/// مش عايز ده اصلا في التطبيق ده ميهمش القارئ في حاجة، ممكن هنت بسيط بس». So
/// the reader gets a sentence and, on request, four short tips in his own
/// language. The host and the exception still exist — `AudioFailure` keeps
/// them and `AyahAudioService` logs them — for whoever fixes it, not for the
/// reader.
///
/// The tips are the causes actually met: the owner's silence was his Honor's
/// per-app volume slider at zero for this app, which nothing in the app can
/// read or change.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'fitted_sheet.dart';

void showRecitationFailure(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('quran.recite_failed'.tr()),
      duration: const Duration(seconds: 7),
      action: SnackBarAction(
        label: 'diag.action'.tr(),
        onPressed: () {
          if (context.mounted) showSilenceTips(context);
        },
      ),
    ),
  );
}

/// «لا تسمع التلاوة؟» — four things to check, nothing technical.
Future<void> showSilenceTips(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return showFittedSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'diag.tips_title'.tr(),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            for (final (icon, key) in const [
              (Icons.volume_up_rounded, 'diag.tip_volume'),
              (Icons.tune_rounded, 'diag.tip_app_volume'),
              (Icons.bluetooth_audio_rounded, 'diag.tip_bluetooth'),
              (Icons.wifi_rounded, 'diag.tip_network'),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 20, color: AppColors.gold),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        key.tr(),
                        style: TextStyle(
                            color: scheme.onSurfaceVariant, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
