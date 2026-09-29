import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/models.dart';
import '../../../core/db/quran_repository.dart';
import '../../../core/utils/arabic_normalize.dart' show surahNamePlain;
import '../../../core/utils/digits.dart';
import '../../../core/widgets/readable_insets.dart';
import '../../hifz/presentation/hifz_session_screen.dart';
import '../data/journey_store.dart';
import '../data/kids_stages.dart';
import 'ayah_game_screen.dart';

/// One stage of the kids' path: its surahs in learning order, each with
/// «سمّع» (the app's memorisation screen, which also plays the recitation to
/// listen along) and «حفظتها» (counts once in «رحلتي»), the stage's
/// progress, a game on the stage's surahs, and a review game on the ones
/// already memorised.
class KidsStageScreen extends ConsumerStatefulWidget {
  final KidsStage stage;
  const KidsStageScreen({super.key, required this.stage});

  @override
  ConsumerState<KidsStageScreen> createState() => _KidsStageScreenState();
}

class _KidsStageScreenState extends ConsumerState<KidsStageScreen> {
  List<Surah>? _surahs;
  Set<int> _done = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = await ref.read(quranRepositoryProvider.future);
    final all = await repo.surahs();
    final done = await JourneyStore.instance.memorized();
    if (mounted) {
      setState(() {
        _surahs = all;
        _done = done;
      });
    }
  }

  Future<void> _toggle(int id) async {
    final on = !_done.contains(id);
    await JourneyStore.instance.setMemorized(id, on);
    setState(() => on ? _done.add(id) : _done.remove(id));
    if (on && mounted) {
      final ar = context.locale.languageCode == 'ar';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'kids.memorized_toast'.tr(
              args: [
                ar
                    ? surahNamePlain(_surahs![id - 1].nameAr)
                    : _surahs![id - 1].nameEn,
              ],
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.stage;
    final color = Color(st.color);
    final lang = context.locale.languageCode;
    final all = _surahs;
    final doneHere = st.surahs.where(_done.contains).toList();
    final progress = doneHere.length / st.surahs.length;
    return Scaffold(
      appBar: AppBar(title: Text('kids.stage_${st.id}'.tr())),
      body: all == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: readableInsets(
                context,
                const EdgeInsets.fromLTRB(16, 4, 16, 32),
              ),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      colors: [color, Color.lerp(color, Colors.black, 0.3)!],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'kids.stage_${st.id}_ages'.tr(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'kids.stage_progress'.tr(
                          args: [
                            localizeDigits('${doneHere.length}', lang),
                            localizeDigits('${st.surahs.length}', lang),
                          ],
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 10,
                          color: const Color(0xFFFFD166),
                          backgroundColor: Colors.white24,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFF79F1F),
                        ),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => AyahGameScreen(surahIds: st.surahs),
                          ),
                        ),
                        icon: const Icon(Icons.extension_rounded),
                        label: Text('kids.game'.tr()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: doneHere.isEmpty
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      AyahGameScreen(surahIds: doneHere),
                                ),
                              ),
                        icon: const Icon(Icons.replay_rounded),
                        label: Text('kids.review'.tr()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'kids.stage_tip'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < st.surahs.length; i++)
                  _SurahRow(
                    n: i + 1,
                    surah: all[st.surahs[i] - 1],
                    color: color,
                    done: _done.contains(st.surahs[i]),
                    lang: lang,
                    onRecite: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            HifzSessionScreen.surah(all[st.surahs[i] - 1]),
                      ),
                    ),
                    onToggle: () => _toggle(st.surahs[i]),
                  ),
              ],
            ),
    );
  }
}

class _SurahRow extends StatelessWidget {
  final int n;
  final Surah surah;
  final Color color;
  final bool done;
  final String lang;
  final VoidCallback onRecite;
  final VoidCallback onToggle;
  const _SurahRow({
    required this.n,
    required this.surah,
    required this.color,
    required this.done,
    required this.lang,
    required this.onRecite,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // The whole card opens the recitation, not only «سمّع» (owner,
    // 2026-09-29: «بضغط عليها مش بيفتح حاجة الا لما اضغط سمع»).
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onRecite,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: done
                  ? color.withValues(alpha: 0.18)
                  : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
              border: Border.all(
                color: done ? color : scheme.outlineVariant,
                width: done ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: color,
                  child: done
                      ? const Icon(
                          Icons.star_rounded,
                          color: Colors.white,
                          size: 20,
                        )
                      : Text(
                          localizeDigits('$n', lang),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang == 'ar' || lang == 'ur'
                            ? surahNamePlain(surah.nameAr)
                            : surah.nameEn,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'kids.ayahs'.tr(
                          args: [localizeDigits('${surah.ayahsCount}', lang)],
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: onRecite,
                  icon: const Icon(Icons.headphones_rounded, size: 18),
                  label: Text('kids.recite'.tr()),
                ),
                IconButton(
                  tooltip: 'kids.memorized'.tr(),
                  onPressed: onToggle,
                  icon: Icon(
                    done
                        ? Icons.check_circle_rounded
                        : Icons.check_circle_outline,
                    color: done ? color : scheme.onSurfaceVariant,
                    size: 30,
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
