import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/db/models.dart';

void showSurahSheet(
  BuildContext context, {
  required List<Surah> surahs,
  required Map<int, int> startPages,
  required ValueChanged<int> onSelect,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'quran.surah_list'.tr(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: surahs.length,
                itemBuilder: (context, i) {
                  final s = surahs[i];
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
                      '${s.ayahsCount} ${'quran.ayahs'.tr()} — '
                      '${s.revelationType == 'Meccan' ? 'quran.makkah'.tr() : 'quran.madinah'.tr()}'
                      '  •  p.${startPages[s.id] ?? 1}',
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
      },
    ),
  );
}

void showJuzSheet(
  BuildContext context, {
  required Map<int, int> juzStartPages,
  required ValueChanged<int> onSelect,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'quran.juz'.tr(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: 30,
                itemBuilder: (context, i) {
                  final juz = i + 1;
                  return ListTile(
                    leading: const Icon(Icons.radio_button_unchecked),
                    title: Text(
                      'الجزء ${_arabicNumber(juz)}',
                      textAlign: TextAlign.right,
                    ),
                    trailing: Text('p.${juzStartPages[juz] ?? 1}'),
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
      },
    ),
  );
}

void showGotoPageSheet(
  BuildContext context, {
  required int current,
  required ValueChanged<int> onSelect,
}) {
  showDialog<void>(
    context: context,
    builder: (ctx) {
      final controller = TextEditingController(text: '$current');
      return AlertDialog(
        title: Text('quran.jump_to'.tr()),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'quran.page'.tr(),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(controller.text.trim());
              Navigator.pop(ctx);
              if (n != null && n >= 1 && n <= 604) onSelect(n);
            },
            child: Text('common.save'.tr()),
          ),
        ],
      );
    },
  );
}

String _arabicNumber(int n) {
  const digits = '٠١٢٣٤٥٦٧٨٩';
  return n.toString().split('').map((c) => digits[int.parse(c)]).join();
}