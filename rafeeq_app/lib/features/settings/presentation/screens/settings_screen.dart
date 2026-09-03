import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme_controller.dart';
import '../../../adhan/presentation/screens/adhan_settings_screen.dart';
import '../../../downloads/presentation/screens/downloads_screen.dart';
import '../../../new_muslim/presentation/screens/new_muslim_guide_screen.dart';

/// Every locale the app ships, labelled in its own script.
const _languageNames = <String, String>{
  'ar': 'العربية',
  'en': 'English',
  'es': 'Español',
  'ru': 'Русский',
  'pt': 'Português',
};

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
          // Language — each shown in its own script, independent of the
          // current locale (P2‑3 added es / ru / pt).
          _SectionLabel('settings.language'.tr()),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in _languageNames.entries)
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
          const SizedBox(height: 24),

          // Theme
          _SectionLabel('settings.theme'.tr()),
          // A Wrap (not SegmentedButton) so longer translated labels never
          // clip — matches the language selector above.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in ThemeVariant.values)
                ChoiceChip(
                  avatar: Icon(
                    v.icon,
                    size: 18,
                    color: themeVariant == v
                        ? scheme.onSecondaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                  label: Text(v.labelKey.tr()),
                  selected: themeVariant == v,
                  onSelected: (_) =>
                      ref.read(themeControllerProvider.notifier).set(v),
                ),
            ],
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

          // New Muslim Guide — used to be a Home quick-access card; the
          // Home redesign (P2‑11/12/13) replaced that grid with the khatma
          // / sunan-suwar / daily-hadith cards, so this needed a new home
          // rather than losing its only entry point.
          _SectionLabel('new_muslim.title'.tr()),
          Card(
            child: ListTile(
              leading: Icon(Icons.library_books_outlined, color: scheme.primary),
              title: Text('new_muslim.title'.tr()),
              subtitle: Text('home.tap_to_open'.tr()),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const NewMuslimGuideScreen(),
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
