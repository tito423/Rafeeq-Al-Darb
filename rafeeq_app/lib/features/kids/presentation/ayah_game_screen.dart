import 'dart:math';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/models.dart';
import '../../../core/db/quran_repository.dart';
import '../../../core/utils/arabic_normalize.dart' show surahNamePlain;
import '../../../core/utils/digits.dart';
import '../../../core/widgets/readable_insets.dart';
import '../data/journey_store.dart';
import '../data/kids_content.dart';

/// «أكمل الآية»: the ayah is shown without its last word, and the child picks
/// the word from three. Every word on screen is the mushaf's own
/// (`quran_local.db`), shown as it is written; a right answer counts in
/// «رحلتي».
class AyahGameScreen extends ConsumerStatefulWidget {
  /// The surahs to ask from - a stage's, or the reader's memorised ones for
  /// a review.
  final List<int> surahIds;
  const AyahGameScreen({super.key, this.surahIds = kidsSurahIds});

  @override
  ConsumerState<AyahGameScreen> createState() => _AyahGameScreenState();
}

class _AyahGameScreenState extends ConsumerState<AyahGameScreen> {
  final _rnd = Random();
  List<Surah>? _surahs;
  late int _surahId = widget.surahIds.first;
  AyahQuestion? _q;
  String? _picked;
  int _score = 0;
  int _asked = 0;

  /// Ayahs of [_surahId] already asked. Owner, 2026-09-29: «ليه بيعيد
  /// الاسئلة»: the game drew a random ayah each time from ONE surah (the
  /// stage's first, al-Fatihah: five usable ayahs) and forgot what it had
  /// asked, so questions came back within a few turns. Now each ayah is
  /// asked once, and when a surah runs out the game moves to the next one.
  final Set<int> _done = {};

  @override
  void initState() {
    super.initState();
    _next();
  }

  Future<void> _next() async {
    final repo = await ref.read(quranRepositoryProvider.future);
    _surahs ??= await repo.surahs();
    AyahQuestion? q;
    // Every surah in the list at most once, then start the round again.
    for (var tries = 0; tries <= widget.surahIds.length && q == null; tries++) {
      final ayahs = await repo.ayahsOfSurah(_surahId);
      q = makeAyahQuestion(ayahs, _rnd, exclude: _done);
      if (q == null) {
        final i = widget.surahIds.indexOf(_surahId);
        _surahId = widget.surahIds[(i + 1) % widget.surahIds.length];
        _done.clear();
      }
    }
    if (!mounted) return;
    if (q != null) _done.add(q.ayah.ayahNumber);
    setState(() {
      _q = q;
      _picked = null;
    });
  }

  void _pick(String w) {
    if (_picked != null || _q == null) return;
    final right = w == _q!.answer;
    setState(() {
      _picked = w;
      _asked++;
      if (right) _score++;
    });
    if (right) JourneyStore.instance.record('game');
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final scheme = Theme.of(context).colorScheme;
    final q = _q;
    final surahs = _surahs;
    return Scaffold(
      appBar: AppBar(title: Text('kids.game'.tr())),
      body: ListView(
        padding: readableInsets(context, const EdgeInsets.fromLTRB(16, 8, 16, 32)),
        children: [
          if (surahs != null)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final id in widget.surahIds)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: ChoiceChip(
                        label: Text(lang == 'ar' || lang == 'ur'
                            ? surahNamePlain(surahs[id - 1].nameAr)
                            : surahs[id - 1].nameEn),
                        selected: id == _surahId,
                        onSelected: (_) {
                          setState(() {
                            _surahId = id;
                            _done.clear();
                          });
                          _next();
                        },
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Text(
            'kids.score'.tr(args: [
              localizeDigits('$_score', lang),
              localizeDigits('$_asked', lang),
            ]),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (q == null)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFF79F1F), width: 1.5),
              ),
              child: Text(
                '${q.prompt} …',
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                    fontFamily: 'AmiriQuran',
                    fontSize: 26,
                    height: 2.1,
                    color: scheme.onSurface),
              ),
            ),
            const SizedBox(height: 18),
            for (final c in q.choices)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _Choice(
                  word: c,
                  state: _picked == null
                      ? 0
                      : c == q.answer
                          ? 1
                          : c == _picked
                              ? 2
                              : 0,
                  onTap: () => _pick(c),
                ),
              ),
            if (_picked != null) ...[
              Text(
                _picked == q.answer ? 'kids.right'.tr() : 'kids.wrong'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: _picked == q.answer
                      ? const Color(0xFF10AC84)
                      : const Color(0xFFEE5253),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _next,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text('kids.next'.tr()),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  final String word;

  /// 0 nothing yet / not chosen, 1 the right word, 2 the wrong one chosen.
  final int state;
  final VoidCallback onTap;
  const _Choice({required this.word, required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      1 => const Color(0xFF10AC84),
      2 => const Color(0xFFEE5253),
      _ => const Color(0xFF2E86DE),
    };
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Text(
            word,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
                fontFamily: 'AmiriQuran', fontSize: 26, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
