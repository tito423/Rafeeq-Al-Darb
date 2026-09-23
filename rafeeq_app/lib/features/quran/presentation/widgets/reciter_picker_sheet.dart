import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/recitation_source.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/arabic_normalize.dart';
import '../../../../core/utils/digits.dart';
import '../../../downloads/data/reciters_provider.dart';
import '../../../quran_audio/data/ayah_recitation_library.dart';

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

  /// «لو موجود في التطبيق يشغله ولو مش موجود يجيبه من النت» (2026-09-23): a
  /// reciter with ayahs downloaded plays them from the device
  /// ([RecitationSource.urlsFor] prefers the local file), so he is marked and
  /// listed first. The counts are read once the library has loaded.
  final _library = AyahRecitationLibrary.instance;
  bool _libraryReady = false;

  @override
  void initState() {
    super.initState();
    _library.ensureReady().then((_) {
      if (mounted) setState(() => _libraryReady = true);
    });
  }

  int _onDevice(String id) => _libraryReady ? _library.downloadedCount(id) : 0;

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
        final da = _onDevice(a.identifier) > 0 ? 0 : 1;
        final db = _onDevice(b.identifier) > 0 ? 0 : 1;
        if (da != db) return da - db;
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
          // WHAT THE TWO ICONS MEAN. They were a gold bolt and a grey cloud
          // with nothing saying which was which — «الأيقونات مختلفة بتاعة
          // القارئ مش فاهم دلالتها». The distinction is real and worth
          // keeping (a verified everyayah mirror plays ayah by ayah without
          // stalling; the CDN fallback does not always), so it is labelled
          // rather than removed.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
            child: Row(
              children: [
                Icon(Icons.bolt_rounded,
                    size: 16, color: goldOn(Theme.of(context).colorScheme)),
                const SizedBox(width: 4),
                Flexible(
                  child: Text('quran.reciter_legend_fast'.tr(),
                      style: TextStyle(
                          fontSize: 11.5,
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
                const SizedBox(width: 12),
                Icon(Icons.offline_pin_rounded,
                    size: 16, color: goldOn(Theme.of(context).colorScheme)),
                const SizedBox(width: 4),
                Flexible(
                  child: Text('quran.reciter_on_device'.tr(),
                      style: TextStyle(
                          fontSize: 11.5,
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
                const SizedBox(width: 12),
                Icon(Icons.cloud_outlined,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Flexible(
                  child: Text('quran.reciter_legend_stream'.tr(),
                      style: TextStyle(
                          fontSize: 11.5,
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (context, i) {
                final r = list[i];
                final isSelected = r.identifier == selected;
                final fast = RecitationSource.hasVerifiedMirror(r.identifier);
                final onDevice = _onDevice(r.identifier);
                return ListTile(
                  leading: Icon(
                    onDevice > 0
                        ? Icons.offline_pin_rounded
                        : fast
                            ? Icons.bolt_rounded
                            : Icons.cloud_outlined,
                    color: onDevice > 0 || fast
                        ? goldOn(Theme.of(context).colorScheme)
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  subtitle: onDevice > 0
                      ? Text('quran.reciter_on_device_count'.tr(
                          args: [pluralN('quran.ayahs', onDevice)]))
                      : null,
                  title: Text(
                    r.displayName(locale),
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                      color: isSelected
                          ? goldOn(Theme.of(context).colorScheme)
                          : null,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_circle_rounded,
                          color: goldOn(Theme.of(context).colorScheme))
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
