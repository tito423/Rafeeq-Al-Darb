/// «تشخيص التلاوة» — what actually happens on THIS phone when an ayah is
/// asked for, written out so the owner can copy it and send it.
///
/// 3.58.0 fixed the silence that came from reciters with no files at all;
/// on the owner's phone the recitation was still silent, for every reciter,
/// while the adhan played — and while the same build played on
/// emulator-5554. That is a difference in the phone, and the phone is not on
/// USB during his working hours (see the owner-availability note), so the
/// evidence has to come off the screen. This is that screen.
///
/// It checks, in order, the four things that each produce the same silence:
///   1. where the sound goes — a connected Bluetooth output takes media
///      even when it is not in anyone's ears;
///   2. the MEDIA volume — the adhan plays on the alarm stream, so a media
///      volume of zero silences the recitation and not the adhan;
///   3. every source URL, fetched directly (status, type, time, error);
///   4. the player itself — does it start, and does the position move.
library;

import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/quran_repository.dart';
import '../../../core/services/audio_failure.dart';
import '../../../core/services/ayah_audio_service.dart';
import '../../../core/services/recitation_source.dart';
import '../../downloads/data/reciters_provider.dart';
import '../../settings/presentation/screens/about_screen.dart';

class RecitationDiagnosticsScreen extends ConsumerStatefulWidget {
  const RecitationDiagnosticsScreen({super.key});

  @override
  ConsumerState<RecitationDiagnosticsScreen> createState() =>
      _RecitationDiagnosticsScreenState();
}

class _RecitationDiagnosticsScreenState
    extends ConsumerState<RecitationDiagnosticsScreen> {
  final _lines = <String>[];
  final _warnings = <String>[];
  bool _running = false;

  void _add(String line) => setState(() => _lines.add(line));

  Future<void> _run() async {
    setState(() {
      _running = true;
      _lines.clear();
      _warnings.clear();
    });
    final edition = ref.read(selectedReciterProvider);
    _add(
      'app ${AboutScreen.appVersion} · ${Platform.operatingSystem} '
      '${Platform.operatingSystemVersion}',
    );
    _add('reciter $edition');

    // 1. Where the sound goes.
    try {
      final session = await AudioSession.instance;
      final devices = await session.getDevices();
      final outs = devices.where((d) => d.isOutput).toList();
      final ins = devices.where((d) => d.isInput).toList();
      _add(
        'outputs: ${outs.map((d) => '${d.type.name}(${d.name})').join(', ')}',
      );
      _add('inputs: ${ins.map((d) => '${d.type.name}(${d.name})').join(', ')}');
      final bt = outs.where(
        (d) =>
            d.type.name.toLowerCase().contains('bluetooth') ||
            d.type.name.toLowerCase().contains('ble'),
      );
      if (bt.isNotEmpty) {
        _warnings.add('diag.bluetooth_out'.tr(args: [bt.first.name]));
      }
    } catch (e) {
      _add('devices: unreadable ($e)');
    }

    // 2. The media volume (the adhan uses the alarm stream, not this one).
    if (Platform.isAndroid) {
      try {
        final am = AndroidAudioManager();
        final v = await am.getStreamVolume(AndroidStreamType.music);
        final max = await am.getStreamMaxVolume(AndroidStreamType.music);
        final alarm = await am.getStreamVolume(AndroidStreamType.alarm);
        _add('media volume $v/$max · alarm volume $alarm');
        if (v == 0) _warnings.add('diag.volume_zero'.tr());
      } catch (e) {
        _add('volume: unreadable ($e)');
      }
    }

    // 3. Every source, fetched directly.
    final urls = RecitationSource.urlsFor(
      edition: edition,
      surah: 1,
      ayah: 1,
      globalAyah: 1,
    );
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 12),
        responseType: ResponseType.bytes,
        validateStatus: (_) => true,
        headers: {'Range': 'bytes=0-1023'},
      ),
    );
    for (final url in urls) {
      final t0 = DateTime.now();
      try {
        final r = await dio.get<List<int>>(url);
        final ms = DateTime.now().difference(t0).inMilliseconds;
        _add(
          'GET ${Uri.parse(url).host} → ${r.statusCode} '
          '${r.headers.value('content-type') ?? '?'} '
          '${r.data?.length ?? 0}B ${ms}ms',
        );
      } catch (e) {
        _add('GET ${Uri.parse(url).host} → ${AudioFailure.describe(url, e)}');
      }
    }

    // 4. The player: does it start, and does the position move?
    try {
      final repo = await ref.read(quranRepositoryProvider.future);
      final ayah = (await repo.ayahsOfSurah(1)).first;
      AudioFailure.instance.clear();
      final started = await AyahAudioService.instance.play(
        ayah,
        repo,
        edition: edition,
      );
      _add(
        'player started: $started'
        '${started ? '' : ' — ${AudioFailure.instance.last.value}'}',
      );
      if (started) {
        final p = AyahAudioService.instance.player;
        final before = p.position;
        await Future<void>.delayed(const Duration(seconds: 4));
        _add(
          'after 4s: position ${before.inMilliseconds}→'
          '${p.position.inMilliseconds}ms · ${p.processingState.name} · '
          'playing ${p.playing} · volume ${p.volume}',
        );
        await AyahAudioService.instance.stop();
        // Playing, moving, media volume up, nothing on Bluetooth — and still
        // silent on the owner's Honor. Its cause was the phone's own per-app
        // volume slider, at zero for this app: nothing the app can read. So
        // when everything the app CAN see is fine, say where to look.
        if (p.position > before && _warnings.isEmpty) {
          _warnings.add('diag.app_volume_hint'.tr());
        }
      }
    } catch (e) {
      _add('player: $e');
    }
    if (mounted) setState(() => _running = false);
  }

  String get _report => [..._warnings, ..._lines].join('\n');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('diag.title'.tr())),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            'diag.hint'.tr(),
            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _running ? null : _run,
            icon: _running
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_circle_outline),
            label: Text('diag.run'.tr()),
          ),
          const SizedBox(height: 12),
          for (final w in _warnings)
            Card(
              color: scheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  w,
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
            ),
          if (_lines.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              // Technical, and left to right on purpose: it is read by
              // whoever fixes it, and hosts and numbers must not reverse.
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: SelectableText(
                  _lines.join('\n'),
                  style: const TextStyle(fontSize: 12, height: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _running
                  ? null
                  : () async {
                      await Clipboard.setData(ClipboardData(text: _report));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('diag.copied'.tr())),
                      );
                    },
              icon: const Icon(Icons.copy_rounded),
              label: Text('diag.copy'.tr()),
            ),
          ],
        ],
      ),
    );
  }
}
