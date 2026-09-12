/// The two dialogs the sciences header opens: the repeat-count picker and
/// the ayah note editor.
library;


// easy_localization re-exports package:intl, whose `TextDirection` (LTR/RTL)
// collides with the `dart:ui` enum (rtl/ltr) used throughout this file.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/db/models.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../data/ayah_notes_store.dart';

/// P2‑8 #1 (Ayat-style memorization loop) — picks how many times to repeat
/// the current ayah's recitation and the gap between repetitions, and pops
/// `(times, gapSeconds)`. Deliberately does **not** start playback or touch
/// `ScaffoldMessenger` itself — this dialog's own context is torn down the
/// instant it pops, and a SnackBar scheduled through a closing dialog's
/// context can end up stuck on screen (observed live: it never
/// auto-dismissed). The caller, whose context outlives the dialog, does
/// both once this returns.
class RepeatDialog extends StatefulWidget {
  const RepeatDialog({super.key});

  @override
  State<RepeatDialog> createState() => RepeatDialogState();
}

class RepeatDialogState extends State<RepeatDialog> {
  int _times = 3;
  int _gapSeconds = 1;

  /// «شيل ٣ و٥ و١٠ وخليه سكرول بار بعدد المرات اللي أنا عايزها وجنبه مربع لو
  /// عايز أدخل التكرار يدوي». The slider covers the common range; the box
  /// takes anything up to [_maxTyped].
  static const _sliderMax = 50;
  static const _maxTyped = 999;
  static const _gapOptions = [0, 1, 2, 3];

  late final TextEditingController _timesField =
      TextEditingController(text: '$_times');

  @override
  void dispose() {
    _timesField.dispose();
    super.dispose();
  }

  void _fromSlider(int n) {
    setState(() => _times = n);
    _timesField.text = '$n';
  }

  @override
  Widget build(BuildContext context) {
    final gold = AppColors.gold;
    return AlertDialog(
      title: Text('quran.repeat_dialog_title'.tr()),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('quran.repeat_count'.tr()),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _times.clamp(1, _sliderMax).toDouble(),
                  min: 1,
                  max: _sliderMax.toDouble(),
                  divisions: _sliderMax - 1,
                  label: '$_times',
                  onChanged: (v) => _fromSlider(v.round()),
                ),
              ),
              SizedBox(
                width: 68,
                child: TextField(
                  controller: _timesField,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (t) {
                    final n = int.tryParse(t.trim());
                    if (n != null && n >= 1 && n <= _maxTyped) {
                      setState(() => _times = n);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('quran.repeat_gap'.tr()),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final g in _gapOptions)
                ChoiceChip(
                  label: Text('${g}s'),
                  selected: _gapSeconds == g,
                  selectedColor: gold.withValues(alpha: 0.25),
                  onSelected: (_) => setState(() => _gapSeconds = g),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop((_times, _gapSeconds)),
          child: Text('quran.repeat_start'.tr()),
        ),
      ],
    );
  }
}

/// P2‑8 #7 — a private free-text note attached to this ayah.
class NoteDialog extends ConsumerStatefulWidget {
  final Ayah ayah;
  final String initialText;

  const NoteDialog({super.key, required this.ayah, required this.initialText});

  @override
  ConsumerState<NoteDialog> createState() => NoteDialogState();
}

class NoteDialogState extends ConsumerState<NoteDialog> {
  late final _controller = TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('quran.note'.tr()),
      content: TextField(
        controller: _controller,
        maxLines: 5,
        minLines: 3,
        textDirection: TextDirection.rtl,
        decoration: InputDecoration(
          hintText: 'quran.note_hint'.tr(),
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        if (widget.initialText.isNotEmpty)
          TextButton(
            onPressed: () async {
              await ref
                  .read(ayahNotesProvider.notifier)
                  .clearNote(widget.ayah.surahId, widget.ayah.ayahNumber);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: Text(
              'quran.note_delete'.tr(),
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: () async {
            await ref.read(ayahNotesProvider.notifier).setNote(
                  widget.ayah.surahId,
                  widget.ayah.ayahNumber,
                  _controller.text,
                );
            if (context.mounted) Navigator.of(context).pop();
          },
          child: Text('common.save'.tr()),
        ),
      ],
    );
  }
}

/// The reciter the card will recite in, and a way to change them.
///
/// Deliberately the *same* provider and the *same* picker the page's
/// recitation bar uses, and it calls `AyahAudioService.switchReciter` exactly
/// as that bar does — two places that chose a reciter independently would be
/// two reciters, and the reader would have no way to tell which one a given
/// button was about to use.
