import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/recitation_source.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/arabic_normalize.dart';
import '../../../downloads/data/reciters_provider.dart';

/// «اديني في خيارات تلاوة الآية بآية إمكانية اختيار القارئ في البلاير
/// الصغير». Opened from the recitation bar under the page; returns the
/// chosen edition, or null.
///
/// Reciters with a verified everyayah mirror are listed first and marked:
/// they are the fast, reliable per-ayah source, the rest stream from the CDN.
Future<String?> showReciterPickerSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _ReciterPickerSheet(),
  );
}

class _ReciterPickerSheet extends ConsumerStatefulWidget {
  const _ReciterPickerSheet();

  @override
  ConsumerState<_ReciterPickerSheet> createState() => _ReciterPickerSheetState();
}

class _ReciterPickerSheetState extends ConsumerState<_ReciterPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.languageCode;
    final selected = ref.watch(selectedReciterProvider);
    final all = ref.watch(recitersProvider).valueOrNull ?? const <Reciter>[];
    final q = normalizeArabic(_query.trim().toLowerCase());
    final list = [
      for (final r in all)
        if (q.isEmpty ||
            normalizeArabic(r.nameAr).contains(q) ||
            r.nameEn.toLowerCase().contains(q))
          r,
    ]..sort((a, b) {
        final ma = RecitationSource.hasVerifiedMirror(a.identifier) ? 0 : 1;
        final mb = RecitationSource.hasVerifiedMirror(b.identifier) ? 0 : 1;
        return ma != mb ? ma - mb : a.displayName(locale).compareTo(b.displayName(locale));
      });

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Column(
        children: [
          Text('quran.recite_choose_reciter'.tr(),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'quran.recite_search_reciter'.tr(),
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (context, i) {
                final r = list[i];
                final isSelected = r.identifier == selected;
                final fast = RecitationSource.hasVerifiedMirror(r.identifier);
                return ListTile(
                  leading: Icon(
                    fast ? Icons.bolt_rounded : Icons.cloud_outlined,
                    color: fast ? AppColors.gold : AppColors.textLow,
                  ),
                  title: Text(
                    r.displayName(locale),
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                      color: isSelected ? AppColors.gold : null,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle_rounded, color: AppColors.gold)
                      : null,
                  onTap: () => Navigator.of(context).pop(r.identifier),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
