/// «حط في كروت شرايح الصلاة في الشاشة الرئيسية اختيار الخلفية بتاعة الأذان
/// ومعاينة الأذان». Two rows under a prayer's muezzin: the adhan screen's
/// background, and the full adhan screen for THIS prayer, played now.
///
/// Its own file because `prayer_slides.dart` is close to the 800-line guard.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/adhan_native.dart';
import '../../../../core/theme/hero_surface.dart';
import '../../../adhan/data/adhan_catalog_provider.dart';
import '../../../adhan/data/adhan_scheduler.dart';
import '../../../adhan/data/adhan_settings_provider.dart';
import '../../../adhan/presentation/screens/adhan_background_screen.dart';
import '../../../adhan/presentation/screens/azan_player_screen.dart';

class PrayerSlideAdhanExtras extends ConsumerWidget {
  final String prayerKey;
  final Color color;

  /// Called before the full-screen preview opens, so the card's own row
  /// preview stops and two adhans never overlap.
  final Future<void> Function() stopRowPreview;

  const PrayerSlideAdhanExtras({
    super.key,
    required this.prayerKey,
    required this.color,
    required this.stopRowPreview,
  });

  Future<void> _preview(BuildContext context, WidgetRef ref) async {
    final settings = ref.read(adhanSettingsProvider);
    final catalog = ref.read(adhanCatalogProvider).valueOrNull ?? const [];
    if (catalog.isEmpty) return;
    await stopRowPreview();
    await AdhanNative.stop();
    if (!context.mounted) return;
    final spec = previewSpec(
      settings: settings,
      catalog: catalog,
      prayerKey: prayerKey,
      prayerLabel: 'prayer.$prayerKey'.tr(),
    );
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AzanPlayerScreen(
          spec: spec,
          playerMode: AzanPlayerMode.preview,
        ),
      ),
    );
    await AdhanNative.stop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Row(
          icon: Icons.auto_awesome_mosaic_rounded,
          label: 'adhan.backgrounds_title'.tr(),
          color: color,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const AdhanBackgroundScreen(),
            ),
          ),
        ),
        _Row(
          icon: Icons.play_circle_fill_rounded,
          label: 'prayer.preview_azan'.tr(),
          color: color,
          onTap: () => _preview(context, ref),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _Row({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hero = HeroSurface.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: hero.accent(color)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: hero.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // chevron_right: must not mirror in RTL (trap #7).
            Icon(Icons.chevron_right, size: 18, color: hero.onSurfaceFaint),
          ],
        ),
      ),
    );
  }
}
