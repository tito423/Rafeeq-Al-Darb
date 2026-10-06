import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/db/azkar_repository.dart';
import '../../../../core/db/models.dart';
import '../../../../core/services/audio_exclusive.dart';
import '../../../../core/services/ayah_audio_service.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/byte_formatter.dart' show ratio;
import '../../../../core/utils/digits.dart';
import '../../../../core/utils/screen_class.dart';
import '../../../../core/widgets/arabic_text.dart';
import '../../../../core/widgets/remote_tap.dart';
import '../../../dorar/presentation/dorar_check_sheet.dart';
import '../../../kids/data/journey_store.dart';
import '../../../library/presentation/widgets/listen_text_button.dart';
import '../../../quotes/data/quote_background_catalog.dart';
import '../../data/azkar_audio.dart';

/// One section's adhkar, one full-screen card at a time (P3‑54 redesign).
///
/// Each dhikr is its own page in a horizontal [PageView] — the user swipes
/// right/left (honouring the app's reading direction automatically, since a
/// horizontal `PageView` follows the ambient `Directionality`) to move between
/// adhkar. The card is a layered `Stack`: an Islamic gradient ground with the
/// app's own ornamental mark as a faint watermark, a dark overlay for
/// legibility, and the white [AmiriQuran] dhikr text on top. A large,
/// tappable **countdown** shows the repeats left for the current dhikr; when
/// it reaches zero the reader auto-advances to the next card. A page indicator
/// at the bottom shows which card of the section is showing.
///
/// The counter still works exactly as before (P3‑11): each dhikr's real repeat
/// count is parsed from its own text (`azkar_repeat.dart`), counted on the
/// very first tap, per-card counts are remembered when swiping back and forth,
/// and a trailing "section done" card closes the flow.
///
/// The background is deliberately a themed gradient + first-party watermark
/// rather than a stock photo: the app ships no real Islamic background image,
/// and the project's zero-placeholder rule forbids inventing/bundling an
/// unverified one. Swapping in a real image later is a single `Image.asset`
/// change in [_CardBackground].
class AzkarSectionScreen extends ConsumerStatefulWidget {
  final AzkarSection section;

  /// Accent colour for the countdown ring and the active page dot — passed by
  /// the hub so a card opened from, say, the "أذكار المساء" group carries that
  /// group's colour through. Falls back to the app gold when not supplied.
  final Color? accent;

  const AzkarSectionScreen({super.key, required this.section, this.accent});

  @override
  ConsumerState<AzkarSectionScreen> createState() => _AzkarSectionScreenState();
}

class _AzkarSectionScreenState extends ConsumerState<AzkarSectionScreen> {
  final PageController _pageController = PageController();
  List<AzkarItem>? _items;
  int _index = 0;

  /// Per-card tap count, keyed by card index so swiping back and forth keeps
  /// each dhikr's own progress rather than resetting it.
  final Map<int, int> _counts = {};

  @override
  void initState() {
    super.initState();
    ref.read(azkarRepositoryProvider.future).then((repo) async {
      final items = await repo.items(widget.section.id);
      if (mounted) setState(() => _items = items);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    // A dhikr's recording does not outlive its screen.
    if (_listeningTo != null &&
        AyahAudioService.instance.isTrack('dhikr:$_listeningTo')) {
      AyahAudioService.instance.stop();
    }
    super.dispose();
  }

  /// The dhikr whose recording was last started here.
  int? _listeningTo;

  /// Plays the current dhikr's hisnmuslim.com recording on the app's one
  /// player (so the notification can stop it too), or stops it.
  Future<void> _listen(AzkarItem item, String url) async {
    final audio = AyahAudioService.instance;
    if (audio.isTrack('dhikr:${item.id}') && audio.isPlaying) {
      await audio.stop();
      return;
    }
    await AudioExclusive.silenceSpeakers();
    _listeningTo = item.id;
    final ok = await audio.playTrack(
      id: 'dhikr:${item.id}',
      url: url,
      title: widget.section.localizedTitle(),
      artist: 'hisnmuslim.com',
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('azkar.listen_failed'.tr())));
    }
  }

  Color get _accent => widget.accent ?? AppColors.gold;

  int _targetFor(int i) =>
      _items == null ? 1 : _items![i].repeat;

  void _tapCount() {
    final items = _items;
    if (items == null || _index >= items.length) return;
    final target = _targetFor(_index);
    final current = _counts[_index] ?? 0;
    if (current >= target) return; // already complete — swipe to advance
    setState(() => _counts[_index] = current + 1);
    
    SharedPreferences.getInstance().then((prefs) {
      final total = prefs.getInt('azkar_total') ?? 0;
      prefs.setInt('azkar_total', total + 1);
    });
    ref.read(syncServiceProvider).incrementCounter('azkar_total', 1);
    JourneyStore.instance.record('dhikr');

    // Auto-advance once this dhikr's real repeat count is reached.
    if ((_counts[_index] ?? 0) >= target) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        if (_index < items.length) {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    // Sideways the counter stands beside the dhikr instead of under it.
    // Under it, on the owner's Xiaomi held sideways (2026-09-26), the ring,
    // its line and the dots took ~210 of the ~300 dp below the app bar and
    // left the dhikr a strip two lines high.
    final sideways =
        ScreenClass.wide(context);
    final pages = items == null
        ? null
        : PageView.builder(
            controller: _pageController,
            itemCount: items.length + 1, // +1 → "section done"
            onPageChanged: (i) {
              // Swiping on stops the dhikr that was being listened to.
              if (_listeningTo != null &&
                  AyahAudioService.instance.isTrack('dhikr:$_listeningTo')) {
                AyahAudioService.instance.stop();
              }
              setState(() => _index = i);
            },
            itemBuilder: (context, i) {
              if (i == items.length) {
                return _DonePage(
                  onBack: () => Navigator.of(context).pop(),
                );
              }
              return _DhikrPage(
                item: items[i],
                isFirst: i == 0,
              );
            },
          );
    // Bottom controls belong to the *current* dhikr, so they live outside
    // the PageView and read `_index` — hidden on the trailing "done" card,
    // which has its own layout.
    final controls = items != null && _index < items.length
        ? _BottomControls(
            accent: _accent,
            count: _counts[_index] ?? 0,
            target: _targetFor(_index),
            index: _index,
            total: items.length,
            onTap: _tapCount,
            // ONE listen button (owner, 2026-10-06: two of them, the
            // recording and the app's voice, sat on one dhikr): the human
            // recording where there is one, otherwise the reader's voice -
            // and never that voice on a dhikr that quotes the Qur'an.
            listen: switch (ref.watch(azkarAudioProvider).valueOrNull?[
                items[_index].id]) {
              final String url => _ListenButton(
                  id: items[_index].id,
                  accent: _accent,
                  onTap: () => _listen(items[_index], url),
                ),
              _ => ListenTextButton(
                  key: ValueKey(items[_index].id),
                  text: () => items[_index].body,
                  quranHides: true,
                  alignment: Alignment.center,
                ),
            },
          )
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.section.localizedTitle()),
        elevation: 0,
      ),
      body: items == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                const Positioned.fill(child: _CardBackground()),
                if (sideways)
                  Row(
                    children: [
                      Expanded(child: pages!),
                      if (controls != null)
                        SizedBox(
                          width: 250,
                          child: SafeArea(
                            child: Center(
                              child: SingleChildScrollView(child: controls),
                            ),
                          ),
                        ),
                    ],
                  )
                else
                  Column(
                    children: [
                      Expanded(child: pages!),
                      ?controls,
                    ],
                  ),
              ],
            ),
    );
  }
}

/// The layered Islamic ground behind every card: one mosque photograph
/// (since 2026-10-03; it was one of the quote cards' ornament scans per
/// card), the quote cards' scrim those images were contrast-measured through, and a
/// deeper scrim toward the bottom for the controls.
///
/// **2026-09-29:** the ground used to be a plain green gradient with the app's
/// own mark faintly in the middle, which read as the old app icon on every
/// card (owner: «خلفيات للأذكار بصورة أيقونة التطبيق القديمة … غيرها لصور
/// إسلامية حلوة»). The picture changes with the card, so a chapter of several
/// adhkar is not one static wall.
class _CardBackground extends ConsumerWidget {
  const _CardBackground();

  /// One calm mosque photograph behind every adhkar card (owner, 2026-10-03:
  /// «خليه خلفية واحدة لمسجد تكون هادية … في الأذكار كلها»). Vakil Mosque,
  /// Shiraz, by Zahrazari, CC BY 4.0 -
  /// https://commons.wikimedia.org/wiki/File:Vakil_mosque_interior_in_2022.jpg
  static const asset = 'assets/azkar_background/vakil_mosque.jpg';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final set = ref.watch(quoteBackgroundsProvider).valueOrNull;
    final scrim = Color(set?.scrimArgb ?? 0xCC071626);
    const Widget photo = Image(
      image: ResizeImage(AssetImage(asset), width: 1080),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0B3D2E), // deep emerald
            Color(0xFF0E5A43),
            Color(0xFF0A1F19), // near-black green
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          photo,
          ColoredBox(color: scrim),
          // Extra scrim toward the bottom for the controls' legibility.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0x66000000)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One dhikr's full-screen card — just the scrollable text + source, drawn
/// transparently over the shared [_CardBackground].
class _DhikrPage extends StatelessWidget {
  final AzkarItem item;
  final bool isFirst;
  const _DhikrPage({required this.item, required this.isFirst});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ArabicText: the dhikr and its takhrij are Arabic, but this
            // screen inherits the app's Directionality, which is LTR in six
            // of the seven locales — and an Arabic paragraph in an LTR box
            // puts its edge punctuation at the wrong end. On the Portuguese
            // build «Fonte:» sat at the left of the first line instead of
            // leading the citation.
            ArabicText(
              // Qur'an quoted in the book is braced; the ornate brackets are
              // the mushaf's own way of setting a verse apart.
              item.body.replaceAll('{ ', '﴿').replaceAll(' }', '﴾'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'AmiriQuran',
                fontSize: 24,
                height: 2.0,
                color: Colors.white,
              ),
            ),
            if (item.footnote.isNotEmpty) ...[
              const SizedBox(height: 20),
              Divider(color: Colors.white.withValues(alpha: 0.25)),
              const SizedBox(height: 8),
              ArabicText(
                '${'azkar.source'.tr()}: ${item.footnote}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
              // The hadith this dhikr comes from, graded by name on Dorar
              // (GitHub build; owner, 2026-09-26).
              DorarCheckButton(
                text: item.body,
                color: Colors.white,
                alignment: Alignment.center,
              ),
            ],
            if (isFirst) ...[
              const SizedBox(height: 20),
              Text(
                'azkar.swipe_hint'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The fixed bottom bar: a tappable countdown for the current dhikr's repeats
/// plus the section's page indicator.
class _BottomControls extends StatelessWidget {
  final Color accent;
  final int count;
  final int target;
  final int index;
  final int total;
  final VoidCallback onTap;

  /// The listen button, when this dhikr has a recording.
  final Widget? listen;

  const _BottomControls({
    required this.accent,
    required this.count,
    required this.target,
    required this.index,
    required this.total,
    required this.onTap,
    this.listen,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = (target - count).clamp(0, target);
    final done = remaining == 0;
    final progress = target == 0 ? 0.0 : (count / target).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (listen != null) ...[listen!, const SizedBox(height: 10)],
          // Tappable countdown ring — shows repeats *remaining* (counts down),
          // with a check once complete. Tapping anywhere on it counts.
          RemoteTap(
            onTap: onTap,
            child: SizedBox(
              width: 108,
              height: 108,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 108,
                    height: 108,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    ),
                  ),
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: done ? 0.9 : 0.18),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.8),
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: done
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 40)
                        : Text(
                            localizeDigits(
                                '$remaining', context.locale.languageCode),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            target > 1
                ? localizeDigits(
                    '${'azkar.repeat'.tr()}: ${localizeDigits(ratio(count, target), uiLanguageCode)}',
                    context.locale.languageCode)
                : 'azkar.tap_to_count_dhikr'.tr(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          _PageIndicator(index: index, total: total, accent: accent),
        ],
      ),
    );
  }
}

/// «استمع» / «إيقاف» for one dhikr, following the shared player.
class _ListenButton extends StatelessWidget {
  final int id;
  final Color accent;
  final VoidCallback onTap;
  const _ListenButton(
      {required this.id, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) => StreamBuilder<bool>(
        stream: AyahAudioService.instance.isPlayingStream,
        builder: (context, snap) {
          final on = (snap.data ?? false) &&
              AyahAudioService.instance.isTrack('dhikr:$id');
          return FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.14),
              foregroundColor: Colors.white,
              side: BorderSide(color: accent.withValues(alpha: 0.8)),
            ),
            onPressed: onTap,
            icon: Icon(on ? Icons.stop_rounded : Icons.headphones_rounded),
            label: Text(on ? 'azkar.listen_stop'.tr() : 'azkar.listen'.tr()),
          );
        },
      );
}

/// Page indicator: elongated-active dots when the section is short enough to
/// show them all, a compact "n / total" pill otherwise. Always paired with the
/// exact count so the position is unambiguous either way.
class _PageIndicator extends StatelessWidget {
  final int index;
  final int total;
  final Color accent;
  const _PageIndicator({
    required this.index,
    required this.total,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final label = Text(
      localizeDigits(ratio(index + 1, total), uiLanguageCode),
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.7),
        fontSize: 12,
      ),
    );

    if (total > 21) {
      // Too many to show as dots without crowding — the numeric pill alone.
      return label;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < total; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: i == index ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == index
                      ? accent
                      : Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        label,
      ],
    );
  }
}

/// The trailing card, reached by swiping past the last dhikr — the same
/// "أتممت أذكار هذا القسم" completion the reader has always shown, redrawn to
/// sit over the shared dark ground.
class _DonePage extends StatelessWidget {
  final VoidCallback onBack;
  const _DonePage({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 84, color: AppColors.success),
            const SizedBox(height: 16),
            Text(
              'azkar.section_done'.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onBack,
              child: Text('azkar.back_to_sections'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
