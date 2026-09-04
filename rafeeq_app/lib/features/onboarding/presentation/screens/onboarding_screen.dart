import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/rafeeq_app.dart' show sharedPrefsProvider;
import '../../../../app/shell/app_shell.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/error_retry.dart';
import '../../../downloads/data/reciters_provider.dart';
import '../../../downloads/presentation/widgets/full_recitation_card.dart';
import '../../../downloads/presentation/widgets/mushaf_download_tile.dart';
import '../../../quran/data/mushaf_data_provider.dart';
import '../../../quran/data/mushaf_edition.dart';
import '../../data/onboarding_state.dart';

/// Every locale the app ships, labelled in its own script — same map
/// `settings_screen.dart` uses, duplicated rather than imported across
/// features to keep onboarding self-contained (this project's existing
/// convention, see `mushaf_download_tile.dart`'s own `formatBytes` doc).
const _onboardingLanguageNames = <String, String>{
  'ar': 'العربية',
  'en': 'English',
  'es': 'Español',
  'ru': 'Русский',
  'pt': 'Português',
  'fr': 'Français',
};

/// P3‑21: first-run onboarding — structured like the reference video's own
/// mushaf-choice screen (a heading, a description, a prominent download
/// action, a closing "ابدأ رحلتك الإيمانية 🚀" CTA) but scoped to this
/// project's real **5** editions, each labelled only by its riwayah, no
/// fabricated cover art. The video's own edition-choice screen additionally
/// showed a "تصفح أغلفة ومعاينات الـ 17 مصحفاً" catalog with real scanned
/// cover thumbnails — strong evidence of QuranFlash-derived assets (see the
/// warning in PHASE3.md right above P3‑20) — that catalog is deliberately
/// **not** rebuilt here.
///
/// Covers both G4 ("pick + download a mushaf edition, immediately") and G5
/// ("first install: pick + download an image mushaf edition and a
/// recitation, both essential") from the original feedback: the mushaf list
/// reuses the exact same real per-edition download job
/// (`MushafDownloadTile`/`MushafPageService`) the Downloads screen already
/// uses, and the recitation section reuses the exact same bulk-recitation
/// download (`FullRecitationCard`/`AyahAudioService`) P3‑27 already built —
/// nothing here is a second, decorative copy. Downloading is offered, not
/// forced: both are real background jobs the user can also start later from
/// Downloads, so the closing CTA never blocks on them finishing.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  Future<void> _finish(BuildContext context, WidgetRef ref) async {
    final prefs = ref.read(sharedPrefsProvider);
    await markOnboardingCompleted(prefs);
    if (!context.mounted) return;
    // Read the locale code *before* navigating, not inside `builder:` — a
    // real crash caught live: `pushReplacement` starts deactivating this
    // screen's element, and by the time the new route's `builder` callback
    // actually runs, `context` here can already be a defunct ancestor, so
    // `context.locale` (which walks up an `InheritedWidget`) throws
    // "Looking up a deactivated widget's ancestor is unsafe."
    final localeCode = context.locale.languageCode;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => AppShell(key: ValueKey(localeCode)),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editions = ref.watch(mushafEditionsProvider);
    final selectedEdition = ref.watch(selectedMushafEditionProvider);

    return Scaffold(
      backgroundColor: AppColors.night,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.menu_book_rounded,
                        color: AppColors.gold,
                        size: 26,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'onboarding.title'.tr(),
                          style: const TextStyle(
                            fontFamily: 'AmiriQuran',
                            fontSize: 24,
                            color: AppColors.textHigh,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'onboarding.subtitle'.tr(),
                    style: const TextStyle(
                      color: AppColors.textMedium,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                children: [
                  // P3‑41: an explicit, visible language choice on the
                  // very first run — real-device feedback asked for this
                  // directly. Doesn't replace the existing device-locale
                  // auto-detect (`main.dart`'s own P3‑37 fix already
                  // defaults to Arabic whenever the device's own language
                  // isn't one of the six shipped) — this just makes that
                  // choice visible and overridable instead of silent.
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.language, color: AppColors.gold, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'settings.language'.tr(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textHigh,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final e in _onboardingLanguageNames.entries)
                              ChoiceChip(
                                label: Text(e.value),
                                selected: context.locale.languageCode == e.key,
                                onSelected: (_) {
                                  if (context.locale.languageCode != e.key) {
                                    context.setLocale(Locale(e.key));
                                  }
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  editions.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, _) => ErrorRetry(
                      onRetry: () => ref.invalidate(mushafEditionsProvider),
                    ),
                    data: (list) => Column(
                      children: [
                        for (final e in list) ...[
                          _SelectableEdition(
                            edition: e,
                            selected: e.id == selectedEdition,
                            onSelect: () => ref
                                .read(selectedMushafEditionProvider.notifier)
                                .select(e.id),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Icon(
                        Icons.graphic_eq,
                        color: AppColors.gold,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'onboarding.recitation_title'.tr(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textHigh,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'onboarding.recitation_subtitle'.tr(),
                    style: const TextStyle(
                      color: AppColors.textMedium,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const _RecitationPicker(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.night,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => _finish(context, ref),
                  child: Text(
                    'onboarding.cta'.tr(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One edition row: tapping the card (outside the download controls
/// themselves) makes it the active reading edition — a lightweight radio
/// selection wrapped *around* the real [MushafDownloadTile], not a second
/// picker duplicating its content.
class _SelectableEdition extends StatelessWidget {
  final MushafEdition edition;
  final bool selected;
  final VoidCallback onSelect;
  const _SelectableEdition({
    required this.edition,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onSelect,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.gold
                : AppColors.gold.withValues(alpha: 0.0),
            width: 1.4,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 14, 0, 0),
              child: Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppColors.gold : AppColors.textLow,
                size: 20,
              ),
            ),
            Expanded(child: MushafDownloadTile(edition: edition)),
          ],
        ),
      ),
    );
  }
}

/// The G5 "essential recitation download" — reciter dropdown + the same
/// real bulk-download card the Downloads screen's Recitations tab uses.
class _RecitationPicker extends ConsumerWidget {
  const _RecitationPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reciters = ref.watch(recitersProvider);
    final selected = ref.watch(selectedReciterProvider);
    final mushaf = ref.watch(mushafDataProvider);

    return reciters.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) =>
          ErrorRetry(onRetry: () => ref.invalidate(recitersProvider)),
      data: (list) => Column(
        children: [
          InputDecorator(
            decoration: InputDecoration(
              labelText: 'downloads.choose_reciter'.tr(),
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: list.any((r) => r.identifier == selected)
                    ? selected
                    : list.first.identifier,
                items: [
                  for (final r in list)
                    DropdownMenuItem(
                      value: r.identifier,
                      child: Text(
                        r.nameAr.isEmpty ? r.nameEn : r.nameAr,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) {
                    ref.read(selectedReciterProvider.notifier).select(v);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          mushaf.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) =>
                ErrorRetry(onRetry: () => ref.invalidate(mushafDataProvider)),
            data: (data) => FullRecitationCard(
              key: ValueKey('onboarding/$selected'),
              edition: selected,
              data: data,
              onFinished: () {},
            ),
          ),
        ],
      ),
    );
  }
}
