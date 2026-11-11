/// «الإعراب» — the ayah's section of «إعراب القرآن الكريم» by Ahmad Ubaid
/// al-Da'as, Ahmad Muhammad Hamidan and Isma'il Mahmud al-Qasim (Dar
/// al-Munir / Dar al-Farabi, 1st ed. 1425 AH), the owner's chosen source
/// (2026-09-25).
///
/// It replaced the per-word cards built from the Quranic Arabic Corpus: the
/// owner allowed those labels only if 100% certain, and they were not.
///
/// Where the book says «سبق إعرابها» and the earlier place was PROVED
/// (the book's own quote found in it, or the ayah repeated word for word -
/// scripts/resolve_irab_daas_refs.py), that earlier i'rab is shown under the
/// book's line, framed and labelled, as the owner asked. Unproved references
/// show the book's sentence alone - never a guessed target.
///
/// The book parses up to 12 ayahs as one run. Only the opened ayah's part is
/// shown, cut where the book's quotes move to the next ayah
/// (assets/data/irab_daas_splits.json, scripts/build_irab_daas_splits.py);
/// a run the script could not cut safely is shown whole, with its range.
/// The book and its authors are credited on the Sources screen only (owner,
/// 2026-10-03).
///
/// Our own word-by-word i'rab (owner, 2026-10-03: it replaces the book's
/// text) is shown instead wherever a surah has been written and checked
/// word by word against al-Da'as by hand (assets/data/own_irab.json, from
/// scripts/own_irab/export_app.py). A second view the book gives is shown
/// under the word, named. Machine-generated text never reaches this asset.
///
/// Above the words, a note says plainly what this i'rab is (prepared by the
/// app against named books, not a critical edition) with a way to report an
/// error. For a reader in the other six languages each word also carries
/// short grammar labels (owner, 2026-11-12, §1.7c), READ from the Arabic
/// text by scripts/own_irab/irab_tags.py - the Arabic stays the reference.
library;

import 'dart:convert';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/config/app_config.dart';
import '../../../../../core/db/models.dart';
import '../../../../../core/db/quran_repository.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/arabic_normalize.dart';
import '../../../../../core/utils/digits.dart';
import '../../../../../core/utils/external_link.dart';
import 'sciences_common.dart';

final _surahNamesProvider = FutureProvider<Map<int, String>>((ref) async {
  final repo = await ref.watch(quranRepositoryProvider.future);
  return {for (final s in await repo.surahs()) s.id: surahNameShort(s.nameAr)};
});

/// "surah:ayahFrom" -> the offsets in the run where ayahFrom+1, +2... start.
final _splitsProvider = FutureProvider<Map<String, List<int>>>((ref) async {
  final raw = await rootBundle.loadString('assets/data/irab_daas_splits.json');
  return (jsonDecode(raw) as Map<String, dynamic>).map(
    (k, v) => MapEntry(k, [for (final o in v as List) o as int]),
  );
});

/// "surah:ayah" -> [word, i'rab, [[book, text], ...], [tag, ...]] for
/// every word.
final ownIrabProvider = FutureProvider<Map<String, List<OwnIrabWord>>>((
  ref,
) async {
  final raw = await rootBundle.loadString('assets/data/own_irab.json');
  return (jsonDecode(raw) as Map<String, dynamic>).map(
    (k, v) => MapEntry(k, [
      for (final w in (v as List).cast<List<dynamic>>())
        OwnIrabWord(
          word: w[0] as String,
          irab: w[1] as String,
          alts: [
            for (final a in (w[2] as List).cast<List<dynamic>>())
              (a[0] as String, a[1] as String),
          ],
          tags: w.length > 3
              ? (w[3] as List).cast<String>()
              : const <String>[],
        ),
    ]),
  );
});

class OwnIrabWord {
  final String word;
  final String irab;
  final List<(String, String)> alts;

  /// `role` or `role:case` (`~` after the case: by position), e.g.
  /// `obj:acc`, `subj:nom~`; translated under `irab_tag.*` / `irab_case.*`.
  final List<String> tags;
  const OwnIrabWord({
    required this.word,
    required this.irab,
    required this.alts,
    this.tags = const <String>[],
  });
}

class IrabTab extends ConsumerWidget {
  final Ayah ayah;
  /// The book's section; null while the sciences pack is not downloaded.
  final Future<IrabSection?>? future;

  /// Shown for an ayah we have not written when [future] is null.
  final Widget whenMissing;
  const IrabTab({
    super.key,
    required this.ayah,
    required this.future,
    required this.whenMissing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = ref.watch(_surahNamesProvider).value ?? const <int, String>{};
    final splits = ref.watch(_splitsProvider);
    final own = ref.watch(ownIrabProvider);
    if (splits.isLoading || own.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final words = own.value?['${ayah.surahId}:${ayah.ayahNumber}'];
    if (words != null && words.isNotEmpty) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
        itemCount: words.length + 1,
        separatorBuilder: (_, i) =>
            i == 0 ? const SizedBox(height: 12) : const Divider(height: 18),
        itemBuilder: (context, i) =>
            i == 0 ? _OwnIrabNote(ayah: ayah) : _OwnWord(words[i - 1]),
      );
    }
    final book = future;
    if (book == null) return whenMissing;
    final cuts = splits.value ?? const <String, List<int>>{};
    return AsyncTab<IrabSection?>(
      future: book,
      isEmpty: (d) => d == null,
      builder: (context, section) {
        final s = section!;
        final range = _rangeOf(s, cuts['${s.surah}:${s.ayahFrom}']);
        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
          children: [
            if (range == null && s.ayahTo > s.ayahFrom) ...[
              _RangeNote(section: s),
              const SizedBox(height: 10),
            ],
            ..._body(context, s, names, range),
          ],
        );
      },
    );
  }

  /// This ayah's [start, end) in the run, or null when the run is shown
  /// whole (one ayah, or a run that was not cut).
  (int, int)? _rangeOf(IrabSection s, List<int>? cut) {
    if (s.ayahTo == s.ayahFrom || cut == null) return null;
    if (cut.length != s.ayahTo - s.ayahFrom) return null;
    final i = ayah.ayahNumber - s.ayahFrom;
    final start = i == 0 ? 0 : cut[i - 1];
    final end = i < cut.length ? cut[i] : s.text.length;
    if (start < 0 || end > s.text.length || start >= end) return null;
    return (start, end);
  }

  /// The book's text, cut at each proved reference, with the referenced
  /// i'rab framed right after the clause that points to it.
  List<Widget> _body(
    BuildContext context,
    IrabSection s,
    Map<int, String> names,
    (int, int)? range,
  ) {
    final out = <Widget>[];
    final (from, to) = range ?? (0, s.text.length);
    var start = from;
    for (final r in s.references) {
      if (r.at <= start || r.at > to) continue;
      out.add(_BookText(s.text.substring(start, r.at).trim()));
      out.add(_ReferenceBlock(reference: r, surahName: names[r.targetSurah]));
      start = r.at;
    }
    final rest = s.text.substring(start, to).trim();
    if (rest.isNotEmpty) out.add(_BookText(rest));
    return out;
  }
}

class _RangeNote extends StatelessWidget {
  final IrabSection section;
  const _RangeNote({required this.section});

  @override
  Widget build(BuildContext context) {
    return Text(
      trn(
        'quran.irab_section_range',
        args: ['${section.ayahFrom}', '${section.ayahTo}'],
      ),
      style: Theme.of(
        context,
      ).textTheme.labelMedium?.copyWith(color: AppColors.gold),
    );
  }
}

/// A run of the book's text. The Qur'an words it parses («…») are set
/// in gold, as the print sets them in bold. Always right to left: it is an
/// Arabic book whatever the interface language.
class _BookText extends StatelessWidget {
  final String text;
  const _BookText(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.bodyLarge?.copyWith(height: 1.9);
    final quote = base?.copyWith(
      color: AppColors.gold,
      fontWeight: FontWeight.w700,
    );
    final spans = <TextSpan>[];
    var i = 0;
    for (final m in RegExp('«[^«»]*»').allMatches(text)) {
      if (m.start > i) spans.add(TextSpan(text: text.substring(i, m.start)));
      spans.add(TextSpan(text: m.group(0), style: quote));
      i = m.end;
    }
    if (i < text.length) spans.add(TextSpan(text: text.substring(i)));
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(style: base, children: spans),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.justify,
      ),
    );
  }
}

class _ReferenceBlock extends StatelessWidget {
  final IrabReference reference;
  final String? surahName;
  const _ReferenceBlock({required this.reference, required this.surahName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const gold = AppColors.gold;
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 2, 12, 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: BorderDirectional(
          start: BorderSide(color: gold.withValues(alpha: 0.7), width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            trn(
              'quran.irab_ref_title',
              args: [
                surahName ?? '${reference.targetSurah}',
                '${reference.targetAyah}',
              ],
            ),
            style: theme.textTheme.labelMedium?.copyWith(
              color: gold,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          _BookText(reference.targetText.trim()),
        ],
      ),
    );
  }
}

/// What this i'rab is, in the reader's language, and a way to report an
/// error. The report opens a GitHub issue on the app's public repository
/// carrying only the ayah number and an empty form - nothing about the reader.
class _OwnIrabNote extends StatelessWidget {
  final Ayah ayah;
  const _OwnIrabNote({required this.ayah});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.6,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(trn('quran.irab_own_note'), style: small),
          if (uiLanguageCode != 'ar') ...[
            const SizedBox(height: 4),
            Text(trn('quran.irab_tags_hint'), style: small),
          ],
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Tooltip(
              message: trn('quran.irab_report_hint'),
              child: TextButton.icon(
                onPressed: () => openExternalLink(
                  irabReportUrl(ayah.surahId, ayah.ayahNumber),
                ),
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: Text(trn('quran.irab_report')),
                style: TextButton.styleFrom(foregroundColor: AppColors.gold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The prefilled GitHub issue for an i'rab error in [surah]:[ayah].
String irabReportUrl(int surah, int ayah) => Uri.parse(AppConfig.irabReportUrl)
    .replace(
      queryParameters: {
        'title': 'quran.irab_report_title'.tr(args: ['$surah', '$ayah']),
        'body': 'quran.irab_report_body'.tr(),
      },
    )
    .toString();

/// `subj:nom~` -> «Subject (fāʿil) · nominative (by position)».
String irabTagLabel(String tag) {
  final parts = tag.split(':');
  final role = trn('irab_tag.${parts[0]}');
  if (parts.length < 2) return role;
  final positional = parts[1].endsWith('~');
  final c = trn('irab_case.${parts[1].replaceAll('~', '')}');
  return positional
      ? '$role · $c (${trn('irab_case.positional')})'
      : '$role · $c';
}

/// One word of our own i'rab: the mushaf word in gold, its i'rab, and any
/// second view a book gives, named.
class _OwnWord extends StatelessWidget {
  final OwnIrabWord w;
  const _OwnWord(this.w);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          w.word,
          textDirection: TextDirection.rtl,
          // The mushaf's own font: the UI font stacks the Uthmani marks and
          // «ٱلۡعَٰلَمِينَ» read «غلمين» on emulator-5554 (2026-10-06).
          style: theme.textTheme.titleLarge?.copyWith(
            fontFamily: 'KFGQPCHafs',
            letterSpacing: 0,
            color: AppColors.gold,
            height: 1.8,
          ),
        ),
        // The full Arabic text is for every reader; the short labels only
        // for a reader of the other six languages.
        if (uiLanguageCode != 'ar' && w.tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final t in w.tags)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Text(
                      irabTagLabel(t),
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
              ],
            ),
          ),
        _BookText(w.irab),
        for (final (book, text) in w.alts)
          Container(
            margin: const EdgeInsetsDirectional.only(start: 12, top: 2),
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              border: BorderDirectional(
                start: BorderSide(
                  color: AppColors.gold.withValues(alpha: 0.7),
                  width: 3,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trn('quran.irab_alt_$book'),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.gold,
                  ),
                ),
                _BookText(text),
              ],
            ),
          ),
      ],
    );
  }
}
