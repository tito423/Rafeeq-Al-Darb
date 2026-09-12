import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/hadith_repository.dart';
import '../../../../core/i18n/supported_locales.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/digits.dart';
import '../../../../core/widgets/islamic_pattern.dart';
import '../../../adhan/data/adhan_catalog_provider.dart';
import '../../../adhan/data/prayer_calculation_methods.dart';
import '../../../channels/data/islamic_channels.dart';
import '../../../downloads/data/reciters_provider.dart';
import '../../../library/data/book_catalog.dart';
import '../../../quran/data/mushaf_edition.dart';
import '../../../quran/data/quran_translation_catalog.dart';

/// The "about" page: who built the app, what version this is, and what it can
/// actually do.
///
/// EVERY NUMBER ON THIS PAGE IS COUNTED, NOT TYPED.
///
/// It used to be a hand-written list, and by the time the owner asked for it
/// to be brought up to date every figure on it was wrong: «سبعة مصاحف» when
/// six ship, and named as «الشمرلي، الهندي الملوّن، ورش، قالون» — four
/// printings that are not in `editions.json` at all and two that are missing
/// from the sentence (قطر، الكويت، الطبعة الليلية); «عشرة مؤذّنين» against
/// twelve in `adhans.json`; «أربع طرق حساب» against twenty in
/// `kPrayerCalculationMethods`; «أكثر من أربعين ألف حديث» against 67,153 rows;
/// and a version badge reading 3.1.0 while `pubspec.yaml` said 3.19.0. That is
/// the same failure §1.1 of CLAUDE.md is about — a catalogue of claims — and
/// hand-editing the sentences again would only reset the clock on it.
///
/// So the counts are read from the very catalogues the features are built on:
/// `mushafEditionsProvider`, `quranTranslationCatalogProvider`,
/// `recitersProvider`, `adhanCatalogProvider`, `kPrayerCalculationMethods`,
/// `libraryBookCatalog`, `islamicChannels`, `kSupportedLocales`, and three
/// `COUNT(*)`s against the open `hadith.db`. A row whose catalogue has not
/// loaded yet shows the sentence without its number rather than a guess, and
/// nothing here can go stale without the feature itself changing.
///
/// The version is the one figure that cannot be counted from anything the app
/// carries at runtime, so `test/about_version_test.dart` reads `pubspec.yaml`
/// and fails the build when the two drift.
class AboutScreen extends ConsumerStatefulWidget {
  /// From `pubspec.yaml`'s `version:` — kept equal to it by
  /// `test/about_version_test.dart`.
  static const appVersion = '3.23.0';

  const AboutScreen({super.key});

  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  /// A slow, continuous shimmer across the gold rule under the author's name.
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  @override
  void dispose() {
    _intro.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  /// Each block fades and rises in turn, so the page assembles itself rather
  /// than appearing all at once.
  Widget _staggered({required int index, required Widget child}) {
    final start = (index * 0.12).clamp(0.0, 0.7);
    final curve = CurvedAnimation(
      parent: _intro,
      curve: Interval(start, (start + 0.4).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curve,
      builder: (context, c) => Opacity(
        opacity: curve.value,
        child: Transform.translate(
          offset: Offset(0, 22 * (1 - curve.value)),
          child: c,
        ),
      ),
      child: child,
    );
  }

  /// A count in the reader's own digits, or `null` while its catalogue loads.
  String? _n(int? value) => value == null
      ? null
      : localizeDigits('$value', context.locale.languageCode);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rows = _capabilityRows();

    return Scaffold(
      appBar: AppBar(title: Text('settings.about'.tr())),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _staggered(index: 0, child: _hero(theme, scheme)),
          const SizedBox(height: 22),
          _staggered(index: 1, child: const _DuaCard()),
          const SizedBox(height: 18),
          _staggered(
            index: 2,
            child: _card(
              scheme,
              child: Text(
                'about.blurb'.tr(),
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.8),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _staggered(
            index: 3,
            child: Text(
              'about.capabilities'.tr(),
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: scheme.primary),
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < rows.length; i++) ...[
            _staggered(index: 4 + i, child: rows[i]),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  /// The capability list, each line carrying the count its own catalogue
  /// reports right now.
  List<Widget> _capabilityRows() {
    final editions = ref.watch(mushafEditionsProvider).valueOrNull;
    final translations =
        ref.watch(quranTranslationCatalogProvider).valueOrNull;
    final reciters = ref.watch(recitersProvider).valueOrNull;
    final adhans = ref.watch(adhanCatalogProvider).valueOrNull;

    // The scanned printings, named as their own catalogue names them, so the
    // sentence can never list a printing the app does not carry.
    final raster = editions?.where((e) => e.isRaster).toList();
    final printings = raster
        ?.map((e) => e.namesByLocale[context.locale.languageCode] ?? e.nameAr)
        .join('، ');

    return [
      _FeatureRow(
        icon: Icons.menu_book_rounded,
        title: 'about.f_quran'.tr(args: [_n(editions?.length) ?? '—']),
        subtitle: printings == null
            ? 'about.f_quran_desc_loading'.tr()
            : 'about.f_quran_desc'
                .tr(args: [_n(raster!.length) ?? '—', printings]),
      ),
      _FeatureRow(
        icon: Icons.translate_rounded,
        title: 'about.f_translations'.tr(args: [_n(translations?.length) ?? '—']),
        subtitle: 'about.f_translations_desc'.tr(),
      ),
      _FeatureRow(
        icon: Icons.headphones_rounded,
        title: 'about.f_audio'.tr(),
        subtitle: 'about.f_audio_desc'.tr(
          args: [_n(reciters?.length) ?? '—', _n(adhans?.length) ?? '—'],
        ),
      ),
      _FeatureRow(
        icon: Icons.mosque_rounded,
        title: 'about.f_prayer'.tr(),
        subtitle: 'about.f_prayer_desc'
            .tr(args: [_n(kPrayerCalculationMethods.length)!]),
      ),
      const _HadithFeatureRow(),
      _FeatureRow(
        icon: Icons.spa_rounded,
        title: 'about.f_azkar'.tr(),
        subtitle: 'about.f_azkar_desc'.tr(),
      ),
      _FeatureRow(
        icon: Icons.local_library_rounded,
        title: 'about.f_library'.tr(args: [_n(libraryBookCatalog.length)!]),
        subtitle: 'about.f_library_desc'
            .tr(args: [_n(islamicChannels.length)!]),
      ),
      _FeatureRow(
        icon: Icons.language_rounded,
        title: 'about.f_locales'.tr(args: [_n(kSupportedLocales.length)!]),
        subtitle: 'about.f_locales_desc'.tr(),
      ),
      _FeatureRow(
        icon: Icons.cloud_off_rounded,
        title: 'about.f_offline'.tr(),
        subtitle: 'about.f_offline_desc'.tr(),
      ),
    ];
  }

  Widget _hero(ThemeData theme, ColorScheme scheme) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: theme.brightness == Brightness.dark
                ? [const Color(0xFF0B2A26), const Color(0xFF071625)]
                : [const Color(0xFFE8F5F1), const Color(0xFFF7F3E8)],
          ),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
        ),
        child: Column(
          children: [
            // A gently breathing app mark.
            ScaleTransition(
              scale: Tween<double>(begin: 0.85, end: 1.0).animate(
                CurvedAnimation(parent: _intro, curve: Curves.elasticOut),
              ),
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold.withValues(alpha: 0.12),
                  border:
                      Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                ),
                child: const Icon(Icons.mosque_rounded,
                    size: 42, color: AppColors.gold),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'app.name'.tr(),
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'v${AboutScreen.appVersion}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'about.developed_by'.tr(),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            // The author's name, with a shimmer sweeping across it.
            AnimatedBuilder(
              animation: _shimmer,
              builder: (context, _) {
                final t = _shimmer.value;
                return ShaderMask(
                  shaderCallback: (rect) => LinearGradient(
                    begin: Alignment(-1 + 3 * t, 0),
                    end: Alignment(-0.4 + 3 * t, 0),
                    colors: const [
                      AppColors.gold,
                      Color(0xFFFFF3C4),
                      AppColors.gold,
                    ],
                  ).createShader(rect),
                  child: Text(
                    'Tito Abo Malak',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.6,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 120,
              height: 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    AppColors.gold.withValues(alpha: 0),
                    AppColors.gold,
                    AppColors.gold.withValues(alpha: 0),
                  ]),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _card(ColorScheme scheme, {required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.18)),
        ),
        child: child,
      );
}

/// «في عن التطبيق ضيف في كارت جميل وروعة بصريًا واكتب: عني نسألكم الدعاء لي
/// ولوالدي رحمه الله ولوالدتي بارك الله بعمرها وحفظها ولكم بالمثل إن شاء
/// الله».
///
/// The owner's own words, set the way the app sets a dhikr — AmiriQuran on the
/// patterned navy panel, a pair of gold rules, and a lamp above them — rather
/// than as another paragraph in a settings list. It sits directly under the
/// hero so it is the first thing read on the page.
class _DuaCard extends StatefulWidget {
  const _DuaCard();

  @override
  State<_DuaCard> createState() => _DuaCardState();
}

class _DuaCardState extends State<_DuaCard>
    with SingleTickerProviderStateMixin {
  /// The lamp breathes; nothing else on the card moves. A card that is asking
  /// for du'a should not be the busiest thing on the screen.
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IslamicPatternPanel(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _glow,
            builder: (context, child) => Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gold
                    .withValues(alpha: 0.10 + 0.10 * _glow.value),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold
                        .withValues(alpha: 0.14 + 0.18 * _glow.value),
                    blurRadius: 20 + 12 * _glow.value,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: child,
            ),
            child: const Icon(Icons.volunteer_activism_rounded,
                size: 26, color: AppColors.gold),
          ),
          const SizedBox(height: 14),
          _rule(),
          const SizedBox(height: 14),
          Text(
            'about.dua'.tr(),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontFamily: 'AmiriQuran',
              height: 2.1,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          _rule(),
        ],
      ),
    );
  }

  Widget _rule() => SizedBox(
        width: 140,
        height: 1.5,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppColors.gold.withValues(alpha: 0),
              AppColors.gold.withValues(alpha: 0.7),
              AppColors.gold.withValues(alpha: 0),
            ]),
          ),
        ),
      );
}

/// The hadith line, counted from the database that is open right now rather
/// than from a number anyone typed. While `hadith.db` is still opening — or on
/// a device where it has not been downloaded — the sentence appears without
/// its figures instead of with invented ones.
class _HadithFeatureRow extends ConsumerWidget {
  const _HadithFeatureRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(hadithRepositoryProvider).valueOrNull;
    final locale = context.locale.languageCode;
    String n(int v) => localizeDigits('$v', locale);

    return FutureBuilder<(int, int, int)>(
      future: repo?.counts(),
      builder: (context, snap) {
        final c = snap.data;
        return _FeatureRow(
          icon: Icons.auto_stories_rounded,
          title: c == null
              ? 'about.f_hadith_loading'.tr()
              : 'about.f_hadith'.tr(args: [n(c.$1)]),
          subtitle: c == null
              ? 'about.f_hadith_desc_loading'.tr()
              : 'about.f_hadith_desc'.tr(args: [n(c.$2), n(c.$3)]),
        );
      },
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              color: AppColors.gold.withValues(alpha: 0.12),
            ),
            child: Icon(icon, size: 20, color: AppColors.gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
