import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/arabic_text.dart';
import '../../../../core/widgets/remote_tap.dart';
import '../../data/hifz_mask.dart';

/// The ayah as the memorizer sees it at the chosen [cue] level: whole, first
/// letters only, every other word, the first word only, or nothing - with
/// any word the reader asked for ([peeked]) shown again. The ayah's text is
/// never changed; covering happens here (§1.2).
class HifzAyahView extends StatelessWidget {
  final List<String> words;
  final HifzCue cue;
  final Set<int> peeked;
  final ValueChanged<int> onPeek;
  final ValueChanged<HifzCue> onCue;

  /// Disabled while the tasmee' records: the ayah is hidden then, on purpose.
  final bool locked;

  const HifzAyahView({
    super.key,
    required this.words,
    required this.cue,
    required this.peeked,
    required this.onPeek,
    required this.onCue,
    this.locked = false,
  });

  bool _covered(int i) =>
      !peeked.contains(i) && hifzCueHidden(i, words.length, cue);

  bool _lettered(int i) => !peeked.contains(i) && cue == HifzCue.firstLetters;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final next = [
      for (var i = 0; i < words.length; i++)
        if (_covered(i) || _lettered(i)) i,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 10,
              children: [
                for (var i = 0; i < words.length; i++)
                  _Word(
                    word: words[i],
                    covered: _covered(i),
                    lettered: _lettered(i),
                    onTap: locked ? null : () => onPeek(i),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('hifz.cue_title'.tr(),
            style: TextStyle(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final c in HifzCue.values)
              ChoiceChip(
                label: Text('hifz.cue_${c.name}'.tr()),
                selected: cue == c,
                onSelected: locked ? null : (_) => onCue(c),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                // The next covered word, in reading order: the one the
                // reader is stuck on.
                onPressed: locked || next.isEmpty ? null : () => onPeek(next.first),
                icon: const Icon(Icons.lightbulb_outline_rounded),
                label: Text('hifz.hint'.tr()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: locked || cue == HifzCue.full
                    ? null
                    : () => onCue(HifzCue.full),
                icon: const Icon(Icons.visibility_outlined),
                label: Text('hifz.show_all'.tr()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'hifz.cue_note'.tr(),
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _Word extends StatelessWidget {
  final String word;
  final bool covered;
  final bool lettered;
  final VoidCallback? onTap;

  const _Word({
    required this.word,
    required this.covered,
    required this.lettered,
    required this.onTap,
  });

  static const _style = TextStyle(
    fontFamily: 'KFGQPCHafs',
    fontSize: 24,
    height: 1.9,
  );

  @override
  Widget build(BuildContext context) {
    if (!covered && !lettered) return ArabicText(word, style: _style);
    final line = Container(
      height: 3,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(2),
      ),
    );
    return RemoteTap(
      onTap: onTap ?? () {},
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The word keeps its own width, so the line does not jump when it
          // comes back.
          Opacity(opacity: 0, child: ArabicText(word, style: _style)),
          Positioned.fill(
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                if (lettered) ArabicText(hifzFirstLetter(word), style: _style),
                Expanded(child: line),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
