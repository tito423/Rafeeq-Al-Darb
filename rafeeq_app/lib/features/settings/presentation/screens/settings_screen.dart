import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme_controller.dart';
import '../../../downloads/presentation/screens/downloads_screen.dart';
import '../../../new_muslim/presentation/screens/new_muslim_guide_screen.dart';
import '../../../splash/data/splash_video_provider.dart';
import '../../../sunan_suwar/presentation/sunan_suwar_reminders_section.dart';
import '../widgets/non_arabic_reading_card.dart';
import 'about_screen.dart';
import 'sources_screen.dart';
import '../widgets/permissions_section.dart';

/// Every locale the app ships, labelled in its own script.
const _languageNames = <String, String>{
  'ar': 'العربية',
  'en': 'English',
  'es': 'Español',
  'ru': 'Русский',
  'pt': 'Português',
  'fr': 'Français',
  'ur': 'اردو',
};

/// Settings tab — language, theme, and app info.
///
/// P3‑54: the settings entry point moved off the Home header card into a
/// dedicated "المزيد" (More) bottom-nav tab (`MoreScreen`). Both that tab and
/// this stand-alone screen render the exact same [SettingsBody], so there is
/// one source of truth for the options regardless of how they're reached.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('nav.settings'.tr())),
      body: const SettingsBody(),
    );
  }
}

/// The scrollable list of every settings/"more" option, with no `Scaffold`
/// of its own so it can be hosted either by [SettingsScreen] (a pushed route)
/// or by the More tab (`MoreScreen`, which supplies its own AppBar titled
/// "المزيد").
class SettingsBody extends ConsumerWidget {
  const SettingsBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeVariant = ref.watch(themeControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    return ListView(
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
          const SizedBox(height: 8),
          // P3‑49: the AI-generated splash video is back on by default; keep
          // a toggle for anyone who prefers a faster cold start.
          Card(
            child: SwitchListTile(
              secondary:
                  Icon(Icons.smart_display_outlined, color: scheme.primary),
              title: Text('settings.splash_video'.tr()),
              subtitle: Text('settings.splash_video_desc'.tr()),
              value: ref.watch(splashVideoEnabledProvider),
              onChanged: (v) =>
                  ref.read(splashVideoEnabledProvider.notifier).set(v),
            ),
          ),
          const SizedBox(height: 24),

          // Reading Options for Non-Arabs (Transliteration)
          _SectionLabel('settings.non_arabic_reading_title'.tr()),
          const NonArabicReadingCard(),
          const SizedBox(height: 24),

          // P3‑41: one place for every permission the app actually needs,
          // each re-checked on resume (granted from a system settings
          // screen, not an in-app dialog).
          //
          // P3‑45: real-device feedback found this section's own text
          // frozen in whatever locale was active when it last happened to
          // rebuild (e.g. a Spanish label surviving a later switch to
          // Arabic) — `.tr()` reads from easy_localization's own global
          // current-locale state, not a `BuildContext` dependency, so
          // nothing marks a `.tr()`-only widget dirty on locale change by
          // itself; a plain `Widget.canUpdate`/`identical()` check in
          // Flutter's own element-update path then short-circuits and
          // never re-invokes `build()` at all when the parent keeps
          // passing back the exact same canonicalized `const` instance.
          // Dropping `const` here (and below) is enough on its own: the
          // parent now constructs a genuinely new, non-identical widget
          // every rebuild, so Flutter takes the normal update path and
          // calls `build()` again with fresh translations.
          _SectionLabel('settings.permissions'.tr()),
          PermissionsSection(),
          const SizedBox(height: 24),

          // P3‑44: per-surah reminder toggles moved here wholesale from
          // the Home "سنن السور" card — see that card's own doc comment.
          _SectionLabel('sunan_suwar.reminders_section_title'.tr()),
          SunanSuwarRemindersSection(),
          const SizedBox(height: 24),

          // P3‑41: the Adhan settings entry that used to live here is
          // gone — real-device feedback pointed out it duplicated the
          // Prayer tab's own `_AdhanSettingsLink` card
          // (`qibla_screen.dart`), which is the one real entry point now.

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
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading:
                  Icon(Icons.verified_user_outlined, color: scheme.primary),
              title: Text('settings.credits'.tr()),
              subtitle: Text('about.sources_hint'.tr()),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SourcesScreen()),
              ),
            ),
          ),
        ],
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
