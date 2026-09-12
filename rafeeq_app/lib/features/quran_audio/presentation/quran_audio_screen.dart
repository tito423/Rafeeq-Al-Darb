import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/arabic_normalize.dart';
import '../../../core/utils/byte_formatter.dart';
import '../../../core/widgets/error_retry.dart';
import '../../quran/data/mushaf_data_provider.dart';
import '../data/device_audio_scanner.dart';
import '../data/quran_audio_favorites.dart';
import '../data/mp3quran_api.dart';
import '../data/quran_audio_library.dart';
import '../data/quran_audio_player.dart';
import 'reciter_screen.dart';
import 'widgets/audio_common.dart';
import 'widgets/mini_player.dart';
import '../../../core/utils/external_link.dart';

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
      length: 4,
      initialIndex: hasLibrary ? 2 : 0,
      child: Scaffold(
        appBar: AppBar(
          title: Text('quran_audio.title'.tr()),
          bottom: TabBar(
            indicatorColor: AppColors.gold,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: AppColors.gold,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700),
            labelPadding: const EdgeInsets.symmetric(horizontal: 6),
            // Four tabs on a phone: «ملفات الجهاز» was cut to «علفات الجهاز»
            // at the edge. Each label shrinks only when it has to.
            tabs: [
              _tab(Icons.record_voice_over_outlined, 'quran_audio.tab_reciters'),
              _tab(Icons.favorite_border_rounded, 'quran_audio.tab_favorites'),
              _tab(Icons.folder_special_outlined, 'quran_audio.tab_library'),
              _tab(Icons.phone_android_rounded, 'quran_audio.tab_device'),
            ],
          ),
        ),
        bottomNavigationBar: const MiniPlayer(),
        body: const TabBarView(
          children: [_RecitersTab(), _FavoritesTab(), _LibraryTab(), _DeviceTab()],
        ),
      ),
    );
  }
}

Tab _tab(IconData icon, String key) => Tab(
      icon: Icon(icon, size: 20),
      child: FittedBox(fit: BoxFit.scaleDown, child: Text(key.tr(), maxLines: 1)),
    );

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
          onTap: () => openExternalLink('https://mp3quran.net'),
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

enum _DeviceView { all, folders, albums, artists }

class _DeviceTab extends StatefulWidget {
  const _DeviceTab();

  @override
  State<_DeviceTab> createState() => _DeviceTabState();
}

class _DeviceTabState extends State<_DeviceTab> with AutomaticKeepAliveClientMixin {
  final _lib = QuranAudioLibrary.instance;
  final _scanner = DeviceAudioScanner.instance;
  _DeviceView _view = _DeviceView.folders;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scanner.autoScanIfAllowed();
  }

  /// A scan that finds nothing used to change nothing on screen, which reads
  /// as a dead button. Say what it found.
  Future<void> _runScan() async {
    await _scanner.scan();
    if (!mounted || _scanner.denied) return;
    final n = _scanner.items.length;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(n == 0
          ? 'quran_audio.scan_none'.tr()
          : 'quran_audio.scan_found'.tr(args: ['$n'])),
    ));
  }

  Future<void> _addFolder() async {
    final path = await FilePicker.getDirectoryPath();
    if (path != null) await _scanner.addFolder(path);
  }

  Future<void> _import() async {
    final result = await FilePicker.pickFiles(type: FileType.audio, allowMultiple: true);
    if (result == null) return;
    final paths = [for (final f in result.files) if (f.path != null) f.path!];
    await _lib.importFiles(paths);
  }

  PlayerTrack _track(DeviceAudio a) => PlayerTrack(
        id: 'device-${a.id}',
        title: a.title,
        artist: a.artist ?? 'quran_audio.unknown_artist'.tr(),
        album: a.album,
        url: a.uri,
      );

  List<PlayerTrack> _importedTracks(List<File> files) => [
        for (final f in files)
          PlayerTrack(
            id: 'local-${p.basename(f.path)}',
            title: p.basenameWithoutExtension(f.path),
            artist: 'quran_audio.local_artist'.tr(),
            filePath: f.path,
          ),
      ];

  Map<String, List<DeviceAudio>> _groups(List<DeviceAudio> all) {
    final out = <String, List<DeviceAudio>>{};
    for (final a in all) {
      final key = switch (_view) {
        _DeviceView.folders => a.folder.isEmpty ? '/' : a.folder,
        _DeviceView.albums => a.album ?? 'quran_audio.unknown_album'.tr(),
        _DeviceView.artists => a.artist ?? 'quran_audio.unknown_artist'.tr(),
        _DeviceView.all => '',
      };
      (out[key] ??= []).add(a);
    }
    return Map.fromEntries(out.entries.toList()..sort((x, y) => x.key.compareTo(y.key)));
  }

  Future<void> _play(List<PlayerTrack> tracks, [int start = 0]) async {
    final ok = await QuranAudioPlayer.instance.playQueue(tracks, start: start);
    if (!ok && mounted) showPlayFailed(context);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListenableBuilder(
      listenable: Listenable.merge([_lib, _scanner, QuranAudioPlayer.instance]),
      builder: (context, _) => FutureBuilder<List<File>>(
        future: _lib.localFiles(),
        builder: (context, snap) {
          final imported = snap.data ?? const <File>[];
          final scanned = _scanner.items;
          final player = QuranAudioPlayer.instance;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: AppColors.night,
                        ),
                        onPressed: _scanner.scanning ? null : _runScan,
                        icon: _scanner.scanning
                            ? const SizedBox(
                                width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.manage_search_rounded),
                        label: Text(scanned.isEmpty
                            ? 'quran_audio.scan_device'.tr()
                            : 'quran_audio.scan_again'.tr()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<int>(
                      tooltip: 'quran_audio.import_files'.tr(),
                      icon: const Icon(Icons.add_circle_rounded, color: AppColors.gold, size: 32),
                      onSelected: (v) => v == 0 ? _import() : _addFolder(),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 0,
                          child: ListTile(
                            leading: const Icon(Icons.audio_file_rounded),
                            title: Text('quran_audio.add_files'.tr()),
                          ),
                        ),
                        PopupMenuItem(
                          value: 1,
                          child: ListTile(
                            leading: const Icon(Icons.create_new_folder_rounded),
                            title: Text('quran_audio.add_folder'.tr()),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SwitchListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                value: _scanner.autoScan,
                title: Text('quran_audio.auto_scan'.tr(), style: const TextStyle(fontSize: 13)),
                onChanged: _scanner.setAutoScan,
              ),
              if (_scanner.denied)
                ListTile(
                  leading: const Icon(Icons.lock_outline_rounded, color: AppColors.warning),
                  title: Text('quran_audio.scan_permission'.tr(), style: const TextStyle(fontSize: 13)),
                  trailing: TextButton(
                    onPressed: _scanner.openSettings,
                    child: Text('quran_audio.open_settings'.tr()),
                  ),
                ),
              if (scanned.isNotEmpty)
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    children: [
                      for (final v in _DeviceView.values)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: ChoiceChip(
                            label: Text('quran_audio.view_${v.name}'.tr()),
                            selected: _view == v,
                            selectedColor: AppColors.gold.withValues(alpha: 0.85),
                            onSelected: (_) => setState(() => _view = v),
                          ),
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: (scanned.isEmpty && imported.isEmpty && _scanner.userFolders.isEmpty)
                    ? _Empty(icon: Icons.library_music_outlined, text: 'quran_audio.empty_device'.tr())
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(10, 4, 10, 16),
                        children: [
                          if (imported.isNotEmpty)
                            _Group(
                              icon: Icons.upload_file_rounded,
                              title: 'quran_audio.imported_group'.tr(),
                              count: imported.length,
                              onPlayAll: () => _play(_importedTracks(imported)),
                              children: [
                                for (final (i, f) in imported.indexed)
                                  ListTile(
                                    dense: true,
                                    leading: const Icon(Icons.audio_file_rounded, color: AppColors.gold),
                                    title: Text(p.basenameWithoutExtension(f.path),
                                        maxLines: 1, overflow: TextOverflow.ellipsis),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                                      onPressed: () async {
                                        if (await confirmAction(context, 'quran_audio.delete_surah_confirm'.tr())) {
                                          await _lib.deleteLocal(f);
                                        }
                                      },
                                    ),
                                    onTap: () => _play(_importedTracks(imported), i),
                                  ),
                              ],
                            ),
                          for (final folder in _scanner.userFolders.entries)
                            _Group(
                              icon: Icons.folder_special_rounded,
                              title: p.basename(folder.key),
                              count: folder.value.length,
                              onPlayAll: () => _play(_importedTracks([for (final f in folder.value) File(f)])),
                              children: [
                                for (final (i, f) in folder.value.indexed)
                                  ListTile(
                                    dense: true,
                                    leading: const Icon(Icons.music_note_rounded, color: AppColors.gold),
                                    title: Text(p.basenameWithoutExtension(f),
                                        maxLines: 1, overflow: TextOverflow.ellipsis),
                                    onTap: () => _play(_importedTracks([for (final x in folder.value) File(x)]), i),
                                  ),
                                ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.folder_off_rounded, color: AppColors.error),
                                  title: Text('quran_audio.remove_folder'.tr()),
                                  onTap: () => _scanner.removeFolder(folder.key),
                                ),
                              ],
                            ),
                          if (_view == _DeviceView.all)
                            for (final (i, a) in scanned.indexed)
                              _DeviceRow(
                                audio: a,
                                playing: player.active && player.current?.id == 'device-${a.id}',
                                onTap: () => _play([for (final x in scanned) _track(x)], i),
                              )
                          else
                            for (final e in _groups(scanned).entries)
                              _Group(
                                icon: switch (_view) {
                                  _DeviceView.folders => Icons.folder_rounded,
                                  _DeviceView.albums => Icons.album_rounded,
                                  _ => Icons.person_rounded,
                                },
                                title: e.key,
                                count: e.value.length,
                                onPlayAll: () => _play([for (final x in e.value) _track(x)]),
                                children: [
                                  for (final (i, a) in e.value.indexed)
                                    _DeviceRow(
                                      audio: a,
                                      playing: player.active && player.current?.id == 'device-${a.id}',
                                      onTap: () => _play([for (final x in e.value) _track(x)], i),
                                    ),
                                ],
                              ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Favourites ─────────────────────────────────────────────────────────────

class _FavoritesTab extends StatelessWidget {
  const _FavoritesTab();

  @override
  Widget build(BuildContext context) {
    final favs = QuranAudioFavorites.instance..ensureLoaded();
    return ListenableBuilder(
      listenable: Listenable.merge([favs, QuranAudioPlayer.instance]),
      builder: (context, _) {
        final items = favs.items;
        if (items.isEmpty) {
          return _Empty(icon: Icons.favorite_border_rounded, text: 'quran_audio.empty_favorites'.tr());
        }
        final player = QuranAudioPlayer.instance;
        return ListView(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 16),
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.night),
                onPressed: () => player.playQueue(items),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text('quran_audio.play_all'.tr()),
              ),
            ),
            const SizedBox(height: 8),
            for (final (i, t) in items.indexed)
              Card(
                margin: const EdgeInsets.only(bottom: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  leading: Icon(
                    player.active && player.current?.id == t.id
                        ? Icons.graphic_eq_rounded
                        : Icons.favorite_rounded,
                    color: AppColors.gold,
                  ),
                  title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12)),
                  trailing: IconButton(
                    tooltip: 'quran_audio.favorite_remove'.tr(),
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => favs.remove(t.id),
                  ),
                  onTap: () => player.playQueue(items, start: i),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Group extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;
  final VoidCallback onPlayAll;
  final List<Widget> children;
  const _Group({
    required this.icon,
    required this.title,
    required this.count,
    required this.onPlayAll,
    required this.children,
  });

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          leading: Icon(icon, color: AppColors.gold),
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('quran_audio.files_count'.tr(args: [ltr('$count')]),
              style: const TextStyle(fontSize: 12)),
          trailing: IconButton(
            color: AppColors.gold,
            icon: const Icon(Icons.play_circle_fill_rounded),
            onPressed: onPlayAll,
          ),
          children: children,
        ),
      );
}

class _DeviceRow extends StatelessWidget {
  final DeviceAudio audio;
  final bool playing;
  final VoidCallback onTap;
  const _DeviceRow({required this.audio, required this.playing, required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
        dense: true,
        leading: Icon(playing ? Icons.graphic_eq_rounded : Icons.music_note_rounded, color: AppColors.gold),
        title: Text(audio.title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: playing ? AppColors.gold : null, fontWeight: FontWeight.w600)),
        subtitle: Text(
          [
            audio.artist ?? 'quran_audio.unknown_artist'.tr(),
            formatClock(Duration(milliseconds: audio.durationMs)),
          ].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11),
        ),
        onTap: onTap,
      );
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
