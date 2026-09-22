/// «سمّع الآية»: record, recognise on the device, and mark each word of the
/// ayah as said or missed.
///
/// The panel says three true things before it says anything else: how big the
/// download is, that it then works with no internet, and that **tajweed is
/// not checked** — the recogniser hears WORDS. Promising a tajweed check
/// would be the kind of claim §1.1 forbids.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/digits.dart';
import '../../../../core/utils/byte_formatter.dart';
import '../../../../core/widgets/arabic_text.dart';
import '../../data/tasmee_engine.dart';

enum _Phase { idle, downloading, recording, thinking, done }

class TasmeePanel extends StatefulWidget {
  final String ayahText;

  const TasmeePanel({super.key, required this.ayahText});

  @override
  State<TasmeePanel> createState() => _TasmeePanelState();
}

class _TasmeePanelState extends State<TasmeePanel> {
  final _recorder = AudioRecorder();
  final _dio = Dio();
  final _samples = <double>[];
  StreamSubscription<Uint8List>? _mic;
  CancelToken? _cancel;

  _Phase _phase = _Phase.idle;
  bool? _installed;
  double _progress = 0;
  String? _error;
  TasmeeResult? _result;

  @override
  void initState() {
    super.initState();
    TasmeeEngine.instance
        .isInstalled()
        .then((v) => mounted ? setState(() => _installed = v) : null);
  }

  @override
  void didUpdateWidget(TasmeePanel old) {
    super.didUpdateWidget(old);
    // A new ayah: the previous result is not about it.
    if (old.ayahText != widget.ayahText && _result != null) {
      setState(() {
        _result = null;
        _phase = _Phase.idle;
      });
    }
  }

  @override
  void dispose() {
    _mic?.cancel();
    _recorder.dispose();
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
    if (!await _recorder.hasPermission()) {
      if (mounted) setState(() => _error = 'tasmee.needs_mic'.tr());
      return;
    }
    _samples.clear();
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );
    _mic = stream.listen((chunk) {
      // 16-bit little-endian PCM -> float32 in [-1, 1], what the recogniser
      // takes. Stop at whisper's window rather than feed it more than it can
      // hear (see TasmeeEngine's note on the 30-second limit).
      final pcm = chunk.buffer.asInt16List(
        chunk.offsetInBytes,
        chunk.lengthInBytes ~/ 2,
      );
      for (final s in pcm) {
        _samples.add(s / 32768.0);
      }
      if (_samples.length >= 16000 * tasmeeMaxSeconds) _stopRecording();
    });
    setState(() {
      _phase = _Phase.recording;
      _error = null;
      _result = null;
    });
  }

  Future<void> _stopRecording() async {
    if (_phase != _Phase.recording) return;
    setState(() => _phase = _Phase.thinking);
    await _mic?.cancel();
    _mic = null;
    await _recorder.stop();
    try {
      final heard = await TasmeeEngine.instance
          .transcribe(Float32List.fromList(_samples));
      final result = TasmeeEngine.compare(
        ayahText: widget.ayahText,
        heard: heard,
      );
      if (mounted) {
        setState(() {
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
              const Icon(Icons.record_voice_over_outlined,
                  color: AppColors.gold),
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
            style: TextStyle(fontSize: 12, height: 1.6,
                color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          if (!installed) ...[
            Text(
              trn('tasmee.download_note',
                  args: [formatBytes(tasmeeDownloadBytes)]),
              style: TextStyle(fontSize: 12.5, height: 1.6,
                  color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            if (_phase == _Phase.downloading) ...[
              LinearProgressIndicator(value: _progress, minHeight: 6),
              const SizedBox(height: 6),
              Text(percentOf(_progress),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12)),
            ] else
              FilledButton.icon(
                onPressed: _download,
                icon: const Icon(Icons.download_rounded),
                label: Text('tasmee.download'.tr()),
              ),
          ] else ...[
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
                            horizontal: 6, vertical: 2),
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
            ],
          ],
          if (_error case final e?) ...[
            const SizedBox(height: 8),
            Text(e,
                style: TextStyle(fontSize: 12, color: scheme.error),
                textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}
