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

import '../../../core/utils/user_error.dart';
import '../../../core/db/models.dart';
import '../../../core/db/quran_repository.dart';
import '../../../core/services/audio_failure.dart';
import '../../../core/services/ayah_audio_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/arabic_normalize.dart' show surahNamePlain;
import '../../../core/widgets/recitation_failure_snackbar.dart';
import '../../../core/utils/digits.dart';
import '../../../core/widgets/arabic_text.dart';
import '../../quran/data/basmala.dart';
import '../data/hifz_mask.dart';
import '../data/hifz_plans.dart';
import '../../downloads/data/reciters_provider.dart';
import '../../quran/presentation/widgets/reciter_picker_sheet.dart';
import 'widgets/hifz_navigator.dart';
import 'widgets/tasmee_panel.dart';
import '../data/hifz_store.dart';

class HifzSessionScreen extends ConsumerStatefulWidget {
  /// The stretch being worked through, ends included — a whole surah from
  /// the surah list, or any range the reader chose under «حفظي».
  final AyahRef from;
  final AyahRef to;

  /// What the app bar says: the surah's name, or the plan's.
  final String title;

  /// Every ayah of the range from its start, not only the due ones - what a
  /// jump to a chosen ayah means.
  final bool allAyahs;

  const HifzSessionScreen({
    super.key,
    required this.from,
    required this.to,
    required this.title,
    this.allAyahs = false,
  });

  /// The whole of [surah], as the surah list opens it.
  factory HifzSessionScreen.surah(Surah surah, {Key? key}) => HifzSessionScreen(
    key: key,
    from: AyahRef(surah.id, 1),
    to: AyahRef(surah.id, surah.ayahsCount),
    title: surahNamePlain(surah.nameAr),
  );

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

  /// Every surah, for the navigator above the ayah.
  List<Surah> _surahs = const [];

  /// The app bar's title once the reader has moved to another surah here.
  String? _titleOverride;

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
      final surahs = await repo.surahs();
      final names = {for (final s in surahs) s.id: surahNamePlain(s.nameAr)};
      final all = <Ayah>[
        for (var s = widget.from.surah; s <= widget.to.surah; s++)
          for (final a in await repo.ayahsOfSurah(s))
            if (widget.from <= AyahRef(a.surahId, a.ayahNumber) &&
                AyahRef(a.surahId, a.ayahNumber) <= widget.to)
              a,
      ];
      // Due ayahs first; when nothing in the range is due, the whole range.
      final store = ref.read(hifzStoreProvider);
      final list = widget.allAyahs
          ? all
          : all.where((a) => store.isDue(a.surahId, a.ayahNumber)).toList();
      if (mounted) {
        setState(() {
          _surahs = surahs;
          _surahNames = names;
          _ayahs = list.isEmpty ? all : list;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = userErrorText(e));
    }
  }

  Future<void> _play(Ayah ayah) async {
    final repo = await ref.read(quranRepositoryProvider.future);
    if (!mounted) return;
    setState(() => _playing = true);
    // Cleared first so what is read afterwards belongs to THIS press. A
    // «استمع» that plays nothing used to leave the button on «إيقاف» and say
    // nothing at all — the owner reported exactly that, and there was no way
    // to tell a blocked host from a broken button.
    AudioFailure.instance.clear();
    try {
      await AyahAudioService.instance.playRepeated(
        ayah,
        repo,
        times: _repeats,
        gap: const Duration(milliseconds: 600),
        // The reader's own reciter, not always al-Minshawi.
        edition: ref.read(selectedReciterProvider),
        title: '$_name — ${ayah.ayahNumber}',
      );
    } finally {
      if (mounted) setState(() => _playing = false);
    }
    if (mounted && AudioFailure.instance.last.value != null) {
      showRecitationFailure(context);
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

  String get _name => _titleOverride ?? widget.title;

  /// One ayah back or forward within the session — the swipe.
  void _step1(int delta) {
    final list = _ayahs!;
    final to = _at + delta;
    if (to < 0 || to >= list.length) return;
    AyahAudioService.instance.stopQueue();
    setState(() {
      _at = to;
      _step = 0;
    });
  }

  /// To any surah and ayah, here, without leaving the screen: inside the
  /// current stretch if it holds that ayah, otherwise the whole of the
  /// chosen surah, opened at it.
  Future<void> _goTo(int surah, int ayah) async {
    AyahAudioService.instance.stopQueue();
    final list = _ayahs!;
    final i = list.indexWhere(
      (a) => a.surahId == surah && a.ayahNumber == ayah,
    );
    if (i >= 0) {
      setState(() {
        _at = i;
        _step = 0;
      });
      return;
    }
    final repo = await ref.read(quranRepositoryProvider.future);
    final all = await repo.ayahsOfSurah(surah);
    if (!mounted || all.isEmpty) return;
    setState(() {
      _ayahs = all;
      _at = (ayah - 1).clamp(0, all.length - 1);
      _step = 0;
      _titleOverride = _surahNames[surah];
    });
  }

  String _reciterName() {
    final id = ref.watch(selectedReciterProvider);
    final list = ref.watch(recitersProvider).valueOrNull;
    final r = list?.where((x) => x.identifier == id).firstOrNull;
    return r?.displayName(context.locale.languageCode) ?? id;
  }

  /// Surah names, for a range that crosses from one surah into the next.
  Map<int, String> _surahNames = const {};
  bool get _crossesSurahs {
    final list = _ayahs;
    return list != null &&
        list.isNotEmpty &&
        list.first.surahId != list.last.surahId;
  }

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
        // No «اختر السورة والآية» button here any more: it opened a sheet
        // with a surah list, an ayah list and «ابدأ من هنا» - every one of
        // which HifzNavigator already offers above the ayah, plus a number
        // box and a slider. «الزرار اللي فوق على الشمال معدش له لازمة»
        // (2026-09-24).
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
      // BUILT ONCE, NOT LAZILY.
      //
      // «بتعلق كدة ثانية في النص قبل ماتنزل تحت او تطلع فوق» (2026-09-24,
      // with a screen recording). This was a ListView, which throws away
      // whatever scrolls off and builds it again when it comes back - so
      // mid-fling it rebuilt HifzNavigator (two DropdownMenus measuring 114
      // surahs and up to 286 ayahs) going up, and TasmeePanel (a recorder,
      // a platform call listing microphones, and on the way out an
      // audio-route reset) going down. Measured: the owner's video froze 7
      // times for 193-258 ms mid-scroll; emulator-5554 at font 1.3 on 2:255
      // froze twice for 911 and 1019 ms in 12 flings. The page is about two
      // screens long, so it is laid out once and only scrolled.
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_surahs.isNotEmpty) ...[
              HifzNavigator(
                surahs: _surahs,
                surah: ayah.surahId,
                ayah: ayah.ayahNumber,
                onGo: _goTo,
              ),
              const SizedBox(height: 12),
            ],
            Text(
              [
                if (_crossesSurahs) _surahNames[ayah.surahId] ?? '',
                trn(
                  'hifz.ayah_of',
                  args: ['${ayah.ayahNumber}', '${list.length - _at}'],
                ),
              ].where((t) => t.isNotEmpty).join(' — '),
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (basmala != null) ...[
              Center(
                child: ArabicText(
                  basmala,
                  style: const TextStyle(
                    fontFamily: 'KFGQPCHafs',
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            // The ayah, with the hidden words covered — never altered. It
            // follows the finger: drag it sideways to the next or last ayah.
            SwipeableAyah(
              onNext: _at + 1 < list.length ? () => _step1(1) : null,
              onPrev: _at > 0 ? () => _step1(-1) : null,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.25),
                  ),
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
                    onPressed: _step == 0
                        ? null
                        : () => setState(() => _step = 0),
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
            const SizedBox(height: 6),
            // «حطلي هنا اختيار صوت القارئ سواء من الجهاز لو موجود او من النت»
            // (the owner, 2026-09-23). The same sheet as the mushaf's: a
            // reciter with ayahs downloaded is marked and plays from the device,
            // any other streams.
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: ActionChip(
                avatar: const Icon(Icons.record_voice_over_rounded, size: 18),
                label: Text(_reciterName()),
                onPressed: () async {
                  final id = await showReciterPickerSheet(context);
                  if (id == null || !mounted) return;
                  await ref.read(selectedReciterProvider.notifier).select(id);
                  setState(() {});
                },
              ),
            ),
            const SizedBox(height: 6),
            FilledButton.icon(
              // Off while the tasmee' records (tasmeeRecordingProvider).
              onPressed: ref.watch(tasmeeRecordingProvider)
                  ? null
                  : _playing
                  ? () => AyahAudioService.instance.stopQueue()
                  : () => _play(ayah),
              icon: Icon(
                _playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
              ),
              label: Text(_playing ? 'hifz.stop'.tr() : 'hifz.listen'.tr()),
            ),
            // Nothing heard? Four plain things to check.
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => showSilenceTips(context),
                icon: const Icon(Icons.hearing_disabled_outlined, size: 18),
                label: Text('diag.link'.tr()),
              ),
            ),
            const Divider(height: 28),
            // «سمّع لنفسك»: the device listens and marks the words.
            TasmeePanel(
              key: ValueKey('${ayah.surahId}:${ayah.ayahNumber}'),
              ayahText: body,
              surahId: ayah.surahId,
              ayahNumber: ayah.ayahNumber,
              // «أتقنتها»: the same step «حفظتها» takes, offered where the
              // reader just proved it — never taken for him.
              onMastered: () async {
                await ref
                    .read(hifzStoreProvider.notifier)
                    .remembered(ayah.surahId, ayah.ayahNumber);
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
                          .forgot(ayah.surahId, ayah.ayahNumber);
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
                          .remembered(ayah.surahId, ayah.ayahNumber);
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
      fontFamily: 'KFGQPCHafs',
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
