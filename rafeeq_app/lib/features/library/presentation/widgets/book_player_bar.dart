import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/arabic_normalize.dart';
import '../../../../core/utils/digits.dart';
import '../../data/book_read_aloud.dart';
import '../../data/book_text.dart';

/// The listening controls under a book's page while it is read aloud:
/// previous sentence, pause/play, next sentence, the pace, a sleep timer,
/// stop - and, when the reader has turned to another page, the way back to
/// the sentence being heard. Hidden when nothing is being read.
class BookPlayerBar extends StatelessWidget {
  const BookPlayerBar({
    super.key,
    required this.aloud,
    required this.doc,
    required this.shownPage,
    required this.paper,
    required this.ink,
    required this.onBackToReading,
  });

  final BookReadAloud aloud;
  final BookText doc;
  final int shownPage;
  final Color paper;
  final Color ink;
  final VoidCallback onBackToReading;

  String _n(Object v) => localizeDigits('$v', uiLanguageCode);

  String _pace(double v) {
    var t = '$v';
    if (t.endsWith('.0')) t = t.substring(0, t.length - 2);
    return '${_n(t)}×';
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: aloud,
    builder: (context, _) {
      if (!aloud.active) return const SizedBox.shrink();
      final away = aloud.page != shownPage;
      final paused = aloud.state == ReadAloudState.paused;
      final preparing = aloud.state == ReadAloudState.preparing;
      final sleepLeft = aloud.sleepAt?.difference(DateTime.now()).inMinutes;
      final page = doc.printedPageAt(aloud.page) ?? aloud.page + 1;
      final status = preparing
          ? 'library.player_preparing'.tr()
          : trn('library.player_status', args: [
              _n(page),
              _n(aloud.index + 1),
              _n(aloud.chunks.length),
            ]);
      IconButton btn(IconData i, String tip, VoidCallback? f) => IconButton(
        icon: Icon(i),
        tooltip: tip,
        color: ink,
        visualDensity: VisualDensity.compact,
        onPressed: f,
      );
      return Material(
        color: paper,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: AppColors.gold.withValues(alpha: 0.45)),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ink.withValues(alpha: 0.8),
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  if (away)
                    TextButton.icon(
                      onPressed: onBackToReading,
                      icon: const Icon(Icons.my_location_rounded, size: 18),
                      label: Text('library.player_back'.tr()),
                    ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Under RTL «previous» is the right-hand arrow, as in
                  // the page rail: skip_next points forward in reading order.
                  btn(Icons.skip_next_rounded, 'library.player_prev'.tr(),
                      () => aloud.skip(-1)),
                  preparing
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                        )
                      : IconButton.filled(
                          icon: Icon(paused
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded),
                          tooltip: paused
                              ? 'library.player_play'.tr()
                              : 'library.player_pause'.tr(),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: aloud.toggle,
                        ),
                  btn(Icons.skip_previous_rounded, 'library.player_next'.tr(),
                      () => aloud.skip(1)),
                  PopupMenuButton<double>(
                    tooltip: 'library.player_speed'.tr(),
                    initialValue: aloud.speed,
                    onSelected: aloud.setSpeed,
                    itemBuilder: (_) => [
                      for (final v in BookReadAloud.speeds)
                        PopupMenuItem(value: v, child: Text(_pace(v))),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      child: Text(
                        _pace(aloud.speed),
                        style: TextStyle(
                          color: ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  PopupMenuButton<int>(
                    tooltip: 'library.player_sleep'.tr(),
                    onSelected: aloud.setSleep,
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 0,
                        child: Text('library.sleep_off'.tr()),
                      ),
                      PopupMenuItem(
                        value: -1,
                        child: Text('library.sleep_end_page'.tr()),
                      ),
                      for (final m in const [15, 30, 60])
                        PopupMenuItem(
                          value: m,
                          child: Text(
                            trn('library.sleep_minutes', args: [_n(m)]),
                          ),
                        ),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            aloud.sleepEndOfPage || sleepLeft != null
                                ? Icons.bedtime_rounded
                                : Icons.bedtime_outlined,
                            color: aloud.sleepEndOfPage || sleepLeft != null
                                ? AppColors.gold
                                : ink,
                          ),
                          if (sleepLeft != null) ...[
                            const SizedBox(width: 2),
                            Text(
                              _n(sleepLeft + 1),
                              style: TextStyle(color: ink, fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  btn(Icons.stop_rounded, 'library.text_listen_stop'.tr(),
                      aloud.stop),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// A paragraph's text with the sentence being read lit, for the reader's
/// body paragraphs. [hl] is in the stored (vowelled) text; with the tashkeel
/// hidden the range is moved onto the stripped text, which only drops
/// marks. The tint is made OPAQUE over [paper] (TRAPS 15: a translucent
/// highlight over the dark ground composited dark).
InlineSpan readAloudSpan({
  required String raw,
  required bool tashkeel,
  required ReadChunk? hl,
  required Color paper,
}) {
  final shown = tashkeel ? raw : stripTashkeelForDisplay(raw);
  if (hl == null) return TextSpan(text: shown);
  int at(int i) => tashkeel
      ? i
      : stripTashkeelForDisplay(raw.substring(0, i.clamp(0, raw.length))).length;
  final s = at(hl.start).clamp(0, shown.length);
  final e = at(hl.end).clamp(s, shown.length);
  final mark = Color.alphaBlend(
    AppColors.gold.withValues(alpha: 0.30),
    paper,
  );
  return TextSpan(
    children: [
      TextSpan(text: shown.substring(0, s)),
      TextSpan(
        text: shown.substring(s, e),
        style: TextStyle(backgroundColor: mark),
      ),
      TextSpan(text: shown.substring(e)),
    ],
  );
}
