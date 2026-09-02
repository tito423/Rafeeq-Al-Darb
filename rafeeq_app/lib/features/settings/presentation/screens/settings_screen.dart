import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme_controller.dart';
import '../../../adhan/presentation/screens/adhan_settings_screen.dart';
import '../../../downloads/presentation/screens/downloads_screen.dart';

/// Settings tab — language, theme, and app info.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeVariant = ref.watch(themeControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('nav.settings'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Language
          _SectionLabel('settings.language'.tr()),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: 'ar',
                label: Text('settings.arabic'.tr()),
                icon: const Icon(Icons.language),
              ),
              ButtonSegment(
                value: 'en',
                label: Text('settings.english'.tr()),
                icon: const Icon(Icons.translate),
              ),
            ],
            selected: {context.locale.languageCode},
            onSelectionChanged: (sel) {
              final code = sel.first;
              if (code != context.locale.languageCode) {
                context.setLocale(Locale(code));
              }
            },
          ),
          const SizedBox(height: 24),

          // Theme
          _SectionLabel('settings.theme'.tr()),
          SegmentedButton<ThemeVariant>(
            showSelectedIcon: false,
            segments: [
              for (final v in ThemeVariant.values)
                ButtonSegment(
                  value: v,
                  label: Text(v.labelKey.tr()),
                  icon: Icon(v.icon, size: 18),
                ),
            ],
            selected: {themeVariant},
            onSelectionChanged: (sel) {
              ref.read(themeControllerProvider.notifier).set(sel.first);
            },
          ),
          if (themeVariant == ThemeVariant.rgb) ...[
            const SizedBox(height: 8),
            Card(
              child: SwitchListTile(
                secondary: Icon(Icons.motion_photos_on_outlined,
                    color: scheme.primary),
                title: Text('settings.motion_effects'.tr()),
                subtitle: Text('settings.motion_effects_desc'.tr()),
                value: ref.watch(motionEffectsProvider),
                onChanged: (v) =>
                    ref.read(motionEffectsProvider.notifier).set(v),
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Adhan
          _SectionLabel('prayer.adhan_settings'.tr()),
          Card(
            child: ListTile(
              leading: Icon(Icons.notifications_active_outlined,
                  color: scheme.primary),
              title: Text('prayer.adhan_settings'.tr()),
              subtitle: Text('prayer.choose_adhan'.tr()),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AdhanSettingsScreen(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Offline content
          _SectionLabel('downloads.title'.tr()),
          Card(
            child: ListTile(
              leading: Icon(Icons.download_for_offline_outlined,
                  color: scheme.primary),
              title: Text('downloads.title'.tr()),
              subtitle: Text('downloads.offline_ready'.tr()),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DownloadsScreen(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // About
          _SectionLabel('settings.about'.tr()),
          Card(
            child: ListTile(
              leading: Icon(Icons.info_outline, color: scheme.primary),
              title: Text('app.name'.tr()),
              subtitle: Text('settings.about_desc'.tr()),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(Icons.verified_user_outlined, color: scheme.primary),
              title: Text('settings.credits'.tr()),
              subtitle: Text(
                'api.quran.com • api.alquran.cloud • api.aladhan.com • '
                'cdn.islamic.network • mp3quran.net • islamcan.com • '
                'quranpedia/quran-svg (CC0)',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
