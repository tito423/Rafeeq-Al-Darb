// `hide TextDirection`: easy_localization re-exports package:intl, whose
// TextDirection collides with dart:ui's - and this file uses dart:ui's.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/db/models.dart';
import '../../../../core/db/sciences_repository.dart';
import '../../../../core/services/quran_translation_store.dart';
import '../../../../core/utils/arabic_normalize.dart';
import '../../../../core/utils/digits.dart';
import '../../data/basmala.dart';
import '../../data/quran_translation_catalog.dart';
import '../../data/tafseer_source_provider.dart';
import '../../data/translation_lang_provider.dart';
import 'ayah_sciences/irab_tab.dart' show ownIrabProvider;
import 'ayah_share_card.dart';

/// What the reader can send with the ayah (owner, 2026-11-10: «الآية مع
/// تفسيرها أو الآية وترجمتها أو الآية وإعرابها»).
enum _ShareWith { ayah, translation, tafseer, irab }

/// Everything that can go under this ayah, read once when the sheet opens.
/// Nothing here is made up: a part that is not on the phone is null and its
/// choice is shown switched off, with the reason.
class _ShareData {
  final ShareBody? translation;

  /// Tafsir source id -> its text for this ayah, in the catalogue's order.
  final Map<String, String> tafseer;
  final ShareBody? irab;

  /// False while the ayah-sciences pack is not downloaded.
  final bool hasPack;
  const _ShareData({
    required this.translation,
    required this.tafseer,
    required this.irab,
    required this.hasPack,
  });
}

Future<_ShareData> _load(WidgetRef ref, Ayah ayah) async {
  final s = ayah.surahId;
  final a = ayah.ayahNumber;
  final repo = await ref.read(sciencesRepositoryProvider.future);

  // The translation the reader chose in the ayah card.
  ShareBody? translation;
  final lang = ref.read(selectedTranslationLangProvider);
  final catalog = await ref
      .read(quranTranslationCatalogProvider.future)
      .catchError((_) => const <QuranTranslationInfo>[]);
  final info = catalog.where((e) => e.lang == lang).firstOrNull;
  String? text;
  if (info != null && info.bundled) {
    text = (await repo?.translationForAyah(s, a, lang))?.text;
  } else if (QuranTranslationStore.instance.isInstalled(lang)) {
    text = await QuranTranslationStore.instance.verse(lang, s, a);
  } else {
    text = (await repo?.translationForAyah(s, a, lang))?.text;
  }
  if (text != null && text.trim().isNotEmpty) {
    translation = ShareBody(
      title: info?.nativeName ?? lang,
      text: text,
      direction: (info?.isRtl ?? false) ? TextDirection.rtl : TextDirection.ltr,
    );
  }

  final raw = await repo?.tafseerForAyah(s, a) ?? const <String, String>{};
  final tafseer = {
    for (final id in SciencesRepository.tafseerSources.keys)
      if ((raw[id] ?? '').trim().isNotEmpty) id: raw[id]!,
  };

  // Our own word-by-word i'rab where the surah has been written; else the
  // book's section when it parses this ayah alone. A section that runs over
  // several ayahs is not offered: it would say more than this ayah.
  ShareBody? irab;
  final own = (await ref.read(ownIrabProvider.future))['$s:$a'];
  if (own != null && own.isNotEmpty) {
    irab = ShareBody(
      title: 'quran.irab'.tr(),
      text: [for (final w in own) '«${w.word}»: ${w.irab}'].join('\n'),
      markQuotes: true,
    );
  } else {
    final section = await repo?.irabForAyah(s, a);
    if (section != null && section.ayahFrom == section.ayahTo) {
      irab = ShareBody(
        title: 'quran.irab_book'.tr(),
        text: section.text,
        markQuotes: true,
      );
    }
  }

  return _ShareData(
    translation: translation,
    tafseer: tafseer,
    irab: irab,
    hasPack: repo != null,
  );
}

/// The share options for one ayah.
Future<void> showAyahShareSheet(
  BuildContext context, {
  required Ayah ayah,
  required String surahNameAr,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _AyahShareSheet(ayah: ayah, surahNameAr: surahNameAr),
  );
}

class _AyahShareSheet extends ConsumerStatefulWidget {
  final Ayah ayah;
  final String surahNameAr;
  const _AyahShareSheet({required this.ayah, required this.surahNameAr});

  @override
  ConsumerState<_AyahShareSheet> createState() => _AyahShareSheetState();
}

class _AyahShareSheetState extends ConsumerState<_AyahShareSheet> {
  // Kept for the session, so the next ayah opens the way the last was sent.
  static _ShareWith _lastWith = _ShareWith.ayah;
  static ShareStyle _lastStyle = ShareStyle.night;

  late final Future<_ShareData> _data = _load(ref, widget.ayah);
  _ShareWith _with = _lastWith;
  ShareStyle _style = _lastStyle;
  static ShareFrame _lastFrame = ShareFrame.stars;
  ShareFrame _frame = _lastFrame;

  Widget _swatch(ThemeData theme, ShareStyle s) {
    final c = SharePalette.of(s);
    final on = _style == s;
    return Tooltip(
      message: 'quran.share_style_${s.name}'.tr(),
      child: Semantics(
        selected: on,
        button: true,
        label: 'quran.share_style_${s.name}'.tr(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => setState(() {
            _style = s;
            _lastStyle = s;
          }),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [c.top, c.bottom],
              ),
              border: Border.all(
                color: on ? theme.colorScheme.primary : c.gold,
                width: on ? 3.5 : 2,
              ),
            ),
            alignment: Alignment.center,
            child: on
                ? Icon(Icons.check_rounded, size: 20, color: c.gold)
                : Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: c.gold,
                      shape: BoxShape.circle,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  String? _tafseerSource;
  bool _busy = false;

  ShareContent _content(_ShareData d) {
    final ayah = widget.ayah;
    final ShareBody? body = switch (_with) {
      _ShareWith.ayah => null,
      _ShareWith.translation => d.translation,
      _ShareWith.irab => d.irab,
      _ShareWith.tafseer => () {
        final id = _source(d);
        if (id == null) return null;
        return ShareBody(
          title: SciencesRepository.tafseerSources[id] ?? id,
          text: d.tafseer[id]!,
        );
      }(),
    };
    return ShareContent(
      // The basmala that opens a surah is not part of verse 1 (al-Fatiha
      // apart), the same rule the page itself follows.
      ayahText: bodyOf(ayah),
      surahName: surahNameForDisplay(widget.surahNameAr),
      // «آية ٥٥», not «٥:٥٥»: under the surah's own name the surah number
      // adds nothing, and in Arabic-Indic digits «٥:٥٥» read as a clock
      // («0:00») on the card (seen on emulator-5554, 2026-11-13).
      reference:
          '${'quran.ayah'.tr()} '
          '${localizeDigits('${ayah.ayahNumber}', uiLanguageCode)}',
      fileTag: '${ayah.surahId}_${ayah.ayahNumber}',
      body: body,
    );
  }

  String? _source(_ShareData d) {
    if (d.tafseer.isEmpty) return null;
    final chosen = _tafseerSource ?? ref.read(selectedTafseerSourceProvider);
    return d.tafseer.containsKey(chosen) ? chosen : d.tafseer.keys.first;
  }

  bool _available(_ShareWith w, _ShareData d) => switch (w) {
    _ShareWith.ayah => true,
    _ShareWith.translation => d.translation != null,
    _ShareWith.tafseer => d.tafseer.isNotEmpty,
    _ShareWith.irab => d.irab != null,
  };

  String _whyNot(_ShareWith w, _ShareData d) {
    if (!d.hasPack && w != _ShareWith.translation) {
      return 'quran.share_needs_pack'.tr();
    }
    return switch (w) {
      _ShareWith.translation => 'quran.share_no_translation'.tr(),
      _ShareWith.irab => 'quran.share_no_irab'.tr(),
      _ => 'quran.share_needs_pack'.tr(),
    };
  }

  Future<void> _sendImages(ShareContent content) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await shareAyahAsImages(
      context,
      content: content,
      style: _style,
      frame: _frame,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(content: Text('quran.share_failed'.tr())),
      );
    }
  }

  Future<void> _sendText(ShareContent content) async {
    await SharePlus.instance.share(ShareParams(text: shareAyahText(content)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<_ShareData>(
      future: _data,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final d =
            snap.data ??
            const _ShareData(
              translation: null,
              tafseer: {},
              irab: null,
              hasPack: false,
            );
        if (!_available(_with, d)) _with = _ShareWith.ayah;
        final content = _content(d);
        final plans = planShare(content, SharePalette.of(_style));
        final tooLong = plans.length > shareMaxCards;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('quran.share_title'.tr(), style: theme.textTheme.titleLarge),
              const SizedBox(height: 10),
              for (final w in _ShareWith.values) _choice(context, w, d, theme),
              if (_with == _ShareWith.tafseer && d.tafseer.length > 1) ...[
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: _source(d),
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'quran.tafseer'.tr(),
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (final id in d.tafseer.keys)
                      DropdownMenuItem(
                        value: id,
                        child: Text(
                          SciencesRepository.tafseerSources[id] ?? id,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _tafseerSource = v),
                ),
              ],
              const SizedBox(height: 12),
              // Eight colours as swatches (ground + ornament), named for
              // a screen reader; five frames as chips. Both wrap, so a
              // narrow phone never overflows.
              Text('quran.share_style'.tr(), style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  for (final s in ShareStyle.values) _swatch(theme, s),
                ],
              ),
              const SizedBox(height: 10),
              Text('quran.share_frame'.tr(), style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final f in ShareFrame.values)
                    ChoiceChip(
                      label: Text('quran.share_frame_${f.name}'.tr()),
                      selected: _frame == f,
                      onSelected: (_) => setState(() {
                        _frame = f;
                        _lastFrame = f;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // The first card exactly as it will be sent, scaled to fit.
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: FittedBox(
                      fit: BoxFit.fitWidth,
                      child: AyahShareCard(
                        content: content,
                        plan: plans.first,
                        style: _style,
                        frame: _frame,
                        count: plans.length,
                      ),
                    ),
                  ),
                ),
              ),
              if (plans.length > 1) ...[
                const SizedBox(height: 8),
                Text(
                  tooLong
                      ? trn('quran.share_too_long', args: ['${plans.length}'])
                      : trn(
                          'quran.share_images_count',
                          args: ['${plans.length}'],
                        ),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: tooLong
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy || tooLong
                          ? null
                          : () => _sendImages(content),
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.image_outlined),
                      label: Text('quran.share_as_image'.tr()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _sendText(content),
                      icon: const Icon(Icons.notes_rounded),
                      label: Text('quran.share_as_text'.tr()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _choice(
    BuildContext context,
    _ShareWith w,
    _ShareData d,
    ThemeData theme,
  ) {
    final ok = _available(w, d);
    final (icon, label) = switch (w) {
      _ShareWith.ayah => (Icons.menu_book_rounded, 'quran.share_ayah_only'),
      _ShareWith.translation => (
        Icons.translate_rounded,
        'quran.share_with_translation',
      ),
      _ShareWith.tafseer => (
        Icons.auto_stories_rounded,
        'quran.share_with_tafseer',
      ),
      _ShareWith.irab => (Icons.account_tree_outlined, 'quran.share_with_irab'),
    };
    final detail = !ok
        ? _whyNot(w, d)
        : switch (w) {
            _ShareWith.translation => d.translation!.title,
            _ShareWith.tafseer =>
              SciencesRepository.tafseerSources[_source(d)] ?? '',
            _ => null,
          };
    final selected = _with == w;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          dense: true,
          enabled: ok,
          leading: Icon(icon),
          title: Text(label.tr()),
          subtitle: detail == null || detail.isEmpty ? null : Text(detail),
          trailing: selected ? const Icon(Icons.check_circle_rounded) : null,
          onTap: () => setState(() {
            _with = w;
            _lastWith = w;
          }),
        ),
      ),
    );
  }
}
