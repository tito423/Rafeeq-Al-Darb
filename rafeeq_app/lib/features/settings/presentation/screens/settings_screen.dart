import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme_controller.dart';
import '../../../home/data/clock_settings_provider.dart';
import '../../../home/presentation/widgets/clock_gallery_sheet.dart';
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

/// Every actual setting, as a `Column` with no scroll view and no `Scaffold`
/// of its own.
///
/// It is a `Column` on purpose. `MoreScreen` owns the one `ListView` for the
/// whole tab, so that the «المزيد» destinations above and the settings below
/// scroll as a single page. Making this a `ListView` again would nest one
/// scrollable inside another and both would fight for the drag.
///
/// The stand-alone `SettingsScreen` that used to wrap this is gone: nothing
/// pushed it once the More tab took over, and keeping it would have meant a
/// second settings page that silently lacked the destinations.
class SettingsBody extends ConsumerWidget {
  const SettingsBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeVariant = ref.watch(themeControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Language — each shown in its own script, independent of the
          // current locale (P2‑3 added es / ru / pt).
          SectionLabel('settings.language'.tr()),
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
          SectionLabel('settings.theme'.tr()),
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

          // ── Home clock ──
          SectionLabel('home.clock_section'.tr()),
          Card(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                  child: Row(
                    children: [
                      Icon(Icons.schedule_outlined, color: scheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('home.clock_style'.tr(),
                            style: Theme.of(context).textTheme.titleSmall),
                      ),
                    ],
                  ),
                ),
                // The twenty faces live in one gallery, opened from here and
                // from the Home clock itself — one picker, not two lists that
                // can drift apart.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FilledButton.tonalIcon(
                      onPressed: () => ClockGallerySheet.show(context),
                      icon: const Icon(Icons.palette_outlined, size: 18),
                      label: Text(
                        '${'home.clock_gallery_title'.tr()} — '
                        '${_currentFaceLabel(ref)}',
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.access_time),
                  title: Text('home.clock_12h'.tr()),
                  subtitle: Text('home.clock_12h_desc'.tr()),
                  value: ref.watch(clockSettingsProvider).use12Hour,
                  onChanged: (v) =>
                      ref.read(clockSettingsProvider.notifier).set12Hour(v),
                ),
                // Seconds only exist on the digital face; the analogue one
                // always sweeps them.
                if (ref.watch(clockSettingsProvider).style ==
                    ClockStyle.digital)
                  SwitchListTile(
                    secondary: const Icon(Icons.timer_outlined),
                    title: Text('home.clock_seconds'.tr()),
                    value: ref.watch(clockSettingsProvider).showSeconds,
                    onChanged: (v) => ref
                        .read(clockSettingsProvider.notifier)
                        .setShowSeconds(v),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Reading Options for Non-Arabs (Transliteration)
          SectionLabel('settings.non_arabic_reading_title'.tr()),
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
          SectionLabel('settings.permissions'.tr()),
          PermissionsSection(),
          const SizedBox(height: 24),

          // P3‑44: per-surah reminder toggles moved here wholesale from
          // the Home "سنن السور" card — see that card's own doc comment.
          SectionLabel('sunan_suwar.reminders_section_title'.tr()),
          SunanSuwarRemindersSection(),
          const SizedBox(height: 24),

          // P3‑41: the Adhan settings entry that used to live here is
          // gone — real-device feedback pointed out it duplicated the
          // Prayer tab's own `_AdhanSettingsLink` card
          // (`qibla_screen.dart`), which is the one real entry point now.

          // About
          SectionLabel('settings.about'.tr()),
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

/// The name of whichever face is selected right now, so the button on the
/// settings screen says what it will open rather than a bare label.
String _currentFaceLabel(WidgetRef ref) {
  final cs = ref.watch(clockSettingsProvider);
  return cs.style == ClockStyle.digital
      ? cs.digitalFace.labelKey.tr()
      : cs.analogFace.labelKey.tr();
}

/// The heading above a group of options. Public so `MoreScreen` heads its
/// own «المزيد» / «الإعدادات» sections with the same one.
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

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
