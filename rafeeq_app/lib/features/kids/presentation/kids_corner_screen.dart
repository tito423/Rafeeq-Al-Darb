import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/azkar_repository.dart';
import '../../../core/db/models.dart';
import '../../../core/utils/digits.dart';
import '../../../core/widgets/islamic_scene.dart';
import '../../../core/widgets/readable_insets.dart';
import '../../azkar/presentation/screens/azkar_section_screen.dart';
import '../data/journey_store.dart';
import '../data/kids_content.dart';
import '../data/kids_stages.dart';
import 'ayah_game_screen.dart';
import 'kids_stage_screen.dart';
import 'kids_stories_screen.dart';

/// «ركن الأطفال» (owner, 2026-09-29): big, bright, and only real content -
/// the short surahs in the app's memorisation screen, the everyday adhkar of
/// «حصن المسلم», and «أكمل الآية», a game on the mushaf's own words.
class KidsCornerScreen extends ConsumerWidget {
  const KidsCornerScreen({super.key});

  static const _palette = [
    Color(0xFF2E86DE), Color(0xFF10AC84), Color(0xFFEE5253),
    Color(0xFFF79F1F), Color(0xFF8854D0), Color(0xFF0ABDE3),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final lang = context.locale.languageCode;
    return Scaffold(
      appBar: AppBar(title: Text('kids.title'.tr())),
      body: ListView(
        padding: readableInsets(context, const EdgeInsets.fromLTRB(16, 4, 16, 32)),
        children: [
          // A greeting over one of the painted night/dawn scenes.
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: SizedBox(
              height: 150,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(painter: IslamicScene(variant: 1, dark: dark)),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('kids.hello'.tr(),
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: dark ? Colors.white : const Color(0xFF3B2A4F),
                            )),
                        Text('kids.hello_sub'.tr(),
                            style: TextStyle(
                              fontSize: 14,
                              color: dark ? Colors.white70 : const Color(0xFF5B4A6F),
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          // The story shelves: drawn, narrated stories from the Qur'an.
          _BigTile(
            color: const Color(0xFF2E86DE),
            icon: Icons.movie_filter_rounded,
            title: 'kids.stories'.tr(),
            subtitle: 'kids.stories_sub'.tr(),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const KidsStoriesScreen())),
          ),
          const SizedBox(height: 12),
          // Only what is for children lives here; «رحلتي» is for every age
          // and has its own entry in More (owner, 2026-09-29).
          _BigTile(
            color: const Color(0xFFF79F1F),
            icon: Icons.extension_rounded,
            title: 'kids.game'.tr(),
            subtitle: 'kids.game_sub'.tr(),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const AyahGameScreen())),
          ),
          const SizedBox(height: 20),
          _Heading(icon: Icons.stairs_rounded, text: 'kids.path'.tr()),
          const SizedBox(height: 4),
          Text('kids.path_sub'.tr(),
              style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 10),
          ValueListenableBuilder<int>(
            valueListenable: JourneyStore.instance.changes,
            builder: (context, _, _) => FutureBuilder<Set<int>>(
              future: JourneyStore.instance.memorized(),
              builder: (context, snap) {
                final done = snap.data ?? const <int>{};
                return Column(
                  children: [
                    for (var i = 0; i < kidsStages.length; i++)
                      _StageCard(
                        step: i + 1,
                        stage: kidsStages[i],
                        done: kidsStages[i].surahs.where(done.contains).length,
                        lang: lang,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                KidsStageScreen(stage: kidsStages[i]),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 22),
          _Heading(icon: Icons.wb_sunny_rounded, text: 'kids.azkar'.tr()),
          const SizedBox(height: 8),
          FutureBuilder<List<AzkarSection>>(
            future: ref.read(azkarRepositoryProvider.future).then((r) => r.sections()),
            builder: (context, snap) {
              final byId = {for (final s in snap.data ?? <AzkarSection>[]) s.id: s};
              final sections = [
                for (final id in kidsAzkarSectionIds)
                  if (byId[id] != null) byId[id]!,
              ];
              return Column(
                children: [
                  for (var i = 0; i < sections.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _BigTile(
                        color: _palette[(i + 2) % _palette.length],
                        icon: Icons.favorite_rounded,
                        title: sections[i].localizedTitle(),
                        subtitle: '',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => AzkarSectionScreen(
                              section: sections[i],
                              accent: _palette[(i + 2) % _palette.length],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          Text(
            'kids.note'.tr(args: [localizeDigits('${kidsStages.fold<int>(0, (n, st) => n + st.surahs.length)}', lang)]),
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Heading({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: const Color(0xFFF79F1F)),
          const SizedBox(width: 8),
          Text(text,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        ],
      );
}

/// A coloured glow under a rounded card. It is painted OUTSIDE the Material:
/// an `Ink` shadow is clipped to the Material's rectangle, which showed as a
/// square block behind the rounded corners in the light theme.
class _Shadowed extends StatelessWidget {
  final Color color;
  final Widget child;
  const _Shadowed({required this.color, required this.child});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.32),
                blurRadius: 14,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Material(color: Colors.transparent, child: child),
      );
}

class _BigTile extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _BigTile({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => _Shadowed(
        color: color,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color, Color.lerp(color, Colors.black, 0.28)!],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900)),
                      if (subtitle.isNotEmpty)
                        Text(subtitle,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _StageCard extends StatelessWidget {
  final int step;
  final KidsStage stage;
  final int done;
  final String lang;
  final VoidCallback onTap;
  const _StageCard({
    required this.step,
    required this.stage,
    required this.done,
    required this.lang,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(stage.color);
    final total = stage.surahs.length;
    final complete = done == total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _Shadowed(
        color: color,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color, Color.lerp(color, Colors.black, 0.3)!],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.22),
                    border: Border.all(color: Colors.white54, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: complete
                      ? const Icon(Icons.emoji_events_rounded,
                          color: Color(0xFFFFD166), size: 30)
                      : Text(localizeDigits('$step', lang),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('kids.stage_${stage.id}'.tr(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w900)),
                      Text('kids.stage_${stage.id}_ages'.tr(),
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 13)),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: done / total,
                          minHeight: 7,
                          color: const Color(0xFFFFD166),
                          backgroundColor: Colors.white24,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'kids.stage_progress'.tr(args: [
                          localizeDigits('$done', lang),
                          localizeDigits('$total', lang),
                        ]),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
