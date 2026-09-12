/// The ayah itself, as it is shown at the top of the sciences sheet — the
/// Uthmani text, and the transliteration when the reader has asked for one.
library;


// easy_localization re-exports package:intl, whose `TextDirection` (LTR/RTL)
// collides with the `dart:ui` enum (rtl/ltr) used throughout this file.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/db/models.dart';
import '../../../../../core/services/quran_api_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../settings/data/transliteration_settings_provider.dart';

/// The ayah itself, framed the way a printed mushaf frames its text,
/// with optional Latin transliteration for non-Arabic readers.
class AyahPanel extends ConsumerWidget {
  final Ayah ayah;
  const AyahPanel({super.key, required this.ayah});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final gold = AppColors.gold;
    // «ظاهر نطق الكلمات العربية بالإنجليزية مع إني مش مفعّل الخيار ده وكمان
    // أنا مختار اللغة العربية للتطبيق». The switch is a reading aid for
    // someone who cannot read the script — an Arabic-reading user has no use
    // for it, and a stored `true` from an older build (or from a moment when
    // the app was in another language) kept surfacing Latin text under every
    // ayah with no way to see, in Arabic, that anything was switched on.
    // The locale decides first; the switch only applies where it can help.
    final isArabicUi = context.locale.languageCode == 'ar';
    final showTransliteration =
        !isArabicUi && ref.watch(transliterationEnabledProvider);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: gold.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: gold.withValues(alpha: 0.3)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ayah.textUthmani,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: theme.textTheme.titleLarge?.copyWith(
                fontFamily: 'AmiriQuran',
                height: 2.0,
              ),
            ),
            if (showTransliteration) ...[
              const SizedBox(height: 8),
              Container(
                width: 48,
                height: 1.5,
                color: gold.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 8),
              FutureBuilder<String?>(
                future: ref
                    .read(quranApiServiceProvider)
                    .getAyahTransliteration(ayah.surahId, ayah.ayahNumber),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: gold.withValues(alpha: 0.6),
                        ),
                      ),
                    );
                  }
                  final text = snapshot.data;
                  if (text == null || text.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    text,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.ltr,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: gold,
                      height: 1.5,
                      letterSpacing: 0.25,
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shared loading / error / empty handling for every tab.
