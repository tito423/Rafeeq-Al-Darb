import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// The "about" page: who built the app, what version this is, and what it can
/// actually do.
///
/// The capability list is deliberately written from what is really shipped and
/// verified — seven mushaf printings whose pages are all hosted, 45 complete
/// Quran translations, nine hadith collections — rather than an aspirational
/// feature list. If a capability changes, this list changes with it.
class AboutScreen extends StatefulWidget {
  /// From `pubspec.yaml`'s `version:`.
  static const appVersion = '3.1.0';

  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen>
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('settings.about'.tr())),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _staggered(index: 0, child: _hero(theme, scheme)),
          const SizedBox(height: 22),
          _staggered(
            index: 1,
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
            index: 2,
            child: Text(
              'about.capabilities'.tr(),
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: scheme.primary),
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < _features.length; i++) ...[
            _staggered(
              index: 3 + i,
              child: _FeatureRow(
                icon: _features[i].$1,
                title: _features[i].$2.tr(),
                subtitle: _features[i].$3.tr(),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
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

/// (icon, title key, subtitle key) — kept honest against what actually ships.
const _features = <(IconData, String, String)>[
  (Icons.menu_book_rounded, 'about.f_quran', 'about.f_quran_desc'),
  (Icons.translate_rounded, 'about.f_translations',
      'about.f_translations_desc'),
  (Icons.headphones_rounded, 'about.f_audio', 'about.f_audio_desc'),
  (Icons.mosque_rounded, 'about.f_prayer', 'about.f_prayer_desc'),
  (Icons.auto_stories_rounded, 'about.f_hadith', 'about.f_hadith_desc'),
  (Icons.spa_rounded, 'about.f_azkar', 'about.f_azkar_desc'),
  (Icons.cloud_off_rounded, 'about.f_offline', 'about.f_offline_desc'),
];

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
