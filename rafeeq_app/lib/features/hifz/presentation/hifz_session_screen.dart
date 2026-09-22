/// One memorization sitting: the surah's ayahs that are due today, one at a
/// time.
///
/// Per ayah: play it as many times as chosen (the app's own per-ayah
/// recitation), hide its words from the end one tap at a time, say it, then
/// «حفظت» or «أعِده». Nothing here judges the recitation — that is the
/// second half of the feature and is not pretended at here (§1.1).
library;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/models.dart';
import '../../../core/db/quran_repository.dart';
import '../../../core/services/ayah_audio_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/arabic_normalize.dart' show surahNameForDisplay;
import '../../../core/utils/digits.dart';
import '../../../core/widgets/arabic_text.dart';
import '../../quran/data/basmala.dart';
import '../data/hifz_mask.dart';
import 'widgets/tasmee_panel.dart';
import '../data/hifz_store.dart';

class HifzSessionScreen extends ConsumerStatefulWidget {
  final Surah surah;
  const HifzSessionScreen({super.key, required this.surah});

  @override
  ConsumerState<HifzSessionScreen> createState() => _HifzSessionScreenState();
}

class _HifzSessionScreenState extends ConsumerState<HifzSessionScreen> {
  List<Ayah>? _ayahs;
  int _at = 0;
  int _step = 0;
  int _repeats = 3;
  bool _playing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    AyahAudioService.instance.stopQueue();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final repo = await ref.read(quranRepositoryProvider.future);
      final all = await repo.ayahsOfSurah(widget.surah.id);
      final due = ref
          .read(hifzStoreProvider)
          .dueIn(widget.surah.id, widget.surah.ayahsCount)
          .toSet();
      final list = all.where((a) => due.contains(a.ayahNumber)).toList();
      if (mounted) setState(() => _ayahs = list.isEmpty ? all : list);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _play(Ayah ayah) async {
    final repo = await ref.read(quranRepositoryProvider.future);
    if (!mounted) return;
    setState(() => _playing = true);
    try {
      await AyahAudioService.instance.playRepeated(
        ayah,
        repo,
        times: _repeats,
        gap: const Duration(milliseconds: 600),
        edition: AyahAudioService.defaultEdition,
        title: '$_name — ${ayah.ayahNumber}',
      );
    } finally {
      if (mounted) setState(() => _playing = false);
    }
  }

  void _next() {
    AyahAudioService.instance.stopQueue();
    final list = _ayahs!;
    if (_at + 1 >= list.length) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _at++;
      _step = 0;
    });
  }

  /// The Uthmani name with its U+06E1 sukun swapped for the plain one — the
  /// chrome font draws U+06E1 as a stray mark (P3-46).
  String get _name => surahNameForDisplay(widget.surah.nameAr);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final list = _ayahs;
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(_name)),
        body: Center(child: Text(_error!)),
      );
    }
    if (list == null) {
      return Scaffold(
        appBar: AppBar(title: Text(_name)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final ayah = list[_at];
    // The stored verse 1 carries the basmala (quran_local.db, 112 surahs);
    // it is not part of the verse, so it is neither hidden, counted nor
    // listened for — it is shown above, on its own line, as a mushaf sets it.
    final basmala = basmalaOf(ayah);
    final body = bodyOf(ayah);
    final words = ayahWords(body);

    return Scaffold(
      appBar: AppBar(
        title: Text(_name),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_at + 1) / list.length,
            minHeight: 4,
            color: AppColors.gold,
            backgroundColor: AppColors.gold.withValues(alpha: 0.15),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            trn(
              'hifz.ayah_of',
              args: ['${ayah.ayahNumber}', '${list.length - _at}'],
            ),
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          if (basmala != null) ...[
            Center(
              child: ArabicText(
                basmala,
                style: const TextStyle(fontFamily: 'AmiriQuran', fontSize: 20),
              ),
            ),
            const SizedBox(height: 8),
          ],
          // The ayah, with the hidden words covered — never altered.
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 10,
                children: [
                  for (var i = 0; i < words.length; i++)
                    _Word(
                      word: words[i],
                      hidden: hifzWordHidden(i, words.length, _step),
                      onTap: () => setState(() {
                        // Tapping a hidden word brings that word back.
                        final hiddenCount = words.length - i;
                        _step = (hiddenCount - 1).clamp(0, words.length);
                      }),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _step >= words.length - 1
                      ? null
                      : () => setState(() => _step++),
                  icon: const Icon(Icons.visibility_off_outlined),
                  label: Text('hifz.hide_one'.tr()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _step == 0 ? null : () => setState(() => _step = 0),
                  icon: const Icon(Icons.visibility_outlined),
                  label: Text('hifz.show_all'.tr()),
                ),
              ),
            ],
          ),
          const Divider(height: 28),
          Row(
            children: [
              Text('hifz.repeats'.tr()),
              const SizedBox(width: 10),
              for (final n in [1, 3, 5, 10])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(
                      localizeDigits('$n', context.locale.languageCode),
                    ),
                    selected: _repeats == n,
                    onSelected: (_) => setState(() => _repeats = n),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _playing
                ? () => AyahAudioService.instance.stopQueue()
                : () => _play(ayah),
            icon: Icon(_playing ? Icons.stop_rounded : Icons.play_arrow_rounded),
            label: Text(_playing ? 'hifz.stop'.tr() : 'hifz.listen'.tr()),
          ),
          const Divider(height: 28),
          // «سمّع لنفسك»: the device listens and marks the words.
          TasmeePanel(
            key: ValueKey('${widget.surah.id}:${ayah.ayahNumber}'),
            ayahText: body,
            surahId: widget.surah.id,
            ayahNumber: ayah.ayahNumber,
            // «أتقنتها»: the same step «حفظتها» takes, offered where the
            // reader just proved it — never taken for him.
            onMastered: () async {
              await ref
                  .read(hifzStoreProvider.notifier)
                  .remembered(widget.surah.id, ayah.ayahNumber);
              if (context.mounted) _next();
            },
          ),
          const Divider(height: 28),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await ref
                        .read(hifzStoreProvider.notifier)
                        .forgot(widget.surah.id, ayah.ayahNumber);
                    if (context.mounted) _next();
                  },
                  icon: const Icon(Icons.replay_rounded),
                  label: Text('hifz.again'.tr()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () async {
                    await ref
                        .read(hifzStoreProvider.notifier)
                        .remembered(widget.surah.id, ayah.ayahNumber);
                    if (context.mounted) _next();
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: Text('hifz.memorized'.tr()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Word extends StatelessWidget {
  final String word;
  final bool hidden;
  final VoidCallback onTap;

  const _Word({required this.word, required this.hidden, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final style = const TextStyle(
      fontFamily: 'AmiriQuran',
      fontSize: 24,
      height: 1.9,
    );
    if (!hidden) {
      return ArabicText(word, style: style);
    }
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: 0.25,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // The word keeps its own width, so the line does not jump when it
            // comes back.
            Opacity(opacity: 0, child: ArabicText(word, style: style)),
            Container(
              height: 3,
              width: 26.0 + word.length * 6,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
