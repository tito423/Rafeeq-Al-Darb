import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/arabic_normalize.dart';
import '../../../core/utils/byte_formatter.dart';
import '../../../core/widgets/error_retry.dart';
import '../../quran/data/mushaf_data_provider.dart';
import '../data/mp3quran_api.dart';
import '../data/quran_audio_library.dart';
import '../data/quran_audio_player.dart';
import 'reciter_screen.dart';
import 'widgets/audio_common.dart';
import 'widgets/mini_player.dart';

/// «تحميل تلاوات القرآن» — the reciters of mp3quran.net, what is on the
/// device (a folder per reciter, a sub-folder per recitation), and audio files
/// from the phone itself, all playing in one player.
class QuranAudioScreen extends StatefulWidget {
  const QuranAudioScreen({super.key});

  @override
  State<QuranAudioScreen> createState() => _QuranAudioScreenState();
}

class _QuranAudioScreenState extends State<QuranAudioScreen> {
  @override
  void initState() {
    super.initState();
    QuranAudioLibrary.instance.ensureReady();
  }

  @override
  Widget build(BuildContext context) {
    final hasLibrary = QuranAudioLibrary.instance.entries.isNotEmpty;
    return DefaultTabController(
      length: 3,
      initialIndex: hasLibrary ? 1 : 0,
      child: Scaffold(
        appBar: AppBar(
          title: Text('quran_audio.title'.tr()),
          bottom: TabBar(
            indicatorColor: AppColors.gold,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: AppColors.gold,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700),
            tabs: [
              Tab(icon: const Icon(Icons.record_voice_over_outlined, size: 20), text: 'quran_audio.tab_reciters'.tr()),
              Tab(icon: const Icon(Icons.folder_special_outlined, size: 20), text: 'quran_audio.tab_library'.tr()),
              Tab(icon: const Icon(Icons.phone_android_rounded, size: 20), text: 'quran_audio.tab_device'.tr()),
            ],
          ),
        ),
        bottomNavigationBar: const MiniPlayer(),
        body: const TabBarView(
          children: [_RecitersTab(), _LibraryTab(), _DeviceTab()],
        ),
      ),
    );
  }
}

// ── Reciters ───────────────────────────────────────────────────────────────

class _RecitersTab extends ConsumerStatefulWidget {
  const _RecitersTab();

  @override
  ConsumerState<_RecitersTab> createState() => _RecitersTabState();
}

class _RecitersTabState extends ConsumerState<_RecitersTab>
    with AutomaticKeepAliveClientMixin {
  String _query = '';

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final async = ref.watch(mp3RecitersProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('quran_audio.load_failed'.tr(), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ErrorRetry(onRetry: () => ref.invalidate(mp3RecitersProvider)),
            ],
          ),
        ),
      ),
      data: (all) {
        final q = normalizeArabic(_query.trim().toLowerCase());
        final list = q.isEmpty
            ? all
            : all.where((r) => normalizeArabic(r.name.toLowerCase()).contains(q)).toList();
        final lib = QuranAudioLibrary.instance;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'quran_audio.search'.tr(),
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: lib,
                builder: (context, _) => ListView.builder(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 16),
                  itemCount: list.length + 1,
                  itemBuilder: (context, i) {
                    if (i == list.length) return const _SourceCredit();
                    final r = list[i];
                    final onDevice = r.moshafs.where((m) => lib.downloadedCount(m.id) > 0).length;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        leading: ReciterAvatar(name: r.name, number: all.indexOf(r) + 1),
                        title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          r.moshafs.map((m) => m.name).join(' • '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (onDevice > 0)
                              const Icon(Icons.offline_pin_rounded, color: AppColors.success, size: 20),
                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ReciterScreen(reciter: r, number: all.indexOf(r) + 1),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SourceCredit extends StatelessWidget {
  const _SourceCredit();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: InkWell(
          onTap: () => launchUrl(Uri.parse('https://mp3quran.net'), mode: LaunchMode.externalApplication),
          child: Text(
            'quran_audio.source_note'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textLow, fontSize: 12),
          ),
        ),
      );
}

// ── Library: folders ───────────────────────────────────────────────────────

class _LibraryTab extends ConsumerWidget {
  const _LibraryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lib = QuranAudioLibrary.instance;
    return ListenableBuilder(
      listenable: lib,
      builder: (context, _) {
        final entries = lib.entries;
        if (entries.isEmpty) {
          return _Empty(icon: Icons.folder_open_rounded, text: 'quran_audio.empty_library'.tr());
        }
        // One folder per reciter, one sub-folder per recitation.
        final byReciter = <int, List<LibraryEntry>>{};
        for (final e in entries) {
          (byReciter[e.reciterId] ??= []).add(e);
        }
        final data = ref.watch(mushafDataProvider).valueOrNull;
        final locale = context.locale.languageCode;
        return ListView(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 16),
          children: [
            for (final group in byReciter.values)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  initiallyExpanded: byReciter.length <= 3,
                  leading: const Icon(Icons.folder_rounded, color: AppColors.gold, size: 30),
                  title: Text(group.first.reciterName, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(
                    'quran_audio.downloaded_surahs'.tr(args: [
                      ltr('${group.fold<int>(0, (n, e) => n + lib.downloadedCount(e.moshafId))}'),
                    ]),
                    style: const TextStyle(fontSize: 12),
                  ),
                  children: [
                    for (final e in group)
                      _RecitationFolder(entry: e, data: data, locale: locale),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RecitationFolder extends ConsumerWidget {
  final LibraryEntry entry;
  final MushafData? data;
  final String locale;
  const _RecitationFolder({required this.entry, required this.data, required this.locale});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lib = QuranAudioLibrary.instance;
    final done = lib.downloadedCount(entry.moshafId);
    final total = entry.moshaf.surahs.length;
    final downloading = entry.pending.isNotEmpty && !entry.paused;
    return ListTile(
      contentPadding: const EdgeInsetsDirectional.fromSTEB(28, 2, 8, 2),
      leading: Icon(
        downloading ? Icons.downloading_rounded : Icons.library_music_rounded,
        color: downloading ? AppColors.gold : AppColors.goldSoft,
      ),
      title: Text(entry.moshaf.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('quran_audio.downloaded_of'.tr(args: [ltr('$done'), ltr('$total')]),
              style: const TextStyle(fontSize: 12)),
          if (entry.pending.isNotEmpty) ...[
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: total == 0 ? 0 : done / total,
              minHeight: 4,
              color: entry.paused ? AppColors.textLow : AppColors.gold,
              backgroundColor: AppColors.nightBorder,
            ),
          ],
        ],
      ),
      trailing: IconButton(
        color: AppColors.gold,
        iconSize: 32,
        icon: const Icon(Icons.play_circle_fill_rounded),
        onPressed: done == 0
            ? null
            : () async {
                final ok = await QuranAudioPlayer.instance.playQueue(recitationTracks(
                  reciterName: entry.reciterName,
                  moshaf: entry.moshaf,
                  data: data,
                  locale: locale,
                  downloadedOnly: true,
                ));
                if (!ok && context.mounted) showPlayFailed(context);
              },
      ),
      onTap: () {
        // The whole reciter if the catalogue is loaded, so his other
        // recitations are one tap away; this one alone when offline.
        final reciters = ref.read(mp3RecitersProvider).valueOrNull;
        final full = reciters?.where((r) => r.id == entry.reciterId).firstOrNull;
        final reciter = full != null && full.moshafs.any((m) => m.id == entry.moshafId)
            ? full
            : Mp3Reciter(id: entry.reciterId, name: entry.reciterName, moshafs: [entry.moshaf]);
        Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => ReciterScreen(reciter: reciter, initialMoshafId: entry.moshafId),
        ));
      },
    );
  }
}

// ── Device files ───────────────────────────────────────────────────────────

class _DeviceTab extends StatefulWidget {
  const _DeviceTab();

  @override
  State<_DeviceTab> createState() => _DeviceTabState();
}

class _DeviceTabState extends State<_DeviceTab> {
  final _lib = QuranAudioLibrary.instance;

  Future<void> _import() async {
    final result = await FilePicker.pickFiles(type: FileType.audio, allowMultiple: true);
    if (result == null) return;
    final paths = [for (final f in result.files) if (f.path != null) f.path!];
    await _lib.importFiles(paths);
  }

  List<PlayerTrack> _tracks(List<File> files) => [
        for (final f in files)
          PlayerTrack(
            id: 'local-${p.basename(f.path)}',
            title: p.basenameWithoutExtension(f.path),
            artist: 'quran_audio.local_artist'.tr(),
            filePath: f.path,
          ),
      ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_lib, QuranAudioPlayer.instance]),
      builder: (context, _) => FutureBuilder<List<File>>(
        future: _lib.localFiles(),
        builder: (context, snap) {
          final files = snap.data ?? const <File>[];
          final player = QuranAudioPlayer.instance;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _import,
                        icon: const Icon(Icons.add_rounded),
                        label: Text('quran_audio.import_files'.tr()),
                      ),
                    ),
                    if (files.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: AppColors.night,
                        ),
                        onPressed: () => player.playQueue(_tracks(files)),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text('quran_audio.play_all'.tr()),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: files.isEmpty
                    ? _Empty(icon: Icons.audio_file_outlined, text: 'quran_audio.empty_device'.tr())
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(10, 4, 10, 16),
                        itemCount: files.length,
                        itemBuilder: (context, i) {
                          final f = files[i];
                          final playing = player.active && player.current?.id == 'local-${p.basename(f.path)}';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            child: ListTile(
                              leading: Icon(
                                playing ? Icons.graphic_eq_rounded : Icons.audio_file_rounded,
                                color: AppColors.gold,
                              ),
                              title: Text(p.basenameWithoutExtension(f.path),
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                              subtitle: Text(formatBytes(f.lengthSync()), style: const TextStyle(fontSize: 12)),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                                onPressed: () async {
                                  if (await confirmAction(context, 'quran_audio.delete_surah_confirm'.tr())) {
                                    await _lib.deleteLocal(f);
                                  }
                                },
                              ),
                              onTap: () => player.playQueue(_tracks(files), start: i),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Empty({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: AppColors.gold.withValues(alpha: 0.6)),
              const SizedBox(height: 14),
              Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMedium, height: 1.6)),
            ],
          ),
        ),
      );
}
