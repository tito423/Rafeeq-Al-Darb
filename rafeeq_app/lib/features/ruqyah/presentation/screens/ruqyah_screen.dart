import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import '../../../../core/utils/digits.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/models.dart';
import '../../../../core/db/quran_repository.dart';
import '../../../../core/db/azkar_repository.dart';
import '../../../../core/services/ayah_audio_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/error_retry.dart';
import '../../../../core/widgets/islamic_pattern.dart';
import '../../../downloads/data/reciters_provider.dart';
import '../../../quran/presentation/widgets/ayah_sciences/sciences_header.dart';
import '../../data/ruqyah_catalog.dart';
import 'ruqyah_audio_screen.dart';


/// Everything the ruqyah is made of, assembled from sources already in the app.
///
/// Not one word on this screen is typed into Dart. The verses come from
/// `quran_local.db` through [QuranRepository.ayahRange] — the same text the
/// mushaf draws — and the supplications come from the bundled Ḥiṣn al-Muslim
/// table by row id, carrying their own takhrij with them. A ruqyah screen with
/// its own copy of the Qur'an in it would be a second copy of scripture that
/// nothing keeps in step with the first.
class RuqyahScreen extends ConsumerStatefulWidget {
  const RuqyahScreen({super.key});

  @override
  ConsumerState<RuqyahScreen> createState() => _RuqyahScreenState();
}

class _RuqyahScreenState extends ConsumerState<RuqyahScreen> {
  /// Which group is being recited, if any — so the button on that group turns
  /// into a stop button and no other one does.
  int? _playingGroup;
  int _playingIndex = 0;

  @override
  void dispose() {
    // Leaving must never leave a recitation sounding behind the screen.
    if (_playingGroup != null) AyahAudioService.instance.stopQueue();
    super.dispose();
  }

  Future<void> _playGroup(int groupIndex, List<Ayah> ayahs) async {
    final audio = AyahAudioService.instance;
    if (_playingGroup == groupIndex) {
      await audio.stopQueue();
      await audio.stop();
      if (mounted) setState(() => _playingGroup = null);
      return;
    }
    final repo = await ref.read(quranRepositoryProvider.future);
    if (!mounted) return;
    setState(() {
      _playingGroup = groupIndex;
      _playingIndex = 0;
    });
    await audio.playQueue(
      ayahs,
      repo,
      // The reciter the chip beside the button shows. Without this the queue
      // ran on playQueue's default whatever the chip said, which would make
      // the chooser a label rather than a control.
      edition: ref.read(selectedReciterProvider),
      titleFor: (a, i) => 'ruqyah.title'.tr(),
      onIndex: (i) {
        if (mounted) setState(() => _playingIndex = i);
      },
    );
    // playQueue returns when the run finishes or is superseded; only clear the
    // flag if this run is still the current one.
    if (mounted && _playingGroup == groupIndex) {
      setState(() => _playingGroup = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(_ruqyahContentProvider);
    final scheme = Theme.of(context).colorScheme;
    final accent = goldOn(scheme);

    return Scaffold(
      // No headphones action here: it opened exactly the screen the
      // «استمع إلى تلاوات الرقية» button below opens, and the owner asked for
      // the duplicate to go. The button stays because it says what it does.
      appBar: AppBar(title: Text('ruqyah.title'.tr())),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetry(
          message: 'errors.generic'.tr(),
          onRetry: () => ref.invalidate(_ruqyahContentProvider),
        ),
        data: (content) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            IslamicPatternPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.healing_outlined, color: accent, size: 26),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'ruqyah.intro'.tr(),
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 13,
                            height: 1.55,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const RuqyahAudioScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.headphones_rounded, size: 18),
                      label: Text('ruqyah.listen_recordings'.tr()),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            for (var g = 0; g < ruqyahGroups.length; g++) ...[
              _GroupCard(
                group: ruqyahGroups[g],
                ayahs: content.groups[g],
                playing: _playingGroup == g,
                playingIndex: _playingGroup == g ? _playingIndex : -1,
                onPlay: () => _playGroup(g, content.groups[g]),
              ),
              const SizedBox(height: 16),
            ],

            // ── The supplications ──
            _SectionTitle('ruqyah.group_duas'.tr()),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'ruqyah.group_duas_note'.tr(),
                style:
                    TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
            ),
            for (final d in content.duas) _DuaCard(item: d),
          ],
        ),
      ),
    );
  }
}

/// Everything the screen renders, loaded once.
class _RuqyahContent {
  /// One list of ayahs per group, in [ruqyahGroups] order.
  final List<List<Ayah>> groups;
  final List<AzkarItem> duas;

  const _RuqyahContent(this.groups, this.duas);
}

final _ruqyahContentProvider = FutureProvider<_RuqyahContent>((ref) async {
  final quran = await ref.watch(quranRepositoryProvider.future);
  final azkar = await ref.watch(azkarRepositoryProvider.future);

  final groups = <List<Ayah>>[];
  for (final g in ruqyahGroups) {
    final ayahs = <Ayah>[];
    for (final p in g.passages) {
      ayahs.addAll(await quran.ayahRange(p.surah, p.from, p.to));
    }
    groups.add(ayahs);
  }
  final duas = await azkar.itemsByIds(ruqyahDuaItemIds);
  return _RuqyahContent(groups, duas);
});

class _GroupCard extends StatelessWidget {
  final RuqyahGroup group;
  final List<Ayah> ayahs;
  final bool playing;
  final int playingIndex;
  final VoidCallback onPlay;

  const _GroupCard({
    required this.group,
    required this.ayahs,
    required this.playing,
    required this.playingIndex,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = goldOn(scheme);
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Color.alphaBlend(
                scheme.primary.withValues(alpha: 0.10),
                scheme.surfaceContainerHighest,
              ),
              scheme.surfaceContainerHigh,
            ],
          ),
          border: Border.all(color: accent.withValues(alpha: 0.38)),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: IslamicPatternPainter(
                    tile: 52,
                    color: accent.withValues(alpha: 0.07),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          group.titleKey.tr(),
                          style: TextStyle(
                            color: accent,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      // «ضيف جنبه اختيار لاختيار القارئ اللي يقراها
                      // بالترتيب». Deliberately the SAME widget the tafsir
                      // card uses, so it is the same provider, the same
                      // picker and the same highlight - two reciter choices
                      // in one app would be two reciters.
                      const Flexible(child: ReciterChip()),
                      const SizedBox(width: 6),
                      IconButton.filledTonal(
                        onPressed: onPlay,
                        tooltip: 'ruqyah.play_group'.tr(),
                        icon: Icon(
                          playing
                              ? Icons.stop_rounded
                              : Icons.play_arrow_rounded,
                        ),
                      ),
                    ],
                  ),
                  // The honest note about what puts this group in the ruqyah.
                  Text(
                    group.noteKey.tr(),
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (var i = 0; i < ayahs.length; i++)
                    _AyahLine(
                      ayah: ayahs[i],
                      highlighted: i == playingIndex,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AyahLine extends StatelessWidget {
  final Ayah ayah;
  final bool highlighted;

  const _AyahLine({required this.ayah, required this.highlighted});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = goldOn(scheme);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        // A white wash is invisible on a light theme, and a fixed translucent
        // gold composites differently on each ground (trap #15) - both now
        // come from the live scheme.
        color: highlighted
            ? accent.withValues(alpha: 0.20)
            : scheme.onSurface.withValues(alpha: 0.04),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ayah.textUthmani,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 19,
              height: 1.95,
              fontFamily: 'KFGQPCHafs',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            localizeDigits('${ayah.surahId}:${ayah.ayahNumber}', uiLanguageCode),
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _DuaCard extends StatelessWidget {
  final AzkarItem item;
  const _DuaCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: scheme.surfaceContainerHighest,
        border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.body,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 16,
              height: 1.9,
            ),
          ),
          // The takhrij the database carries, shown as it is. A dua without a
          // source is not shown at all, so this is never empty by accident.
          if (item.footnote.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              item.footnote,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 11,
                height: 1.6,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 6),
        child: Text(
          text,
          style: TextStyle(
            color: goldOn(Theme.of(context).colorScheme),
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}
