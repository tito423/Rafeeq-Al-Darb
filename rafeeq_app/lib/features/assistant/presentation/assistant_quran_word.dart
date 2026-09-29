import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navigation.dart';
import '../../../app/shell/tab_request_provider.dart';
import '../../../core/db/models.dart';
import '../../../core/db/quran_repository.dart';
import '../../../core/utils/digits.dart';
import '../../quran/data/quran_jump_provider.dart';
import '../data/assistant_intent.dart';
import '../data/assistant_lexicon.dart' show spokenOrdinals;
import '../data/rafeeq_ear.dart';
import 'assistant_describe.dart';
import 'assistant_sheet.dart' show assistantSheetOpen;

/// «فين كلمة X في القرآن» (owner, 2026-09-29): every word of the Qur'an, by
/// voice. One place: the mushaf opens on it at once. Several places: a list of
/// them - surah and ayah, with the ayah's own words - and the reader picks by
/// tapping or by saying the number («التاسعة»), or the surah («البقرة»).
///
/// The words come from `QuranRepository.searchQuran`, the search screen's own
/// index, so a word, its derivatives («الصلاة» is written «الصلوة» in the
/// Uthmani text) and a whole phrase all resolve.
Future<void> runQuranWord(ProviderContainer ref, String query) async {
  final nav = rootNavigatorKey.currentState;
  final ctx = rootNavigatorKey.currentContext;
  if (nav == null || ctx == null) return;
  final repo = await ref.read(quranRepositoryProvider.future);
  final hits = await repo.searchQuran(query, limit: _cap + 1);
  final surahs = await repo.surahs();
  final ar = assistantLanguage() == 'ar' || assistantLanguage() == 'ur';
  String surahName(int id) => ar ? surahs[id - 1].nameAr : surahs[id - 1].nameEn;

  void open(Ayah a) {
    nav.popUntil((r) => r.isFirst);
    ref.read(quranJumpRequestProvider.notifier).state = a.pageNumber;
    ref.read(requestedTabProvider.notifier).state = AppTab.quran;
  }

  if (hits.isEmpty) {
    rootScaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
        content: Text('assistant.word_none'.tr(args: [query]))));
    return;
  }
  if (hits.length == 1) {
    final a = hits.first;
    rootScaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
        content: Text('assistant.opening'.tr(args: [
      '${surahName(a.surahId)} ${localizeDigits('${a.ayahNumber}', assistantLanguage())}',
    ]))));
    open(a);
    return;
  }
  if (assistantSheetOpen.value) return;
  assistantSheetOpen.value = true;
  try {
    await showModalBottomSheet<void>(
      // ignore: use_build_context_synchronously
      context: ctx,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _WordSheet(
        query: query,
        hits: hits.take(_cap).toList(),
        more: hits.length > _cap,
        surahs: surahs,
        surahName: surahName,
        onPick: open,
      ),
    );
  } finally {
    assistantSheetOpen.value = false;
  }
}

/// A word like «الله» is in over two thousand ayahs; the list stops here and
/// says so, rather than building thousands of rows nobody scrolls.
const _cap = 300;

class _WordSheet extends StatefulWidget {
  final String query;
  final List<Ayah> hits;
  final bool more;
  final List<Surah> surahs;
  final String Function(int) surahName;
  final void Function(Ayah) onPick;
  const _WordSheet({
    required this.query,
    required this.hits,
    required this.more,
    required this.surahs,
    required this.surahName,
    required this.onPick,
  });

  @override
  State<_WordSheet> createState() => _WordSheetState();
}

class _WordSheetState extends State<_WordSheet> {
  StreamSubscription<String>? _heard;

  @override
  void initState() {
    super.initState();
    _heard = RafeeqEar.instance.heard.listen(_onHeard);
  }

  @override
  void dispose() {
    _heard?.cancel();
    super.dispose();
  }

  /// A spoken choice: the row's number, an ordinal, or a surah's name (with or
  /// without the ayah's number).
  void _onHeard(String text) {
    final said = norm(asciiDigits(afterWakeWord(text) ?? text));
    final words = said.split(' ').where((w) => w.isNotEmpty).toList();
    int? number;
    for (final w in words) {
      number ??= int.tryParse(w) ?? spokenOrdinals[w];
    }
    for (final s in widget.surahs) {
      final name = norm(s.nameAr);
      if (name.isNotEmpty && said.contains(name)) {
        final inSurah = widget.hits.where((a) => a.surahId == s.id);
        final byAyah = number == null
            ? null
            : inSurah.where((a) => a.ayahNumber == number).firstOrNull;
        final pick = byAyah ?? inSurah.firstOrNull;
        if (pick != null) return widget.onPick(pick);
      }
    }
    if (number != null && number >= 1 && number <= widget.hits.length) {
      widget.onPick(widget.hits[number - 1]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = assistantLanguage();
    final scheme = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text(
            'assistant.word_found'.tr(args: [
              widget.query,
              '${widget.more ? '+' : ''}${localizeDigits('${widget.hits.length}', lang)}',
            ]),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'assistant.word_hint'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          if (widget.more)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'assistant.word_limit'.tr(args: [localizeDigits('$_cap', lang)]),
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
            ),
          const SizedBox(height: 10),
          for (var i = 0; i < widget.hits.length; i++)
            Card(
              child: ListTile(
                onTap: () => widget.onPick(widget.hits[i]),
                leading: CircleAvatar(
                  radius: 16,
                  child: Text(localizeDigits('${i + 1}', lang),
                      style: const TextStyle(fontSize: 12)),
                ),
                title: Text(
                  '${widget.surahName(widget.hits[i].surahId)} · '
                  '${localizeDigits('${widget.hits[i].ayahNumber}', lang)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  widget.hits[i].textUthmani,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(fontFamily: 'AmiriQuran', fontSize: 16, height: 1.8),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
