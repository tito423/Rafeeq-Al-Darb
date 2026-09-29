import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/azkar_repository.dart';
import '../../../core/db/models.dart';
import '../../../core/db/quran_repository.dart';
import '../../../core/utils/digits.dart';
import '../../../core/widgets/islamic_scene.dart';
import '../../../core/widgets/readable_insets.dart';
import '../../azkar/presentation/screens/azkar_section_screen.dart';
import '../../hifz/presentation/hifz_session_screen.dart';
import '../data/kids_content.dart';
import 'ayah_game_screen.dart';
import 'journey_screen.dart';

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
    final surahs = ref.watch(quranRepositoryProvider).whenData((r) => r.surahs());
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
          Row(
            children: [
              Expanded(
                child: _BigTile(
                  color: const Color(0xFFF79F1F),
                  icon: Icons.extension_rounded,
                  title: 'kids.game'.tr(),
                  subtitle: 'kids.game_sub'.tr(),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => const AyahGameScreen())),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BigTile(
                  color: const Color(0xFF8854D0),
                  icon: Icons.emoji_events_rounded,
                  title: 'journey.title'.tr(),
                  subtitle: 'kids.journey_sub'.tr(),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => const JourneyScreen())),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _Heading(icon: Icons.menu_book_rounded, text: 'kids.surahs'.tr()),
          const SizedBox(height: 8),
          surahs.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const SizedBox.shrink(),
            data: (future) => FutureBuilder<List<Surah>>(
              future: future,
              builder: (context, snap) {
                final all = snap.data;
                if (all == null) return const SizedBox(height: 60);
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (var i = 0; i < kidsSurahIds.length; i++)
                      _Chip(
                        color: _palette[i % _palette.length],
                        label: lang == 'ar' || lang == 'ur'
                            ? all[kidsSurahIds[i] - 1].nameAr
                            : all[kidsSurahIds[i] - 1].nameEn,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => HifzSessionScreen.surah(
                                all[kidsSurahIds[i] - 1]),
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
            'kids.note'.tr(args: [localizeDigits('${kidsSurahIds.length}', lang)]),
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
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
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
              boxShadow: [
                BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 6)),
              ],
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

class _Chip extends StatelessWidget {
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _Chip({required this.color, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
        ),
      );
}
