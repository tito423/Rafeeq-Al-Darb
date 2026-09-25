import '../../../more/presentation/widgets/sign_in_offer.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/rafeeq_app.dart' show sharedPrefsProvider;
import '../../../../app/shell/app_shell.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/error_retry.dart';
import '../../../downloads/presentation/widgets/mushaf_download_tile.dart'
    show MushafDownloadTile;
import '../../../quran/data/mushaf_edition.dart';
import '../../data/onboarding_state.dart';
import '../../../home/data/prayer_controller.dart' show prayerControllerProvider;
import '../../../../core/config/app_config.dart';
import '../../../../core/db/sciences_repository.dart';
import '../../../../core/services/download_manager.dart';
import '../../../../core/utils/byte_formatter.dart' show formatBytes;
import '../../../../core/utils/digits.dart' show trn;
import '../../../hifz/data/tasmee_engine.dart' show tasmeeDownloadBytes;
import '../../../library/data/tts/open_voice.dart';
import '../../data/offline_pack_sizes.dart';
import '../widgets/content_pack_tile.dart';
import '../widgets/offline_pack_tiles.dart';


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
/// uses, nothing here is a second, decorative copy. (The recitation download that
/// used to sit below it went with the per-ayah downloads in 3.17.0; whole
/// recitations are downloaded from «تحميل تلاوات القرآن».) Downloading is offered, not
/// forced: both are real background jobs the user can also start later from
/// Downloads, so the closing CTA never blocks on them finishing.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key, this.revisit = false});

  /// Opened again from Downloads («حطها خيار في التنزيلات ممكن ارجعلها
  /// بعدين», 2026-09-25): the same rows, but the button just closes the
  /// page - onboarding is not run a second time.
  final bool revisit;

  Future<void> _finish(BuildContext context, WidgetRef ref) async {
    final prefs = ref.read(sharedPrefsProvider);
    await markOnboardingCompleted(prefs);
    // «لما فتحت التطبيق علق على الموقع مش شغال … مع انه واخد اذن الموقع في
    // الاول» (2026-09-24). The prayer card first loads while the splash is
    // still up - BEFORE the permissions page - so on a first run it asked,
    // was denied (no permission yet, and LocationService does not prompt
    // before onboarding), and kept «فعّل الموقع» on the Home screen after the
    // reader had granted it, until a pull-to-refresh. Reproduced on
    // emulator-5554 (fresh install, location allowed on the permissions page,
    // `granted=true` in dumpsys, card still asking). Onboarding is where the
    // answer changes, so the card starts again from here.
    ref.invalidate(prayerControllerProvider);
    if (!context.mounted) return;
    // Once per install: the sign-in offer (see `offerSignInOnce`).
    await offerSignInOnce(context, ref);
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
    final scheme = Theme.of(context).colorScheme;
    final sizes = ref.watch(offlinePackSizesProvider).valueOrNull;
    final ayahChoice = ref.watch(onboardingAyahChoiceProvider);
    final surahChoice = ref.watch(onboardingSurahChoiceProvider);
    final ayahBytes = sizes?.ayahReciters[ayahChoice];
    final surahBytes = sizes?.surahRecitations[surahChoice];
    final total = sizes == null || ayahBytes == null || surahBytes == null
        ? null
        : sizes.mushaf +
            AppConfig.sciencesDbBytes +
            ayahBytes +
            surahBytes +
            tasmeeDownloadBytes +
            OpenVoice.totalBytes;

    // THE APP'S OWN THEME, not a hard-coded night. This screen used to set
    // `AppColors.night` and night text colours outright, so on a fresh
    // install - which opens on the DAY theme (`ThemeController.
    // defaultVariant`) - the page right after the permissions screen was the
    // one dark page in a light app: «اختر مصحفك تظهر داكنة على تثبيت
    // جديد». The theme is chosen on the page before this one now, and this
    // page wears whatever was chosen.
    return Scaffold(
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
                      Icon(
                        Icons.download_for_offline_rounded,
                        color: goldText(context),
                        size: 26,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'onboarding.title'.tr(),
                          style: TextStyle(
                            fontFamily: 'AmiriQuran',
                            fontSize: 24,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'onboarding.subtitle'.tr(),
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
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
                  // THE LANGUAGE IS NOT HERE ANY MORE.
                  //
                  // It moved to `PermissionsIntroScreen`, the page BEFORE
                  // this one, because that page was asking for five
                  // permissions in whatever language the phone happened to
                  // be set to. Leaving a copy here put the same chooser on
                  // two screens in a row - «اللغة اتكررت في شاشة الاذونات
                  // وشاشة تحميل المصحف».
                  const SizedBox(height: 18),
                  if (sizes != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        trn('onboarding.mushaf_size',
                            args: [formatBytes(sizes.mushaf)]),
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ),
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
                  const SizedBox(height: 6),
                  // EVERYTHING ELSE THAT CAN BE DOWNLOADED, HERE.
                  //
                  // «والاوبشنز اللي ممكن يحملها المستخدم في نفس الصفحة بدل
                  // مايتفاجأ بيها جوه مش موجودة زي التفاسير مثلا». علوم
                  // القرآن left the APK in 3.45.0 and the only place that
                  // said so was a prompt inside an ayah card, weeks later.
                  ContentPackTile(
                    icon: Icons.auto_stories_outlined,
                    titleKey: 'quran.sciences_pack',
                    hintKey: 'quran.sciences_pack_hint',
                    bytes: AppConfig.sciencesDbBytes,
                    downloadId: sciencesDbDownloadId,
                    installed: ref.watch(sciencesRepositoryProvider).valueOrNull
                        != null,
                    onDownload: () => DownloadManager.instance.enqueue(
                      id: sciencesDbDownloadId,
                      url: AppConfig.sciencesDbUrl,
                      category: 'sciences',
                      fileName: 'quran_sciences.zip',
                      unzipToDatabases: true,
                      dbVersion: AppConfig.sciencesDbVersion,
                      title: 'quran.sciences_pack'.tr(),
                    ),
                  ),
                  const AyahReciterPackTile(),
                  const SurahRecitationPackTile(),
                  const TasmeePackTile(),
                  const VoicePackTile(),
                ],
              ),
            ),
            // «المساحة المطلوبة للتجربة الكاملة», summed from the measured
            // sizes of exactly the packs listed above, with the reciters the
            // reader has chosen - never a number typed here.
            if (total != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Text(
                  trn('onboarding.total', args: [formatBytes(total)]),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, revisit ? 20 : 4),
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
                  onPressed: revisit
                      ? () => Navigator.of(context).maybePop()
                      : () => _finish(context, ref),
                  child: Text(
                    revisit ? 'onboarding.done'.tr() : 'onboarding.cta'.tr(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
            // «ابقى حط لاحقا في شاشة التحميلات المبدئية» (2026-09-25):
            // leaving without downloading anything, said in so many words.
            // Every row stays reachable from Downloads → Initial downloads.
            if (!revisit)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextButton(
                  onPressed: () => _finish(context, ref),
                  child: Text('onboarding.later'.tr()),
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
                color: selected
                    ? AppColors.gold
                    : Theme.of(context).colorScheme.outline,
                size: 20,
              ),
            ),
            // No forced dark theme around the tile any more. It was there
            // because this screen was always night-dark while the tile took
            // its ink from the app theme; now the screen follows the theme
            // too, so the tile's own colours are the right ones.
            Expanded(child: MushafDownloadTile(edition: edition)),
          ],
        ),
      ),
    );
  }
}
