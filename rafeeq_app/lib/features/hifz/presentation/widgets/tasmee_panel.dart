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

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/digits.dart';
import '../../../../core/utils/byte_formatter.dart';
import '../../../../core/widgets/arabic_text.dart';
import '../../data/hifz_store.dart';
import '../../data/tasmee_mic.dart';
import '../../data/tasmee_engine.dart';
import '../../../../core/services/adhan_native.dart';
import '../../../../core/services/audio_exclusive.dart';

enum _Phase { idle, recording, thinking, done }

/// True while the tasmee' microphone is open. «استمع» on the same screen
/// reads it: pressing it mid-recording played the reciter INTO the
/// microphone - on emulator-5554 (2026-09-24) the ayah played and the
/// recording ran at once, and the reciter would have passed the reader's
/// test for him.
final tasmeeRecordingProvider = StateProvider<bool>((ref) => false);

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
  final _engine = TasmeeEngine.instance;
  Timer? _cap;

  /// While recording, asks once a second whether an adhan has started. The
  /// microphone would hear it and grade the reader against the muezzin; the
  /// adhan's native player takes the audio focus, which a recorder is not
  /// told about. That recording is thrown away, as on an ayah change.
  Timer? _adhanWatch;
  String? _wavPath;

  _Phase _phase = _Phase.idle;
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
    _recordingFlag; // bind while `ref` is valid (see _recordingFlag)
    // The download lives in the engine, so it survives this panel and
    // shows here again, still running, when the reader comes back.
    _engine.downloadProgress.addListener(_onEngine);
    _engine.installed.addListener(_onEngine);
    unawaited(_engine.isInstalled());
    TasmeeMics.find(
      _recorder,
    ).then((m) => mounted ? setState(() => _mics = m) : null);
  }

  @override
  void didUpdateWidget(TasmeePanel old) {
    super.didUpdateWidget(old);
    // A new ayah mid-recording: that recording is of the OLD ayah, and
    // finishing it would mark the new one by it. Thrown away.
    if (old.ayahText != widget.ayahText && _phase == _Phase.recording) {
      unawaited(_cancelRecording());
      return;
    }
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
    if (_phase == _Phase.recording) {
      // Not ref.read here (disposed); the provider is reset on the next
      // frame so the screen that stays does not keep «استمع» disabled.
      final n = _recordingFlag;
      Future.microtask(() => n.state = false);
    }
    _cap?.cancel();
    _adhanWatch?.cancel();
    _amp?.cancel();
    _recorder.dispose();
    // Never leave the phone on the call route behind a closed screen.
    unawaited(restoreAudioRoute());
    _engine.downloadProgress.removeListener(_onEngine);
    _engine.installed.removeListener(_onEngine);
    // The download is NOT cancelled here: it belongs to the engine.
    super.dispose();
  }

  void _onEngine() {
    if (mounted) setState(() {});
  }

  Future<void> _download() async {
    setState(() => _error = null);
    try {
      await _engine.startDownload();
    } on DioException catch (e) {
      if (e.type != DioExceptionType.cancel && mounted) {
        setState(() => _error = '$e');
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _startRecording() async {
    // The reciter must be silent while the reader recites: the microphone
    // would hear him, and taking the audio focus left «استمع» waiting.
    // Everything, not only a queued ayah: a continuous recitation (with
    // its listeners), the Qur'an player and the book reader were left
    // sounding into the microphone (`AudioExclusive`).
    await AudioExclusive.silenceAll();
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
    _adhanWatch?.cancel();
    _adhanWatch = Timer.periodic(const Duration(seconds: 1), (_) async {
      if ((await AdhanNative.state()).playing) await _cancelRecording();
    });
    _setRecording(true);
    setState(() {
      _phase = _Phase.recording;
      _error = null;
      _result = null;
    });
  }

  /// Mic closed, recording discarded, nothing marked.
  Future<void> _cancelRecording() async {
    if (_phase != _Phase.recording) return;
    _cap?.cancel();
    _adhanWatch?.cancel();
    await _recorder.stop();
    await _amp?.cancel();
    _amp = null;
    _level = 0;
    await restoreAudioRoute();
    _setRecording(false);
    if (mounted) setState(() => _phase = _Phase.idle);
  }

  /// Held from initState: `ref` is not usable once dispose has begun.
  late final StateController<bool> _recordingFlag =
      ref.read(tasmeeRecordingProvider.notifier);

  void _setRecording(bool on) {
    if (!mounted) return;
    _recordingFlag.state = on;
  }

  Future<void> _stopRecording() async {
    if (_phase != _Phase.recording) return;
    _setRecording(false);
    setState(() => _phase = _Phase.thinking);
    _cap?.cancel();
    _adhanWatch?.cancel();
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
    final installed = _engine.installed.value;
    final progress = _engine.downloadProgress.value;
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
            if (progress != null) ...[
              LinearProgressIndicator(value: progress, minHeight: 6),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${'downloads.downloading'.tr()}  ${percentOf(progress)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: _engine.cancelDownload,
                    child: Text('common.cancel'.tr()),
                  ),
                ],
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
                  Text(
                    'tasmee.level'.tr(),
                    style: const TextStyle(fontSize: 12),
                  ),
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
