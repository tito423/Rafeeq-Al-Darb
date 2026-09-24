import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Stands where the auto-scroll speed bar stands while a continuous
/// recitation drives the page.
///
/// «مزامنة بين وضع التلاوة المستمرة والتمرير التلقائي» (2026-09-24). The two
/// used to run at once: the auto-scroll ticker moved at its fixed speed and
/// turned the page at the bottom, the recitation turned it when the reciter
/// crossed - so the page ran ahead of the reciter and was dragged back.
/// While a recitation sounds, the page follows the highlighted verse at the
/// reciter's own pace (`MushafTextPage._scrollToPlayingAyah`); the fixed
/// speed yields, and comes back by itself when the recitation stops. This
/// line says so, so the reader knows why the speed control went away and
/// that auto-scroll is still on.
class FollowsRecitationNote extends StatelessWidget {
  const FollowsRecitationNote({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sync_rounded, size: 16, color: scheme.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'quran.autoscroll_follows'.tr(),
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
