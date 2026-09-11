import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/db/models.dart';
import '../../../../core/utils/arabic_normalize.dart';
import '../../../../core/utils/byte_formatter.dart' show ltr;
import '../../../../core/utils/digits.dart';

/// What is typed in each sheet's search box. File-level because the sheets
/// are functions, not widgets, and the box has to survive the rebuild it
/// causes. Cleared when each sheet opens.
String _surahQuery = '';
String _juzQuery = '';

/// A search field for a sheet that lists a hundred and fourteen things.
///
/// «أضف بحث في أيقونة السور والأجزاء». Scrolling to Surah al-Mursalat past
/// seventy-six others is not navigation.
///
/// It matches on the **normalised** name, because the stored names are fully
/// vocalised (trap #2): «الفاتحة» typed plainly cannot match «ٱلْفَاتِحَة» with a
/// `contains`. It also matches the number, so «36» finds Ya-Sin.
class _SheetSearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;

  const _SheetSearchField({required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: TextField(
          autofocus: false,
          textInputAction: TextInputAction.search,
          onChanged: onChanged,
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
        ),
      );
}

/// True when [query] matches this row, by name or by number.
bool _rowMatches(String query, String name, int number) {
  final q = normalizeArabic(query.trim()).toLowerCase();
  if (q.isEmpty) return true;
  // The number, both as the reader types it and as the app draws it.
  if ('$number'.startsWith(q) || localizeDigits('$number', 'ar').startsWith(q)) {
    return true;
  }
  final n = normalizeArabic(name).toLowerCase();
  // Not a word-boundary test: in a list this short, a plain substring is what
  // someone expects — typing «قره» should find «البقرة».
  return n.contains(q) || normalizeArabicLoose(name).toLowerCase().contains(q);
}

void showSurahSheet(
  BuildContext context, {
  required List<Surah> surahs,
  required Map<int, int> startPages,
  required ValueChanged<int> onSelect,
}) {
  _surahQuery = '';
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return StatefulBuilder(builder: (context, setSheetState) {
        final query = _surahQuery;
        final shown = [
          for (final s in surahs)
            if (_rowMatches(query, s.nameAr, s.id)) s,
        ];
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'quran.surah_list'.tr(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            _SheetSearchField(
              hint: 'quran.search_surah_hint'.tr(),
              onChanged: (v) => setSheetState(() => _surahQuery = v),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: shown.length,
                itemBuilder: (context, i) {
                  final s = shown[i];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        '${s.id}',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                    title: Text(
                      s.nameAr,
                      style: const TextStyle(fontFamily: 'AmiriQuran'),
                      textAlign: TextAlign.right,
                    ),
                    subtitle: Text(
                      '${'quran.ayahs'.plural(s.ayahsCount)} — '
                      '${s.revelationType == 'Meccan' ? 'quran.makkah'.tr() : 'quran.madinah'.tr()}'
                      '  •  ${'quran.page'.tr()} ${startPages[s.id] ?? 1}',
                      textAlign: TextAlign.right,
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      onSelect(startPages[s.id] ?? 1);
                    },
                  );
                },
              ),
            ),
          ],
        );
        });
      },
    ),
  );
}

void showJuzSheet(
  BuildContext context, {
  required Map<int, int> juzStartPages,
  required ValueChanged<int> onSelect,
}) {
  _juzQuery = '';
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return StatefulBuilder(builder: (context, setSheetState) {
        final shown = [
          for (var j = 1; j <= 30; j++)
            if (_rowMatches(_juzQuery, '', j)) j,
        ];
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'quran.juz'.tr(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            _SheetSearchField(
              hint: 'quran.search_juz_hint'.tr(),
              onChanged: (v) => setSheetState(() => _juzQuery = v),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: shown.length,
                itemBuilder: (context, i) {
                  final juz = shown[i];
                  return ListTile(
                    leading: const Icon(Icons.radio_button_unchecked),
                    title: Text(
                      '${'quran.juz'.tr()} $juz',
                      textAlign: TextAlign.right,
                    ),
                    trailing:
                        Text('${'quran.page'.tr()} ${juzStartPages[juz] ?? 1}'),
                    onTap: () {
                      Navigator.pop(ctx);
                      onSelect(juzStartPages[juz] ?? 1);
                    },
                  );
                },
              ),
            ),
          ],
        );
        });
      },
    ),
  );
}

/// Ask for a page number.
///
/// [totalPages] is the CURRENT printing's page count, not 604. This used to be
/// a hard-coded `n <= 604`, which silently refused pages 605–611 of the
/// Nastaleeq mushaf and happily accepted page 600 of the Shamarly one, which
/// ends at 521 — the same family of bug as a surah index that lands on the
/// wrong surah.
void showGotoPageSheet(
  BuildContext context, {
  required int current,
  required int totalPages,
  required ValueChanged<int> onSelect,
}) {
  showDialog<void>(
    context: context,
    builder: (ctx) {
      final controller = TextEditingController(text: '$current');
      void submit() {
        final n = int.tryParse(controller.text.trim());
        Navigator.pop(ctx);
        if (n != null && n >= 1 && n <= totalPages) onSelect(n);
      }

      // What is left of the screen once the number pad is up. In landscape
      // that is about 380 of 1080 physical pixels, and the first fix — a
      // smaller inset — got both buttons on screen but left the title
      // clipped, seen on the emulator. Under that much pressure the title
      // goes: the field's own label already says «صفحة».
      final mq = MediaQuery.of(ctx);
      final room = mq.size.height - mq.viewInsets.bottom;
      final compact = room < 420;

      return AlertDialog(
        // The default 40-pixel inset spends 80 of those pixels on air, which
        // is why the owner's screenshot shows the keyboard sitting on top of
        // «حفظ». Scrollable so a shorter screen still reaches both buttons.
        insetPadding: EdgeInsets.symmetric(
          horizontal: 24,
          vertical: compact ? 8 : 12,
        ),
        scrollable: true,
        contentPadding: compact
            ? const EdgeInsets.fromLTRB(24, 16, 24, 0)
            : null,
        title: compact ? null : Text('quran.jump_to'.tr()),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.go,
          onSubmitted: (_) => submit(),
          decoration: InputDecoration(
            labelText: 'quran.page'.tr(),
            // Trap #16: a range of Latin numerals is bidi-weak, so in an
            // Arabic dialog «1 – 604» renders as «604 – 1» — seen on the
            // emulator before this line existed.
            helperText: ltr('1 – $totalPages'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: submit,
            child: Text('common.save'.tr()),
          ),
        ],
      );
    },
  );
}
