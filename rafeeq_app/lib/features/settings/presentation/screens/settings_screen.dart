import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/rafeeq_app.dart';

/// Settings tab — language, theme, and app info.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
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
          SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('settings.light'.tr()),
                icon: const Icon(Icons.light_mode),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('settings.dark'.tr()),
                icon: const Icon(Icons.dark_mode),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('settings.system'.tr()),
                icon: const Icon(Icons.settings_brightness),
              ),
            ],
            selected: {themeMode},
            onSelectionChanged: (sel) {
              ref.read(themeModeProvider.notifier).set(sel.first);
            },
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
                'cdn.islamic.network • mp3quran.net • islamcan.com',
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
