import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// What a long press on a verse does while continuous recitation runs.
enum RecitingAyahChoice { tafsir, startHere }

/// «اثناء ما التلاوة المستمرة شغالة … اضغط على آية ضغطة طويلة … تتظلل ويطلع
/// لي اختيارين: كارت التفسير ولا بدء التلاوة من هنا» (owner, 2026-10-03).
/// Only shown while the recitation runs; otherwise the press opens the card.
Future<RecitingAyahChoice?> showRecitingAyahChoice(
  BuildContext context, {
  required String title,
}) {
  return showModalBottomSheet<RecitingAyahChoice>(
    context: context,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.play_circle_outline),
            title: Text('quran.recite_choice_start_here'.tr()),
            onTap: () => Navigator.pop(ctx, RecitingAyahChoice.startHere),
          ),
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: Text('quran.recite_choice_tafsir'.tr()),
            onTap: () => Navigator.pop(ctx, RecitingAyahChoice.tafsir),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
