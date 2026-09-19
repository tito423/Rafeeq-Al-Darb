/// «مناسك الحج والعمرة».
///
/// «اشرح فيهم كل شي من مصادر موثوقة وبشكل تفاعلي واحترافي وروعه بصريا». The
/// explanation is the source's own text, read verbatim from Ibn Baz's manual
/// by the ranges in `hajj_guide.dart` — the app writes none of the fiqh. What
/// the app adds is the path through it (Hajj or Umrah, day by day) and the
/// interactive pieces beside the steps they illustrate: the route between the
/// holy sites, the seven circuits of tawaf, the seven passes of sa'i and the
/// pebbles at the jamarat.
library;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/digits.dart';
import '../../../core/widgets/arabic_text.dart';
import '../../library/data/book_text.dart';
import '../../library/data/library_api_service.dart';
import '../data/hajj_guide.dart';
import 'widgets/jamarat_counter.dart';
import 'widgets/journey_map.dart';
import 'widgets/sai_counter.dart';
import 'widgets/tawaf_counter.dart';

/// The manual's text, downloaded once like any Library book and read from
/// disk after that. A failure is logged, not only shown.
final hajjBookProvider = FutureProvider<BookText?>((ref) async {
  try {
    final api = LibraryApiService.instance;
    if (!await api.isBookDownloaded(hajjGuideBook)) {
      await api.downloadBook(
        hajjGuideBook,
        '${AppConfig.contentBaseUrl}/books/text/$hajjGuideBook.json',
      );
    }
    return BookText.fromFile(await api.bookFilePath(hajjGuideBook));
  } catch (e, st) {
    debugPrint('hajjBookProvider failed: $e\n$st');
    rethrow;
  }
});

final _trackProvider = StateProvider<HajjTrack>((ref) => HajjTrack.hajj);

class HajjScreen extends ConsumerWidget {
  const HajjScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.watch(hajjBookProvider);
    final track = ref.watch(_trackProvider);
    final steps = hajjStepsFor(track);

    return Scaffold(
      appBar: AppBar(title: Text('hajj.title'.tr())),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
        itemCount: steps.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return _Header(
              track: track,
              onTrack: (t) => ref.read(_trackProvider.notifier).state = t,
            );
          }
          final step = steps[i - 1];
          return _Entrance(
            key: ValueKey('${track.name}-${step.key}'),
            index: i,
            child: _StepCard(
              number: i,
              step: step,
              book: book,
              onRetry: () => ref.invalidate(hajjBookProvider),
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final HajjTrack track;
  final ValueChanged<HajjTrack> onTrack;

  const _Header({required this.track, required this.onTrack});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            AppColors.gold.withValues(alpha: 0.18),
            scheme.surfaceContainerHighest,
          ],
        ),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<HajjTrack>(
              segments: [
                ButtonSegment(
                  value: HajjTrack.hajj,
                  icon: const Icon(Icons.mosque_rounded),
                  label: Text('hajj.track_hajj'.tr()),
                ),
                ButtonSegment(
                  value: HajjTrack.umrah,
                  icon: const Icon(Icons.brightness_7_rounded),
                  label: Text('hajj.track_umrah'.tr()),
                ),
              ],
              selected: {track},
              onSelectionChanged: (s) => onTrack(s.first),
            ),
          ),
          const SizedBox(height: 8),
          // The route loops for Hajj; Umrah stays in Makkah, so it is not
          // drawn for it rather than drawn wrong.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: track == HajjTrack.hajj
                ? const JourneyMap(key: ValueKey('map'))
                : const SizedBox(
                    key: ValueKey('umrah'),
                    height: 260,
                    child: TawafCounter(),
                  ),
          ),
          Text(
            'hajj.source'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Each step card rises into place a little after the one above it.
class _Entrance extends StatelessWidget {
  final int index;
  final Widget child;

  const _Entrance({super.key, required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + (index.clamp(0, 8)) * 60),
      curve: Curves.easeOutCubic,
      builder: (context, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 24), child: c),
      ),
      child: child,
    );
  }
}

class _StepCard extends StatelessWidget {
  final int number;
  final HajjStep step;
  final AsyncValue<BookText?> book;
  final VoidCallback onRetry;

  const _StepCard({
    required this.number,
    required this.step,
    required this.book,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppColors.gold.withValues(alpha: 0.25)),
      ),
      child: ExpansionTile(
        shape: const Border(),
        leading: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppColors.gold, Color(0xFFB8860B)],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.35),
                blurRadius: 8,
              ),
            ],
          ),
          child: Text(
            // The app's own digits for its language, as everywhere else —
            // the first build on the owner's phone showed «1 2 3» in Arabic.
            localizeDigits('$number', context.locale.languageCode),
            style: const TextStyle(
                color: Colors.black, fontWeight: FontWeight.w800),
          ),
        ),
        title: Text('hajj.step_${step.key}'.tr(),
            style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: step.dayKey == null
            ? null
            : Text(step.dayKey!.tr(),
                style: const TextStyle(color: AppColors.gold, fontSize: 12)),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        children: [
          if (_rite(step) case final rite?) ...[
            rite,
            const Divider(height: 22),
          ],
          book.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(18),
              child: CircularProgressIndicator(),
            ),
            error: (_, _) => Column(
              children: [
                Text('hajj.needs_download'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant)),
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text('common.retry'.tr()),
                ),
              ],
            ),
            data: (text) => _StepText(step: step, book: text),
          ),
        ],
      ),
    );
  }

  static Widget? _rite(HajjStep s) => switch (s.rite) {
        HajjRite.tawaf => const TawafCounter(),
        HajjRite.sai => const SaiCounter(),
        HajjRite.jamarat => JamaratCounter(nahr: s.key == 'nahr'),
        HajjRite.journey => JourneyMap(highlight: _placeOf(s.key)),
        HajjRite.none => null,
      };

  /// Where on the route a day's step happens.
  static int? _placeOf(String key) => switch (key) {
        'tarwiyah' => 1,
        'arafah' => 2,
        'muzdalifah' => 3,
        'mawaqit' => 0,
        _ => null,
      };
}

/// The step's span of the manual, verbatim, inclusive at both ends.
class _StepText extends StatelessWidget {
  final HajjStep step;
  final BookText? book;

  const _StepText({required this.step, required this.book});

  @override
  Widget build(BuildContext context) {
    // «مش ينفع تعرض ... واللغه المختارة انجليزي».
    //
    // The chapter is al-Nawawi's Arabic, and translating a 522-page manual is
    // not this feature's job. A reader on another language gets the step said
    // plainly in his own — what the chapter is about, carrying no ruling —
    // beside the illustration, and is told where the full text lives. The
    // Arabic reader gets the book itself, unchanged.
    if (context.locale.languageCode != 'ar') {
      final scheme = Theme.of(context).colorScheme;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'hajj.desc_${step.key}'.tr(),
            style: const TextStyle(height: 1.9),
          ),
          const SizedBox(height: 10),
          Text(
            'hajj.arabic_only'.tr(),
            style: TextStyle(
              fontSize: 11.5,
              height: 1.7,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'p. ${step.fromPage}–${step.toPage}',
            textDirection: TextDirection.ltr,
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ],
      );
    }

    final paras = <BookPara>[];
    for (final p in book?.pages ?? const <BookPage>[]) {
      if (p.printedPage < step.fromPage || p.printedPage > step.toPage) {
        continue;
      }
      final first = p.printedPage == step.fromPage ? step.fromPara : 0;
      final last =
          p.printedPage == step.toPage ? step.toPara : p.paras.length - 1;
      for (var i = first; i <= last && i < p.paras.length; i++) {
        if (p.paras[i].text.trim().isEmpty) continue;
        // الإفصاح's notes, not al-Nawawi's text — thirty per cent of this
        // printing's body paragraphs, and a modern commentator's words.
        if (isHajjGuideNote(p.paras[i].text)) continue;
        paras.add(p.paras[i]);
      }
    }
    if (paras.isEmpty) {
      return Text('hajj.needs_download'.tr());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final para in paras)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: switch (para.kind) {
              'aya' => Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ArabicText(
                    para.text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontFamily: 'AmiriQuran', fontSize: 18, height: 2),
                  ),
                ),
              'head' => ArabicText(para.text,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: AppColors.gold)),
              _ => ArabicText(para.text, style: const TextStyle(height: 1.9)),
            },
          ),
        Text(
          'p. ${step.fromPage}–${step.toPage}',
          textDirection: TextDirection.ltr,
          style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
