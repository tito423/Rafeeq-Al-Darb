// easy_localization re-exports package:intl, whose `TextDirection` (LTR/RTL)
// collides with the `dart:ui` enum (ltr/rtl) this file needs.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import '../../../../core/db/hadith_repository.dart';

/// The hadith's translation, shown under the Arabic whenever the app is not
/// in Arabic — on the daily card and on the detail screen alike.
///
/// **Why there is only one translation language.** `hadith.db` carries an
/// English rendering for 36,148 of the 67,153 hadiths, taken from sunnah.com's
/// published translations (Muhsin Khan for al-Bukhari, Siddiqui for Muslim,
/// and so on) — named translators, which is what a translation of hadith has
/// to have. There is no Spanish or Portuguese rendering of these collections
/// in any redistributable source at all, and the French, Urdu and Russian sets
/// that do circulate publicly name **no translator** and, on inspection, read
/// as translations of the English rather than of the Arabic. Shipping those
/// under «الترجمة الفرنسية لصحيح البخاري» would be exactly the unattributed
/// religious content this project does not ship.
///
/// So the label always says WHICH language this is and where it came from,
/// rather than letting a Spanish reader assume the paragraph is Spanish; and
/// where a collection has no translation at all — Musnad Ahmad's 27,584 and
/// al-Darimi's 3,406 — that is stated instead of left blank.
class HadithTranslation extends StatelessWidget {
  final HadithItem item;

  /// The card is a preview, so it clamps; the detail screen shows all of it.
  final int? maxLines;

  const HadithTranslation({super.key, required this.item, this.maxLines});

  @override
  Widget build(BuildContext context) {
    if (context.locale.languageCode == 'ar') return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = (item.textEn ?? '').trim();
    final narrator = (item.narratorEn ?? '').trim();

    final caption = Text(
      text.isEmpty
          ? 'library.translation_none'.tr()
          : 'library.translation_en_label'.tr(),
      style: theme.textTheme.labelSmall?.copyWith(color: scheme.outline),
    );
    if (text.isEmpty) {
      return Padding(padding: const EdgeInsets.only(top: 10), child: caption);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          caption,
          const SizedBox(height: 6),
          if (narrator.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                narrator,
                // The translation is English prose whatever the app's own
                // language is, so it is laid out left-to-right even inside
                // the RTL shell an Urdu reader sees.
                textDirection: TextDirection.ltr,
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          Text(
            text,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            maxLines: maxLines,
            overflow: maxLines == null ? null : TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }
}
