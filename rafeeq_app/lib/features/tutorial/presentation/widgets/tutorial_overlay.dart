/// The guided tour, played **on the app itself**.
///
/// «المقصود كل شاشة تتشرح في مكانها … زي فيديو يشرح كل شاشة مدته ٣ ثواني أو
/// أربعة». The previous tour was a separate full-screen route with a painted
/// medallion above a paragraph — it described the app while hiding it. This
/// one does not: it lives inside `AppShell`'s body, switches the real tab
/// underneath for every chapter, and narrates the screen the reader is
/// actually looking at.
///
/// It plays: each chapter holds for four seconds, a hairline fills across the
/// card as it goes, and the tour moves on by itself. Tapping the screen pauses
/// it (a reader who wants to look at what is being described should be allowed
/// to), tapping again resumes, and «التالي»/«السابق» step it by hand.
///
/// The language row is on the first chapter because that is the moment it is
/// useful — the owner asked for «اختيار لغة التطبيق تظهر على هيئة خيار فيه»,
/// and a reader who cannot read the tour cannot be told where the language
/// setting is.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/shell/tab_request_provider.dart';
import '../../../../core/i18n/supported_locales.dart';
import '../../../../core/utils/digits.dart';
import '../../data/tutorial_chapters.dart';
import '../../data/tutorial_state.dart';


/// How long a chapter holds before the tour moves on by itself.
const _hold = Duration(seconds: 4);

class TutorialOverlay extends ConsumerStatefulWidget {
  /// Switches the shell's visible tab. The overlay drives the app rather than
  /// drawing a picture of it, so it needs the shell's own navigation.
  final void Function(int tab) onGoToTab;

  const TutorialOverlay({super.key, required this.onGoToTab});

  @override
  ConsumerState<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends ConsumerState<TutorialOverlay>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  bool _paused = false;
  bool _closing = false;

  /// Drives both the hold timer and the hairline that shows it running, so
  /// the bar can never disagree with when the tour will actually advance.
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: _hold,
  )..addStatusListener((s) {
      if (s == AnimationStatus.completed) _next();
    });

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _enter(0));
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  /// Show chapter [i]: open its tab, then start its clock.
  void _enter(int i) {
    widget.onGoToTab(tutorialChapters[i].tab);
    _progress
      ..reset()
      ..forward();
  }

  void _next() {
    if (_index >= tutorialChapters.length - 1) {
      _finish();
      return;
    }
    setState(() => _index++);
    _enter(_index);
  }

  void _prev() {
    if (_index == 0) return;
    setState(() => _index--);
    _enter(_index);
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    if (_paused) {
      _progress.stop();
    } else {
      _progress.forward();
    }
  }

  /// The single exit. Every way out lands here — finishing, «تخطّي», and the
  /// back gesture that `AppShell` routes in — so "seen" is recorded however
  /// the reader leaves, and the guard stops the three paths racing.
  void _finish() {
    if (_closing) return;
    _closing = true;
    _progress.stop();
    endTutorial(ref);
    widget.onGoToTab(AppTab.home);
  }

  @override
  Widget build(BuildContext context) {
    final chapter = tutorialChapters[_index];
    final locale = context.locale.languageCode;
    final theme = Theme.of(context);

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _togglePause,
        child: DecoratedBox(
          // Transparent over the top two thirds so the screen being explained
          // is genuinely visible; opaque enough under the card that the text
          // stays legible over any of the four themes.
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.10),
                Colors.black.withValues(alpha: 0.30),
                Colors.black.withValues(alpha: 0.82),
              ],
              stops: const [0, 0.45, 1],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _TopRow(
                  index: _index,
                  total: tutorialChapters.length,
                  locale: locale,
                  paused: _paused,
                  onSkip: _finish,
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  child: _ChapterCard(
                    chapter: chapter,
                    progress: _progress,
                    paused: _paused,
                    isFirst: _index == 0,
                    isLast: _index == tutorialChapters.length - 1,
                    onPrev: _index == 0 ? null : _prev,
                    onNext: _next,
                    theme: theme,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopRow extends StatelessWidget {
  final int index;
  final int total;
  final String locale;
  final bool paused;
  final VoidCallback onSkip;

  const _TopRow({
    required this.index,
    required this.total,
    required this.locale,
    required this.paused,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: Row(
        children: [
          _Pill(
            child: Text(
              '${localizeDigits('${index + 1}', locale)}'
              ' / ${localizeDigits('$total', locale)}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (paused) ...[
            const SizedBox(width: 8),
            _Pill(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.pause_rounded,
                      size: 16, color: Colors.white70),
                  const SizedBox(width: 6),
                  Text(
                    'tutorial.paused'.tr(),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
          const Spacer(),
          TextButton(
            onPressed: onSkip,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: Text('tutorial.skip'.tr()),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final Widget child;
  const _Pill({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(20),
        ),
        child: child,
      );
}

class _ChapterCard extends ConsumerWidget {
  final TutorialChapter chapter;
  final Animation<double> progress;
  final bool paused;
  final bool isFirst;
  final bool isLast;
  final VoidCallback? onPrev;
  final VoidCallback onNext;
  final ThemeData theme;

  const _ChapterCard({
    required this.chapter,
    required this.progress,
    required this.paused,
    required this.isFirst,
    required this.isLast,
    required this.onPrev,
    required this.onNext,
    required this.theme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      elevation: 8,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The clock, made visible. It is driven by the very controller that
          // decides when to advance, so it cannot lie about the timing.
          AnimatedBuilder(
            animation: progress,
            builder: (_, _) => LinearProgressIndicator(
              value: progress.value,
              minHeight: 3,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(chapter.accent),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: chapter.accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(chapter.icon,
                          color: chapter.accent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'tutorial.${chapter.key}_title'.tr(),
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'tutorial.${chapter.key}_body'.tr(),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(height: 1.55, color: scheme.onSurfaceVariant),
                ),
                if (isFirst) ...[
                  const SizedBox(height: 14),
                  const _LanguageRow(),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (onPrev != null)
                      TextButton.icon(
                        onPressed: onPrev,
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: Text('tutorial.back'.tr()),
                      ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: onNext,
                      style: FilledButton.styleFrom(
                        backgroundColor: chapter.accent,
                        foregroundColor: Colors.black,
                      ),
                      icon: Icon(
                        isLast
                            ? Icons.check_rounded
                            : Icons.arrow_forward_rounded,
                        size: 18,
                      ),
                      label: Text(
                        isLast ? 'tutorial.done'.tr() : 'tutorial.next'.tr(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The language picker, offered where a reader who cannot read the tour will
/// actually meet it. Changing it here changes the app — the same
/// `context.setLocale` every other language control in the app calls — so the
/// rest of the tour continues in the language just chosen.
class _LanguageRow extends StatelessWidget {
  const _LanguageRow();

  @override
  Widget build(BuildContext context) {
    final current = context.locale.languageCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'tutorial.language'.tr(),
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final e in kLanguageNames.entries)
              ChoiceChip(
                label: Text(e.value),
                selected: e.key == current,
                onSelected: (_) {
                  if (e.key != current) context.setLocale(Locale(e.key));
                },
              ),
          ],
        ),
      ],
    );
  }
}
