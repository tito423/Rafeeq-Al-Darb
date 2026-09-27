import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as so;

import 'rafeeq_voice_pack.dart';

/// «رفيق»'s ear: the microphone -> silero VAD -> omnilingual-asr, all on the
/// phone, nothing sent anywhere.
///
/// The microphone is read here; the models live in a worker isolate, so a
/// second of decoding never freezes a frame. The VAD cuts the stream into
/// utterances; each one is transcribed and handed to [heard].
///
/// It takes NO audio focus (`AudioInterruptionMode.none`): listening must not
/// pause anything another app - or this one - is playing. When to listen at
/// all (calls, sound playing, another app recording) is decided by the
/// caller; see `AssistantWakeListener`.
class RafeeqEar {
  RafeeqEar._();
  static final instance = RafeeqEar._();

  final _heard = StreamController<String>.broadcast();

  /// Every utterance, transcribed.
  Stream<String> get heard => _heard.stream;

  /// True while someone is speaking (the VAD's view).
  final ValueNotifier<bool> speaking = ValueNotifier(false);

  /// True while the microphone is open.
  final ValueNotifier<bool> listening = ValueNotifier(false);

  AudioRecorder? _mic;
  StreamSubscription<Uint8List>? _micSub;
  SendPort? _toWorker;
  ReceivePort? _fromWorker;
  Future<void>? _starting;

  Future<void> _ensureWorker() async {
    if (_toWorker != null) return;
    final dir = (await RafeeqVoicePack.instance.dir()).path;
    final inbox = ReceivePort();
    _fromWorker = inbox;
    final ready = Completer<SendPort>();
    inbox.listen((m) {
      if (m is SendPort) {
        ready.complete(m);
      } else if (m is String) {
        if (m.trim().isNotEmpty) _heard.add(m.trim());
      } else if (m is bool) {
        speaking.value = m;
      } else if (m is List && !ready.isCompleted) {
        ready.completeError(StateError('${m.first}'));
      }
    });
    await Isolate.spawn(_workerMain, [inbox.sendPort, dir]);
    _toWorker = await ready.future;
  }

  /// Opens the microphone (loading the models the first time).
  Future<void> start() => _starting ??= () async {
        try {
          if (listening.value) return;
          await _ensureWorker();
          final mic = _mic ??= AudioRecorder();
          if (!await mic.hasPermission()) return;
          final stream = await mic.startStream(const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: 16000,
            numChannels: 1,
            audioInterruption: AudioInterruptionMode.none,
            androidConfig: AndroidRecordConfig(
              audioSource: AndroidAudioSource.voiceRecognition,
              manageBluetooth: false,
            ),
          ));
          _micSub = stream.listen((chunk) => _toWorker?.send(pcm16ToFloat(chunk)));
          listening.value = true;
        } finally {
          _starting = null;
        }
      }();

  /// Feeds recorded speech (16 kHz mono) into the same path as the
  /// microphone, followed by a second of silence so the VAD closes the
  /// utterance. For checking «رفيق» on a device that cannot be spoken to
  /// (the emulator): see `AssistantWakeListener._testClip`.
  void feed(Float32List samples) {
    final to = _toWorker;
    if (to == null) return;
    for (var i = 0; i < samples.length; i += 1600) {
      final end = i + 1600 < samples.length ? i + 1600 : samples.length;
      to.send(Float32List.fromList(samples.sublist(i, end)));
    }
    to.send(Float32List(16000));
  }

  /// Closes the microphone; the models stay loaded for the next [start].
  Future<void> stop() async {
    await _starting;
    await _micSub?.cancel();
    _micSub = null;
    if (listening.value) await _mic?.stop();
    listening.value = false;
    speaking.value = false;
    _toWorker?.send('reset');
  }

  /// Everything released: the microphone, the worker and its ~400 MB.
  Future<void> shutdown() async {
    await stop();
    await _mic?.dispose();
    _mic = null;
    _toWorker?.send('exit');
    _toWorker = null;
    _fromWorker?.close();
    _fromWorker = null;
  }

  static void _workerMain(List<Object> args) {
    final out = args[0] as SendPort;
    final dir = args[1] as String;
    so.VoiceActivityDetector vad;
    so.OfflineRecognizer rec;
    try {
      so.initBindings();
      vad = so.VoiceActivityDetector(
        config: so.VadModelConfig(
          sileroVad: so.SileroVadModelConfig(
            model: p.join(dir, 'silero_vad.onnx'),
            minSilenceDuration: 0.6,
            maxSpeechDuration: 10,
          ),
          debug: false,
        ),
        bufferSizeInSeconds: 30,
      );
      rec = so.OfflineRecognizer(so.OfflineRecognizerConfig(
        model: so.OfflineModelConfig(
          omnilingual: so.OfflineOmnilingualAsrCtcModelConfig(
              model: p.join(dir, 'model.int8.onnx')),
          tokens: p.join(dir, 'tokens.txt'),
          numThreads: 2,
          debug: false,
        ),
      ));
    } catch (e) {
      out.send(['$e']);
      return;
    }
    final inbox = ReceivePort();
    out.send(inbox.sendPort);
    const window = 512;
    var pending = Float32List(0);
    var wasSpeaking = false;
    inbox.listen((m) {
      if (m is Float32List) {
        final all = Float32List(pending.length + m.length)
          ..setAll(0, pending)
          ..setAll(pending.length, m);
        var i = 0;
        while (i + window <= all.length) {
          vad.acceptWaveform(Float32List.sublistView(all, i, i + window));
          i += window;
          final now = vad.isDetected();
          if (now != wasSpeaking) {
            wasSpeaking = now;
            out.send(now);
          }
          while (!vad.isEmpty()) {
            final seg = vad.front();
            vad.pop();
            final s = rec.createStream();
            s.acceptWaveform(samples: seg.samples, sampleRate: 16000);
            rec.decode(s);
            out.send(rec.getResult(s).text);
            s.free();
          }
        }
        pending = Float32List.fromList(all.sublist(i));
      } else if (m == 'reset') {
        vad.reset();
        pending = Float32List(0);
        wasSpeaking = false;
      } else if (m == 'exit') {
        vad.free();
        rec.free();
        inbox.close();
      }
    });
  }
}

/// 16-bit little-endian mono PCM -> samples in [-1, 1).
///
/// A mic chunk can start at an ODD offset in its buffer, and an Int16 view
/// must be 2-byte aligned: seen on the emulator 2026-09-27, 508 RangeErrors
/// in a minute and nothing reached the recogniser. Such a chunk is copied
/// first.
@visibleForTesting
Float32List pcm16ToFloat(Uint8List chunk) {
  final bytes = chunk.offsetInBytes.isEven ? chunk : Uint8List.fromList(chunk);
  final pcm =
      bytes.buffer.asInt16List(bytes.offsetInBytes, bytes.lengthInBytes ~/ 2);
  final f = Float32List(pcm.length);
  for (var i = 0; i < pcm.length; i++) {
    f[i] = pcm[i] / 32768.0;
  }
  return f;
}
