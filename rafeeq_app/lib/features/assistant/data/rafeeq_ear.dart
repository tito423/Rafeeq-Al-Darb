import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as so;

import '../../hifz/data/tasmee_mic.dart';
import '../presentation/assistant_describe.dart' show assistantLanguage;
import 'assistant_intent.dart' show afterWakeWord;
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

  /// Drops the worker so the next [start] loads the models again - after
  /// the «دقة أعلى» pack is downloaded or deleted.
  Future<void> reload() async {
    await shutdown();
  }

  /// Listen through a connected Bluetooth headset (set from the settings,
  /// applied at the next [start]).
  bool wantBluetooth = false;

  /// True while the microphone is the headset's, with the call route that
  /// needs; [stop] undoes it.
  bool get viaBluetooth => _viaBluetooth;
  bool _viaBluetooth = false;

  /// Whether a Bluetooth headset microphone is connected now.
  Future<bool> bluetoothPresent() async =>
      (await TasmeeMics.find(_mic ??= AudioRecorder())).hasBluetooth;
  StreamSubscription<Uint8List>? _micSub;
  SendPort? _toWorker;
  ReceivePort? _fromWorker;
  Future<void>? _starting;

  Future<void> _ensureWorker() async {
    if (_toWorker != null) return;
    final dir = (await RafeeqVoicePack.instance.dir()).path;
    // The «دقة أعلى» pack, when the reader downloaded it.
    final turbo = await RafeeqVoicePack.accurate.check()
        ? (await RafeeqVoicePack.accurate.dir()).path
        : '';
    final inbox = ReceivePort();
    _fromWorker = inbox;
    final ready = Completer<SendPort>();
    inbox.listen((m) {
      if (m is SendPort) {
        ready.complete(m);
      } else if (m is String) {
        debugPrint('rafeeq segment: "$m"');
        if (m.trim().isNotEmpty) _heard.add(m.trim());
      } else if (m is bool) {
        speaking.value = m;
      } else if (m is List && !ready.isCompleted) {
        ready.completeError(StateError('${m.first}'));
      }
    });
    await Isolate.spawn(_workerMain, [inbox.sendPort, dir, turbo, assistantLanguage()]);
    _toWorker = await ready.future;
  }

  /// Opens the microphone (loading the models the first time).
  Future<void> start() => _starting ??= () async {
        try {
          if (listening.value) return;
          await _ensureWorker();
          final mic = _mic ??= AudioRecorder();
          if (!await mic.hasPermission()) return;
          // A headset the way the tasmee opens one (tasmee_mic.dart): named,
          // the call route moved to it, the voice-communication source.
          final mics = wantBluetooth
              ? await TasmeeMics.find(mic)
              : const TasmeeMics(null, null);
          final bt = mics.hasBluetooth && await routeTasmeeToBluetooth();
          _viaBluetooth = bt;
          final stream = await mic.startStream(RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: 16000,
            numChannels: 1,
            audioInterruption: AudioInterruptionMode.none,
            device: bt ? mics.bluetooth : null,
            androidConfig: bt
                ? const AndroidRecordConfig(
                    audioSource: AndroidAudioSource.voiceCommunication,
                    audioManagerMode: AudioManagerMode.modeInCommunication,
                  )
                : const AndroidRecordConfig(
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
  /// A 16 kHz mono WAV pushed to the app's external files folder as
  /// `rafeeq_test.wav` is heard once, as if spoken, then deleted - how
  /// «رفيق» is checked end to end on the emulator, which hears nothing from
  /// the PC. Returns when it was fed (the time from feeding to text is
  /// logged by the listener), or null when there is no such file.
  Future<DateTime?> feedTestClip() async {
    final dir = await getExternalStorageDirectory();
    if (dir == null) return null;
    final f = File('${dir.path}/rafeeq_test.wav');
    if (!f.existsSync()) return null;
    final b = await f.readAsBytes();
    await f.delete();
    final pcm = b.buffer.asInt16List(44, (b.length - 44) ~/ 2);
    feed(Float32List.fromList([for (final v in pcm) v / 32768.0]));
    return DateTime.now();
  }

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
    if (_viaBluetooth) {
      _viaBluetooth = false;
      await restoreAudioRoute();
    }
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
    final turboDir = args[2] as String;
    final lang = args[3] as String;
    so.VoiceActivityDetector vad;
    so.OfflineRecognizer rec;
    so.OfflineRecognizer? turbo;
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
    // A call to «رفيق» opens a 12-second window: that phrase and what comes
    // after it (a command said in the next breath, an ayah number) are read
    // again by whisper. Everything else stays with the fast model.
    var refineUntil = DateTime.fromMillisecondsSinceEpoch(0);
    // Whisper is loaded only when «رفيق» is called and let go after five
    // minutes of not being needed. Measured on emulator-5554 (2026-09-30):
    // 0.85 GB at rest, 2.2 GB with both models held (more than a 4 GB phone
    // can spare), back to 0.89 GB once let go; loading it costs ~15 s, so a
    // conversation of several commands pays that once.
    var turboUsed = DateTime.fromMillisecondsSinceEpoch(0);
    so.OfflineRecognizer? loadTurbo() {
      if (turboDir.isEmpty) return null;
      try {
        return turbo ??= so.OfflineRecognizer(so.OfflineRecognizerConfig(
          model: so.OfflineModelConfig(
            whisper: so.OfflineWhisperModelConfig(
              encoder: p.join(turboDir, 'turbo-encoder.int8.onnx'),
              decoder: p.join(turboDir, 'turbo-decoder.int8.onnx'),
              language: lang,
              task: 'transcribe',
            ),
            tokens: p.join(turboDir, 'turbo-tokens.txt'),
            numThreads: 4,
            debug: false,
          ),
        ));
      } catch (_) {
        return null; // the fast model's text stands
      }
    }
    final inbox = ReceivePort();
    out.send(inbox.sendPort);
    const window = 512;
    var pending = Float32List(0);
    var wasSpeaking = false;
    inbox.listen((m) {
      if (m is Float32List) {
        if (turbo != null &&
            DateTime.now().difference(turboUsed).inMinutes >= 5) {
          turbo!.free();
          turbo = null;
        }
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
            var text = rec.getResult(s).text;
            s.free();
            final called = afterWakeWord(text) != null;
            if (turboDir.isNotEmpty &&
                (called || DateTime.now().isBefore(refineUntil))) {
              if (called) {
                refineUntil = DateTime.now().add(const Duration(seconds: 12));
              }
              final t = loadTurbo();
              turboUsed = DateTime.now();
              if (t != null) {
                final w = t.createStream();
                // Whisper wants a little silence after the speech.
                w.acceptWaveform(
                    samples: Float32List(seg.samples.length + 8000)
                      ..setAll(0, seg.samples),
                    sampleRate: 16000);
                t.decode(w);
                final better = t.getResult(w).text.trim();
                w.free();
                if (better.isNotEmpty) text = better;
              }
            }
            out.send(text);
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
        turbo?.free();
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
