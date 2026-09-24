import 'dart:async';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/recitation_source.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/byte_formatter.dart' show formatBytes;
import '../../../../core/utils/digits.dart' show trn;
import '../../../downloads/data/reciters_provider.dart';
import '../../../hifz/data/tasmee_engine.dart';
import '../../../library/data/tts/open_voice.dart';
import '../../../quran_audio/data/ayah_recitation_library.dart';
import '../../../quran_audio/data/mp3quran_api.dart';
import '../../../quran_audio/data/quran_audio_library.dart';
import '../../data/offline_pack_sizes.dart';
import 'offline_pack_row.dart';

/// How fast one reciter's host answered a 1 KB range request for al-Fatiha
/// 1:1, measured when the page opens. Null: it did not answer.
class _Probe {
  final Reciter reciter;
  final int bytes;
  final int? ms;
  const _Probe(this.reciter, this.bytes, this.ms);
}

/// «تلاوة آية بآية»: pick a reciter, see his full measured size, download
/// all 6,236 ayahs through [AyahRecitationLibrary] - the same job the
/// Downloads screen runs.
///
/// PLAN.md: offer the reciters whose hosts answered fastest, show the full
/// size, recommend the smallest. Each reciter's own first-choice URL (R2
/// where mirrored, everyayah otherwise) is asked for its first KB; the ones
/// that answered are listed smallest first, each with the time it took, and
/// the smallest is the recommendation. Downloading one also makes it the
/// reciter the app plays - a downloaded voice the player never uses would be
/// 400 MB spent for nothing.
class AyahReciterPackTile extends ConsumerStatefulWidget {
  const AyahReciterPackTile({super.key});

  @override
  ConsumerState<AyahReciterPackTile> createState() =>
      _AyahReciterPackTileState();
}

class _AyahReciterPackTileState extends ConsumerState<AyahReciterPackTile> {
  final _lib = AyahRecitationLibrary.instance;
  List<_Probe>? _probes;

  @override
  void initState() {
    super.initState();
    _lib.addListener(_changed);
    unawaited(_lib.ensureReady().then((_) => _changed()));
    unawaited(_probe());
  }

  @override
  void dispose() {
    _lib.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _probe() async {
    final sizes = await ref.read(offlinePackSizesProvider.future);
    final reciters = await ref.read(recitersProvider.future);
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 6),
      responseType: ResponseType.bytes,
      headers: {'Range': 'bytes=0-1023'},
    ));
    final probes = await Future.wait([
      for (final r in reciters)
        if (sizes.ayahReciters[r.identifier] != null)
          () async {
            final sw = Stopwatch()..start();
            try {
              final res = await dio.get<List<int>>(RecitationSource.primaryUrl(
                edition: r.identifier,
                surah: 1,
                ayah: 1,
                globalAyah: 1,
              ));
              final ok = (res.statusCode == 206 || res.statusCode == 200) &&
                  (res.data?.isNotEmpty ?? false);
              return _Probe(r, sizes.ayahReciters[r.identifier]!,
                  ok ? sw.elapsedMilliseconds : null);
            } catch (_) {
              return _Probe(r, sizes.ayahReciters[r.identifier]!, null);
            }
          }(),
    ]);
    final answered = [
      for (final p in probes)
        if (p.ms != null) p,
    ]..sort((a, b) => a.bytes.compareTo(b.bytes));
    if (!mounted) return;
    setState(() => _probes = answered);
    if (answered.isNotEmpty &&
        ref.read(onboardingAyahChoiceProvider) == null) {
      ref.read(onboardingAyahChoiceProvider.notifier).state =
          answered.first.reciter.identifier;
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.languageCode;
    final probes = _probes;
    final choice = ref.watch(onboardingAyahChoiceProvider);
    final chosen =
        probes?.where((p) => p.reciter.identifier == choice).firstOrNull;

    if (probes == null || chosen == null) {
      return OfflinePackRow(
        icon: Icons.record_voice_over_outlined,
        title: 'onboarding.ayah_title'.tr(),
        hint: probes == null
            ? 'onboarding.probing'.tr()
            : 'onboarding.no_host'.tr(),
        state: probes == null ? PackState.measuring : PackState.idle,
      );
    }

    final progress = _lib.progressOf(chosen.reciter.identifier);
    final entry = _lib.entries
        .where((e) => e.edition == chosen.reciter.identifier)
        .firstOrNull;
    final busy = !progress.isComplete &&
        entry != null &&
        entry.pendingSurahs.isNotEmpty &&
        !entry.paused;

    return OfflinePackRow(
      icon: Icons.record_voice_over_outlined,
      title: 'onboarding.ayah_title'.tr(),
      hint: trn('onboarding.ayah_hint', args: [
        chosen.reciter.displayName(locale),
        formatBytes(chosen.bytes),
      ]),
      state: PackState(
        done: progress.isComplete,
        busy: busy,
        progress: progress.fraction,
      ),
      footer: busy || progress.isComplete
          ? null
          : _ChangeButton(onPressed: () => _pick(context, probes, locale)),
      onDownload: () async {
        await ref
            .read(selectedReciterProvider.notifier)
            .select(chosen.reciter.identifier);
        await _lib.downloadReciter(chosen.reciter.identifier);
      },
      onCancel: () => _lib.cancel(chosen.reciter.identifier),
    );
  }

  Future<void> _pick(
      BuildContext context, List<_Probe> probes, String locale) async {
    final fastest = probes.reduce((a, b) => a.ms! <= b.ms! ? a : b);
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('onboarding.pick_reciter'.tr(),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            for (final p in probes)
              ListTile(
                title: Text(p.reciter.displayName(locale)),
                subtitle: Text([
                  formatBytes(p.bytes),
                  trn('onboarding.response_ms', args: ['${p.ms}']),
                  if (identical(p, probes.first))
                    'onboarding.recommended'.tr(),
                  if (identical(p, fastest)) 'onboarding.fastest'.tr(),
                ].join(' · ')),
                trailing: p.reciter.identifier ==
                        ref.read(onboardingAyahChoiceProvider)
                    ? const Icon(Icons.check_rounded, color: AppColors.gold)
                    : null,
                onTap: () => Navigator.of(ctx).pop(p.reciter.identifier),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      ref.read(onboardingAyahChoiceProvider.notifier).state = picked;
    }
  }
}

/// «التلاوة الكاملة»: the whole recitations mirrored on the app's own
/// bucket (`Mp3Moshaf.r2Mirrors`), downloaded surah by surah through
/// [QuranAudioLibrary] - the «تحميل تلاوات القرآن» job. The smaller one is
/// recommended; both sizes were summed from the bucket's own listing.
class SurahRecitationPackTile extends ConsumerStatefulWidget {
  const SurahRecitationPackTile({super.key});

  @override
  ConsumerState<SurahRecitationPackTile> createState() =>
      _SurahRecitationPackTileState();
}

class _SurahRecitationPackTileState
    extends ConsumerState<SurahRecitationPackTile> {
  final _lib = QuranAudioLibrary.instance;

  /// moshaf id -> (reciter, moshaf) from mp3quran's own catalogue, so the
  /// name shown is the source's, not one typed here.
  Map<int, (Mp3Reciter, Mp3Moshaf)>? _options;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _lib.addListener(_changed);
    unawaited(_lib.ensureReady().then((_) => _changed()));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_options == null && !_failed) unawaited(_load());
  }

  @override
  void dispose() {
    _lib.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final locale = context.locale.languageCode;
    try {
      final sizes = await ref.read(offlinePackSizesProvider.future);
      final reciters = await Mp3QuranApi.reciters(locale);
      final out = <int, (Mp3Reciter, Mp3Moshaf)>{};
      for (final r in reciters) {
        for (final m in r.moshafs) {
          if (Mp3Moshaf.r2Mirrors.containsKey(m.id) &&
              sizes.surahRecitations.containsKey(m.id)) {
            out[m.id] = (r, m);
          }
        }
      }
      if (!mounted) return;
      setState(() => _options = out);
      if (out.isNotEmpty && ref.read(onboardingSurahChoiceProvider) == null) {
        final smallest = out.keys.reduce((a, b) =>
            sizes.surahRecitations[a]! <= sizes.surahRecitations[b]! ? a : b);
        ref.read(onboardingSurahChoiceProvider.notifier).state = smallest;
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sizes = ref.watch(offlinePackSizesProvider).valueOrNull;
    final options = _options;
    final choice = ref.watch(onboardingSurahChoiceProvider);
    final chosen = options?[choice];
    if (sizes == null || options == null || chosen == null) {
      return OfflinePackRow(
        icon: Icons.headphones_outlined,
        title: 'onboarding.surah_title'.tr(),
        hint: _failed ? 'onboarding.no_host'.tr() : 'onboarding.probing'.tr(),
        state: _failed ? PackState.idle : PackState.measuring,
        onDownload: _failed
            ? () {
                setState(() => _failed = false);
                unawaited(_load());
              }
            : null,
      );
    }
    final (reciter, moshaf) = chosen;
    final bytes = sizes.surahRecitations[moshaf.id]!;
    final have = _lib.downloadedCount(moshaf.id);
    final total = moshaf.surahs.length;
    final entry =
        _lib.entries.where((e) => e.moshafId == moshaf.id).firstOrNull;
    final done = have >= total;
    final busy = !done &&
        entry != null &&
        entry.pending.isNotEmpty &&
        !entry.paused;
    final smallest = options.keys.reduce((a, b) =>
        sizes.surahRecitations[a]! <= sizes.surahRecitations[b]! ? a : b);

    return OfflinePackRow(
      icon: Icons.headphones_outlined,
      title: 'onboarding.surah_title'.tr(),
      hint: trn('onboarding.surah_hint', args: [
        reciter.name,
        formatBytes(bytes),
      ]),
      state: PackState(done: done, busy: busy, progress: have / total),
      footer: busy || done || options.length < 2
          ? null
          : _ChangeButton(
              onPressed: () => _pick(context, options, sizes, smallest)),
      onDownload: () => _lib.download(reciter, moshaf),
      onCancel: () => _lib.cancel(moshaf.id),
    );
  }

  Future<void> _pick(
    BuildContext context,
    Map<int, (Mp3Reciter, Mp3Moshaf)> options,
    OfflinePackSizes sizes,
    int smallest,
  ) async {
    final ids = options.keys.toList()
      ..sort((a, b) =>
          sizes.surahRecitations[a]!.compareTo(sizes.surahRecitations[b]!));
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final id in ids)
              ListTile(
                title: Text(options[id]!.$1.name),
                subtitle: Text([
                  options[id]!.$2.name,
                  formatBytes(sizes.surahRecitations[id]!),
                  if (id == smallest) 'onboarding.recommended'.tr(),
                ].join(' · ')),
                trailing: id == ref.read(onboardingSurahChoiceProvider)
                    ? const Icon(Icons.check_rounded, color: AppColors.gold)
                    : null,
                onTap: () => Navigator.of(ctx).pop(id),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      ref.read(onboardingSurahChoiceProvider.notifier).state = picked;
    }
  }
}

/// «نموذج التسميع»: the Quran-tuned whisper-tiny model, through
/// [TasmeeEngine.startDownload] - byte count and SHA-256 checked before it
/// counts as installed. The state is the engine's, so this row and the
/// tasmee panel show the same download.
class TasmeePackTile extends StatefulWidget {
  const TasmeePackTile({super.key});

  @override
  State<TasmeePackTile> createState() => _TasmeePackTileState();
}

class _TasmeePackTileState extends State<TasmeePackTile> {
  final _engine = TasmeeEngine.instance;

  @override
  void initState() {
    super.initState();
    unawaited(_engine.isInstalled());
  }

  Future<void> _download() async {
    try {
      await _engine.startDownload();
    } catch (_) {
      // Cancelled or failed: the row goes back to its download button.
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable:
            Listenable.merge([_engine.downloadProgress, _engine.installed]),
        builder: (context, _) => OfflinePackRow(
          icon: Icons.mic_none_rounded,
          title: 'onboarding.tasmee_title'.tr(),
          hint: trn('onboarding.tasmee_hint',
              args: [formatBytes(tasmeeDownloadBytes)]),
          state: PackState(
            done: _engine.installed.value == true,
            busy: _engine.downloadProgress.value != null,
            progress: _engine.downloadProgress.value,
          ),
          onDownload: _download,
          onCancel: _engine.cancelDownload,
        ),
      );
}

/// «صوت قارئ الكتب المحسّن»: the open Arabic TTS voice, through
/// [OpenVoice.install] - a WorkManager download that survives leaving the
/// app, its state shared with the reader's own offer.
class VoicePackTile extends StatefulWidget {
  const VoicePackTile({super.key});

  @override
  State<VoicePackTile> createState() => _VoicePackTileState();
}

class _VoicePackTileState extends State<VoicePackTile> {
  @override
  void initState() {
    super.initState();
    unawaited(OpenVoice.isInstalled());
  }

  Future<void> _download() async {
    try {
      await OpenVoice.install(null);
    } catch (_) {
      // Cancelled or failed: the row goes back to its download button.
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable:
            Listenable.merge([OpenVoice.installProgress, OpenVoice.installed]),
        builder: (context, _) => OfflinePackRow(
          icon: Icons.menu_book_outlined,
          title: 'onboarding.voice_title'.tr(),
          hint: trn('onboarding.voice_hint',
              args: [formatBytes(OpenVoice.totalBytes)]),
          state: PackState(
            done: OpenVoice.installed.value == true,
            busy: OpenVoice.installProgress.value != null,
            progress: OpenVoice.installProgress.value,
          ),
          onDownload: _download,
          onCancel: OpenVoice.cancelInstall,
        ),
      );
}

class _ChangeButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _ChangeButton({required this.onPressed});

  @override
  Widget build(BuildContext context) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            foregroundColor: AppColors.gold,
          ),
          onPressed: onPressed,
          icon: const Icon(Icons.swap_horiz_rounded, size: 18),
          label: Text('onboarding.change'.tr()),
        ),
      );
}
