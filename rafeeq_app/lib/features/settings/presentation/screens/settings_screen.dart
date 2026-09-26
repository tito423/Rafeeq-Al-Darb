import '../../../../core/widgets/paired_list_view.dart';
import '../widgets/app_font_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/accordion.dart';
import '../../../../core/widgets/islamic_action_card.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/utils/external_link.dart';
import '../../../home/data/clock_settings_provider.dart';
import '../../../quotes/presentation/quote_reminder_section.dart';
import '../../../quran/data/mushaf_theme.dart';
import '../../../quran/presentation/widgets/mushaf_theme_picker.dart';
import '../../../home/presentation/widgets/clock_gallery_sheet.dart';
import '../../../splash/data/splash_video_provider.dart';
import '../../../splash/presentation/screens/splash_preview_screen.dart';
import '../../../sunan_suwar/presentation/sunan_suwar_reminders_section.dart';
import '../../../library/presentation/widgets/book_voice_section.dart';
import '../../../fasting/presentation/fasting_reminder_section.dart';
import '../../../tasbih_reminder/presentation/tasbih_reminder_section.dart';
import '../widgets/non_arabic_reading_card.dart';
import '../../../../core/i18n/supported_locales.dart';
import 'about_screen.dart';
import 'sources_screen.dart';
import '../../../tutorial/data/tutorial_anchors.dart';
import '../widgets/permissions_section.dart';
import '../../../more/presentation/widgets/more_group.dart';
import '../../../../core/widgets/readable_insets.dart';
import '../../../../core/utils/screen_class.dart';

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
/// Which slice of the settings a [SettingsBody] draws. «المزيد» shows them
/// as separate groups - the reminders are not settings one sets once and
/// forgets, and «عن التطبيق» belongs at the very foot of the tab.
enum SettingsPart { settings, reminders, about }

class SettingsBody extends ConsumerWidget {
  const SettingsBody({
    super.key,
    this.part = SettingsPart.settings,
    this.paired = false,
  });

  final SettingsPart part;

  /// Two sections a row sideways - for the page of its own, not inside More.
  final bool paired;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeVariant = ref.watch(themeControllerProvider);
    final splashVideo = ref.watch(splashVideoEnabledProvider);
    final splashSound = ref.watch(splashVideoSoundProvider);
    final scheme = Theme.of(context).colorScheme;

    final items = <Widget>[
        if (part == SettingsPart.settings) ...[
          // Language — each shown in its own script, independent of the
          // current locale (P2‑3 added es / ru / pt).
          CollapsibleSection(
            title: 'settings.language'.tr(),
            icon: Icons.translate_rounded,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in kLanguageNames.entries)
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

          // Theme - collapsible like every other section here: «اختيار
          // ثيم التطبيق يبقى كولابسد برده».
          CollapsibleSection(
            title: 'settings.theme'.tr(),
            icon: Icons.palette_outlined,
            // The tour frames the section's header, which is always shown -
            // not the chips inside, which are folded away until it opens.
            tourAnchor: TourAnchor.settingsTheme,
            children: [
              // A Wrap (not SegmentedButton) so longer translated labels never
              // clip — matches the language selector above.
              TutorialAnchor(
                id: 'settings_theme_chips',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final v in ThemeVariant.values)
                      ChoiceChip(
                        // the check would sit on the avatar icon, muddy
                        showCheckmark: false,
                        avatar: Icon(
                          v.icon,
                          size: 18,
                          color: themeVariant == v
                              ? scheme.onPrimaryContainer
                              : scheme.onSurfaceVariant,
                        ),
                        label: Text(v.labelKey.tr()),
                        selected: themeVariant == v,
                        onSelected: (_) =>
                            ref.read(themeControllerProvider.notifier).set(v),
                      ),
                  ],
                ),
              ),
              if (themeVariant == ThemeVariant.rgb) ...[
                const SizedBox(height: 8),
                Card(
                  child: SwitchListTile(
                    secondary: Icon(
                      Icons.motion_photos_on_outlined,
                      color: scheme.primary,
                    ),
                    title: Text('settings.motion_effects'.tr()),
                    subtitle: Text('settings.motion_effects_desc'.tr()),
                    value: ref.watch(motionEffectsProvider),
                    onChanged: (v) =>
                        ref.read(motionEffectsProvider.notifier).set(v),
                  ),
                ),
              ],
            ],
          ),
          // «مش لاقي فعليًا خيار الاسبلاش سكرين بصوت أو بغير أو عرضها من
          // الأساس». Both switches were here, but inside the appearance block
          // with no heading of their own, so nothing on the screen said
          // «شاشة البداية». They have a heading now.
          // «كارت … بتغيير نوع الخط في البرنامج مع عرض شكل الاختيار فوري».
          CollapsibleSection(
            title: 'settings.font_section'.tr(),
            icon: Icons.font_download_rounded,
            children: const [AppFontPicker()],
          ),
          CollapsibleSection(
            title: 'settings.splash_section'.tr(),
            icon: Icons.auto_awesome_rounded,
            children: [
              // P3‑49: the AI-generated splash video is back on by default; keep
              // a toggle for anyone who prefers a faster cold start.
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: Icon(
                        Icons.smart_display_outlined,
                        color: scheme.primary,
                      ),
                      title: Text('settings.splash_video'.tr()),
                      subtitle: Text('settings.splash_video_desc'.tr()),
                      value: splashVideo,
                      onChanged: (v) =>
                          ref.read(splashVideoEnabledProvider.notifier).set(v),
                    ),
                    // The soundtrack is back in the asset and the choice is his:
                    // «اديني امكانية طبعا يشتغل لو انا فعلت انه يشتغل … او لو
                    // طفيته من الاعدادات مش يشتغل». It defaults OFF, because
                    // the voice in the clip mispronounces «قرآني» and an app
                    // should not say that unless its owner asked for it.
                    // Only offered while the video itself is on — a sound switch
                    // for a video that never plays would be a dead control.
                    if (splashVideo)
                      SwitchListTile(
                        secondary: Icon(
                          splashSound
                              ? Icons.volume_up_outlined
                              : Icons.volume_off_outlined,
                          color: scheme.primary,
                        ),
                        title: Text('settings.splash_video_sound'.tr()),
                        subtitle: Text('settings.splash_video_sound_desc'.tr()),
                        value: splashSound,
                        onChanged: (v) =>
                            ref.read(splashVideoSoundProvider.notifier).set(v),
                      ),
                    // «هل فيه امكانية preview للفيديو من جوه التطبيق» — yes, and
                    // it is the only way to see the intro on demand: it other-
                    // wise plays on a cold start after half an hour away, which
                    // is not something you can wait for while judging it.
                    ListTile(
                      leading: Icon(
                        Icons.play_circle_outline,
                        color: scheme.primary,
                      ),
                      title: Text('settings.splash_preview'.tr()),
                      subtitle: Text('settings.splash_preview_desc'.tr()),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: scheme.primary,
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SplashPreviewScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── Home clock ──
          CollapsibleSection(
            title: 'home.clock_section'.tr(),
            icon: Icons.watch_later_rounded,
            children: [
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
                            child: Text(
                              'home.clock_style'.tr(),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
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
            ],
          ),

          // The text mushaf's own colour scheme — its own section, because it
          // is not the app theme: a light mushaf can be read inside a dark
          // app, and the two settings genuinely mean different things.
          // A collapsible section like its neighbours («الأذونات» and the
          // rest), not a heading over a lone card - the owner asked for it.
          CollapsibleSection(
            title: 'mushaf_theme.title'.tr(),
            icon: Icons.palette_rounded,
            children: [
              Builder(
                builder: (tileContext) => Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.palette_outlined,
                      color: scheme.primary,
                    ),
                    title: Text(_currentMushafThemeLabel(ref)),
                    subtitle: Text('mushaf_theme.subtitle'.tr()),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        MushafThemePicker.show(context, origin: tileContext),
                  ),
                ),
              ),
            ],
          ),

          // Reading Options for Non-Arabs (Transliteration) — and only for
          // them. In Arabic the whole section is gone, which is the same rule
          // `_AyahPanel` applies when it decides whether to render the Latin
          // line at all: a reader who is using the app in Arabic never sees
          // transliteration and never has a switch for it to be stuck on.
          if (context.locale.languageCode != 'ar') ...[
            SectionLabel('settings.non_arabic_reading_title'.tr()),
            const NonArabicReadingCard(),
            const SizedBox(height: 24),
          ],

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
          CollapsibleSection(
            title: 'settings.permissions'.tr(),
            icon: Icons.verified_user_rounded,
            children: [PermissionsSection()],
          ),

          CollapsibleSection(
            title: 'library.voice_section_title'.tr(),
            icon: Icons.record_voice_over_rounded,
            children: const [BookVoiceSection()],
          ),

          // P3‑41: the Adhan settings entry that used to live here is
          // gone — real-device feedback pointed out it duplicated the
          // Prayer tab's own `_AdhanSettingsLink` card
          // (`qibla_screen.dart`), which is the one real entry point now.
        ],
        if (part == SettingsPart.reminders) ...[
          // P3‑44: per-surah reminder toggles moved here wholesale from
          // the Home "سنن السور" card — see that card's own doc comment.
          CollapsibleSection(
            title: 'sunan_suwar.reminders_section_title'.tr(),
            icon: Icons.menu_book_rounded,
            children: [SunanSuwarRemindersSection()],
          ),

          CollapsibleSection(
            title: 'tasbih.section_title'.tr(),
            icon: Icons.all_inclusive_rounded,
            children: const [TasbihReminderSection()],
          ),

          CollapsibleSection(
            title: 'fasting.section_title'.tr(),
            icon: Icons.nights_stay_rounded,
            children: const [FastingReminderSection()],
          ),

          // The Islamic-quote notification, beside the other reminders
          // rather than on a screen of its own: it is one interval and a
          // preview.
          CollapsibleSection(
            title: 'quotes.section_title'.tr(),
            icon: Icons.format_quote_rounded,
            children: [QuoteReminderSection()],
          ),
        ],
        if (part == SettingsPart.about) ...[
          // About - the same cards as the rest of «المزيد».
          IslamicActionCard(
            icon: Icons.info_outline_rounded,
            accent: AppColors.info,
            title: 'app.name'.tr(),
            subtitle: 'settings.about_desc'.tr(),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
            ),
          ),
          TutorialAnchor(
            id: TourAnchor.settingsSources,
            child: IslamicActionCard(
              icon: Icons.verified_user_outlined,
              accent: AppColors.primarySoft,
              title: 'settings.credits'.tr(),
              subtitle: 'about.sources_hint'.tr(),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SourcesScreen()),
              ),
            ),
          ),
          // The policy lives on the app's own bucket rather than in a screen,
          // because Play wants a URL it can open without installing anything
          // — and because a policy nobody outside the app can read is not a
          // policy. Opened in a Custom Tab over the app.
          IslamicActionCard(
            icon: Icons.privacy_tip_outlined,
            accent: AppColors.primarySoft,
            title: 'settings.privacy_policy'.tr(),
            subtitle: 'settings.privacy_policy_desc'.tr(),
            onTap: () => openLink(AppConfig.privacyPolicyUrl, inApp: true),
          ),
        ],
    ];
    // On its own page sideways, two a row like the More tab's groups. Inside
    // the More tab it already sits in one of two columns, and stays single.
    return paired && ScreenClass.twoColumns(context)
        ? PairedColumn(gap: 0, equalHeights: false, children: items)
        : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: items);
  }
}

/// The name of whichever mushaf theme is active, so the row says what it is
/// rather than a bare label. "Follow the app theme" is a real answer, not a
/// missing one.
String _currentMushafThemeLabel(WidgetRef ref) {
  final id = ref.watch(mushafThemeProvider);
  if (id == null) return 'mushaf_theme.follow_app'.tr();
  return mushafThemeById(id).labelKey.tr();
}

/// The name of whichever face is selected right now, so the button on the
/// settings screen says what it will open rather than a bare label.
String _currentFaceLabel(WidgetRef ref) {
  final cs = ref.watch(clockSettingsProvider);
  return cs.style == ClockStyle.digital
      ? cs.digitalFace.labelKey.tr()
      : cs.analogFace.labelKey.tr();
}

/// A section that starts CLOSED.
///
/// The owner asked for the long ones — الأذونات، تذكيرات السنن، المقولات،
/// ساعة الشاشة الرئيسية، اللغة، شاشة البداية — to be collapsed by default:
/// each is a screenful on its own, and six of them stacked meant the settings
/// screen opened on a wall of switches. The heading reads exactly as
/// [SectionLabel] does, so a closed section and an open one look like the same
/// screen.
///
/// The state is deliberately local and not persisted: «افتراضيًا» means every
/// visit starts closed, not that the app remembers a previous visit.
class CollapsibleSection extends StatefulWidget {
  final String title;
  final List<Widget> children;

  /// What the section holds, drawn in a gold badge beside its title —
  /// «حط أيقونات شكلها جميل جنب رؤوس القوائم … وخليها انيميتد».
  final IconData? icon;

  /// A tour anchor for the whole section (header included).
  final String? tourAnchor;

  /// Starts expanded. Used where a section is the WHOLE reason the screen
  /// was opened — «خلي صوت القارئ في التنزيلات يفتح أوتوماتيك الكارت بتاعه
  /// في الإعدادات» (2026-09-21): arriving on a card you then have to tap
  /// open is one tap that carries no decision.
  final bool initiallyOpen;

  const CollapsibleSection({
    super.key,
    required this.title,
    required this.children,
    this.icon,
    this.tourAnchor,
    this.initiallyOpen = false,
  });

  @override
  State<CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<CollapsibleSection>
    with SingleTickerProviderStateMixin, AccordionMember<CollapsibleSection> {
  late bool _open = widget.initiallyOpen;

  @override
  bool get accordionIsOpen => _open;

  @override
  void accordionCollapse() => setState(() => _open = false);

  void _toggle() {
    // Inside a «المزيد» group the section is a screen of its own: «أي شيء
    // فيه نص كثير (مثل تذكير بالتسابيح بأحاديثه) يفتح شاشة كاملة لا يتمدد
    // داخل القائمة» (owner, 2026-09-25). Opening it in place pushed every
    // card below it down the page, inside a group that had itself just
    // opened - that was the jumping.
    final accent = MoreGroupAccent.of(context);
    if (accent != null) {
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(widget.title)),
          body: MoreGroupAccent(
            accent: accent,
            child: ListView(
              padding: readableInsets(context, const EdgeInsets.fromLTRB(16, 12, 16, 28)),
              children: widget.children,
            ),
          ),
        ),
      ));
      return;
    }
    setState(() => _open = !_open);
    if (_open) {
      accordionOpened();
    } else {
      accordionClosed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = _build(context);
    final anchor = widget.tourAnchor;
    return anchor == null ? body : TutorialAnchor(id: anchor, child: body);
  }

  Widget _build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // «يبقى له كروت بنفس شكل القرآن والعبادات» (2026-09-19): the
        // section's heading is the same card the worship entries use.
        IslamicActionCard(
          icon: widget.icon ?? Icons.tune_rounded,
          title: widget.title,
          subtitle: '',
          onTap: _toggle,
          trailing: AnimatedRotation(
            turns: _open ? 0.25 : 0,
            duration: const Duration(milliseconds: 180),
            // chevron_right, not chevron_left: the left one auto-mirrors
            // in RTL and would point the wrong way (trap #7).
            child: Icon(
              Icons.chevron_right,
              color: AppColors.gold.withValues(alpha: 0.85),
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity, height: 0),
          secondChild: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: widget.children,
          ),
          crossFadeState: _open
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
          sizeCurve: Curves.easeOutCubic,
        ),
      ],
    );
  }
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
