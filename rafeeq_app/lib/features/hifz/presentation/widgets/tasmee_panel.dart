/// «سمّع الآية»: record, recognise on the device, and mark each word of the
/// ayah as said or missed.
///
/// The panel says three true things before it says anything else: how big the
/// download is, that it then works with no internet, and that **tajweed is
/// not checked** — the recogniser hears WORDS. Promising a tajweed check
/// would be the kind of claim §1.1 forbids.
library;

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../../core/services/ayah_audio_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/digits.dart';
import '../../../../core/utils/byte_formatter.dart';
import '../../../../core/widgets/arabic_text.dart';
import '../../data/hifz_store.dart';
import '../../data/tasmee_mic.dart';
import '../../data/tasmee_engine.dart';

enum _Phase { idle, downloading, recording, thinking, done }

class TasmeePanel extends ConsumerStatefulWidget {
  final String ayahText;
  final int surahId;
  final int ayahNumber;

  /// Called when the reader recites the ayah well enough that the screen
  /// offers to mark it memorized — the offer is his to take.
  final VoidCallback? onMastered;

  const TasmeePanel({
    super.key,
    required this.ayahText,
    required this.surahId,
    required this.ayahNumber,
    this.onMastered,
  });

  @override
  ConsumerState<TasmeePanel> createState() => _TasmeePanelState();
}

class _TasmeePanelState extends ConsumerState<TasmeePanel> {
  final _recorder = AudioRecorder();
  final _dio = Dio();
  Timer? _cap;
  String? _wavPath;
  CancelToken? _cancel;

  _Phase _phase = _Phase.idle;
  bool? _installed;
  double _progress = 0;
  String? _error;
  String? _heard;
  TasmeeResult? _result;

  /// The microphones on offer; a headset is used when one is connected,
  /// unless the reader switches to the phone's own.
  TasmeeMics? _mics;
  bool _useBluetooth = true;

  /// How loud the microphone hears the reader, 0..1, while recording — the
  /// plain answer to «is it hearing me at all?», on any microphone.
  double _level = 0;
  StreamSubscription<Amplitude>? _amp;

  @override
  void initState() {
    super.initState();
    TasmeeEngine.instance.isInstalled().then(
      (v) => mounted ? setState(() => _installed = v) : null,
    );
    TasmeeMics.find(_recorder).then(
      (m) => mounted ? setState(() => _mics = m) : null,
    );
  }

  @override
  void didUpdateWidget(TasmeePanel old) {
    super.didUpdateWidget(old);
    // A new ayah: the previous result is not about it.
    if (old.ayahText != widget.ayahText && _result != null) {
      setState(() {
        _result = null;
        _heard = null;
        _phase = _Phase.idle;
      });
    }
  }

  @override
  void dispose() {
    _cap?.cancel();
    _amp?.cancel();
    _recorder.dispose();
    // Never leave the phone on the call route behind a closed screen.
    unawaited(restoreAudioRoute());
    _cancel?.cancel();
    super.dispose();
  }

  Future<void> _download() async {
    setState(() {
      _phase = _Phase.downloading;
      _error = null;
      _progress = 0;
    });
    _cancel = CancelToken();
    try {
      await TasmeeEngine.instance.download(
        dio: _dio,
        cancelToken: _cancel,
        onProgress: (p) => mounted ? setState(() => _progress = p) : null,
      );
      if (mounted) {
        setState(() {
          _installed = true;
          _phase = _Phase.idle;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _phase = _Phase.idle;
        });
      }
    }
  }

  Future<void> _startRecording() async {
    // The reciter must be silent while the reader recites: the microphone
    // would hear him, and taking the audio focus left «استمع» waiting.
    await AyahAudioService.instance.stopQueue();
    if (!await _recorder.hasPermission()) {
      if (mounted) setState(() => _error = 'tasmee.needs_mic'.tr());
      return;
    }
    // whisper.cpp reads a 16 kHz mono WAV from disk, so record straight into
    // one instead of holding the samples in memory.
    final dir = await getTemporaryDirectory();
    final path = p.join(dir.path, 'tasmee.wav');
    // A headset if one is connected and chosen, the phone's microphone
    // otherwise — named either way, so `record` never guesses. See
    // tasmee_mic.dart for why the headset needs more than `record` does.
    final mics = await TasmeeMics.find(_recorder);
    if (mounted) setState(() => _mics = mics);
    final viaBluetooth = mics.hasBluetooth && _useBluetooth;
    if (viaBluetooth) await routeTasmeeToBluetooth();
    await _recorder.start(
      RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
        device: viaBluetooth ? mics.bluetooth : mics.phone,
        // record 6 exposes what 5.x hid. A headset records the way Android
        // documents for a Bluetooth call microphone: SCO managed by the
        // plugin, the voice-communication source, the phone in communication
        // mode. The phone's own microphone asks for none of that, so a
        // paired headset cannot pull the route away from it.
        androidConfig: viaBluetooth
            ? const AndroidRecordConfig(
                manageBluetooth: true,
                audioSource: AndroidAudioSource.voiceCommunication,
                audioManagerMode: AudioManagerMode.modeInCommunication,
              )
            : const AndroidRecordConfig(manageBluetooth: false),
      ),
      path: path,
    );
    _wavPath = path;
    // -50 dBFS and below reads as nothing heard, 0 dBFS as full.
    await _amp?.cancel();
    _amp = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 150))
        .listen((a) {
      if (mounted) {
        setState(() => _level = ((a.current + 50) / 50).clamp(0.0, 1.0));
      }
    });
    // A forgotten «stop» should not record for ever.
    _cap?.cancel();
    _cap = Timer(const Duration(seconds: tasmeeMaxSeconds), _stopRecording);
    setState(() {
      _phase = _Phase.recording;
      _error = null;
      _result = null;
    });
  }

  Future<void> _stopRecording() async {
    if (_phase != _Phase.recording) return;
    setState(() => _phase = _Phase.thinking);
    _cap?.cancel();
    await _recorder.stop();
    await _amp?.cancel();
    _amp = null;
    _level = 0;
    await restoreAudioRoute();
    final path = _wavPath;
    try {
      if (path == null || !File(path).existsSync()) {
        throw StateError('nothing was recorded');
      }
      final heard = await TasmeeEngine.instance.transcribeFile(path);
      final result = TasmeeEngine.compare(
        ayahText: widget.ayahText,
        heard: heard,
        surahId: widget.surahId,
        ayahNumber: widget.ayahNumber,
      );
      // The attempt is kept per ayah (the best one), so «أفضل تسميع» means
      // something the next time this ayah comes round. It does NOT move the
      // review ladder by itself.
      await ref
          .read(hifzStoreProvider.notifier)
          .recordTasmee(
            widget.surahId,
            widget.ayahNumber,
            (result.ratio * 100).round(),
          );
      if (mounted) {
        setState(() {
          _heard = heard.trim();
          _result = result;
          _phase = _Phase.done;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _phase = _Phase.idle;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final installed = _installed;
    if (installed == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.record_voice_over_outlined,
                color: AppColors.gold,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'tasmee.title'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'tasmee.not_tajweed'.tr(),
            style: TextStyle(
              fontSize: 12,
              height: 1.6,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          if (!installed) ...[
            Text(
              trn(
                'tasmee.download_note',
                args: [formatBytes(tasmeeDownloadBytes)],
              ),
              style: TextStyle(
                fontSize: 12.5,
                height: 1.6,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            if (_phase == _Phase.downloading) ...[
              LinearProgressIndicator(value: _progress, minHeight: 6),
              const SizedBox(height: 6),
              Text(
                percentOf(_progress),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ] else
              FilledButton.icon(
                onPressed: _download,
                icon: const Icon(Icons.download_rounded),
                label: Text('tasmee.download'.tr()),
              ),
          ] else ...[
            // Which microphone — offered only when a headset is there.
            if ((_mics?.hasBluetooth ?? false) &&
                _phase != _Phase.recording) ...[
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    avatar: const Icon(Icons.headset_mic_rounded, size: 18),
                    label: Text('tasmee.mic_bluetooth'.tr()),
                    selected: _useBluetooth,
                    onSelected: (_) => setState(() => _useBluetooth = true),
                  ),
                  ChoiceChip(
                    avatar: const Icon(Icons.smartphone_rounded, size: 18),
                    label: Text('tasmee.mic_phone'.tr()),
                    selected: !_useBluetooth,
                    onSelected: (_) => setState(() => _useBluetooth = false),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (_phase == _Phase.recording) ...[
              Row(
                children: [
                  const Icon(Icons.graphic_eq_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text('tasmee.level'.tr(),
                      style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: _level,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            switch (_phase) {
              _Phase.recording => FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: _stopRecording,
                icon: const Icon(Icons.stop_rounded),
                label: Text('tasmee.stop'.tr()),
              ),
              _Phase.thinking => const Padding(
                padding: EdgeInsets.all(8),
                child: LinearProgressIndicator(minHeight: 6),
              ),
              _ => FilledButton.icon(
                onPressed: _startRecording,
                icon: const Icon(Icons.mic_rounded),
                label: Text('tasmee.start'.tr()),
              ),
            },
            if (_result case final r?) ...[
              const SizedBox(height: 12),
              Text(
                trn('tasmee.result', args: ['${r.matched}', '${r.total}']),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: r.ratio >= 0.9
                      ? Colors.green.shade700
                      : scheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              // Every word of the ayah, the missed ones marked. The ayah
              // itself is never altered — only its colour.
              Directionality(
                textDirection: TextDirection.rtl,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < r.words.length; i++)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: r.heardWord[i]
                              ? Colors.green.withValues(alpha: 0.12)
                              : Colors.red.withValues(alpha: 0.12),
                        ),
                        child: ArabicText(
                          r.words[i],
                          style: TextStyle(
                            fontFamily: 'AmiriQuran',
                            fontSize: 19,
                            height: 1.8,
                            color: r.heardWord[i] ? null : Colors.red.shade700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (_heard case final h? when h.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'tasmee.heard'.tr(),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                ArabicText(
                  h,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.8,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (r.ratio >= 0.9 && widget.onMastered != null) ...[
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: widget.onMastered,
                  icon: const Icon(Icons.verified_rounded, size: 18),
                  label: Text('tasmee.mark_memorized'.tr()),
                ),
              ],
            ],
            if (ref
                    .watch(hifzStoreProvider.notifier)
                    .bestTasmee(widget.surahId, widget.ayahNumber)
                case final best when best >= 0 && _result == null) ...[
              const SizedBox(height: 8),
              Text(
                trn('tasmee.best', args: ['$best']),
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ],
          if (_error case final e?) ...[
            const SizedBox(height: 8),
            Text(
              e,
              style: TextStyle(fontSize: 12, color: scheme.error),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
