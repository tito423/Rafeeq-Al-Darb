import 'package:flutter/services.dart';

/// What one listen gave back: the words, or why there are none.
class SpeechResult {
  const SpeechResult({this.text, this.alternatives = const [], this.error});
  final String? text;
  final List<String> alternatives;

  /// Android's SpeechRecognizer.ERROR_* number, null on success.
  final int? error;

  bool get ok => error == null && (text?.trim().isNotEmpty ?? false);
}

/// Android's SpeechRecognizer, through `SpeechChannel.kt` - one command,
/// Egyptian Arabic first (the owner speaks it; MSA is understood by the same
/// model).
class SpeechInput {
  SpeechInput._() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'partial':
          onPartial?.call(call.arguments as String);
        case 'level':
          onLevel?.call((call.arguments as num).toDouble());
        case 'ready':
          onReady?.call();
      }
    });
  }
  static final instance = SpeechInput._();

  static const _channel = MethodChannel('com.tito.rafeeq_aldarb/speech');

  void Function(String)? onPartial;
  void Function(double)? onLevel;
  void Function()? onReady;

  // SpeechRecognizer.ERROR_* (android.speech), as the platform reports them.
  static const errNetworkTimeout = 1;
  static const errNetwork = 2;
  static const errSpeechTimeout = 6;
  static const errNoMatch = 7;
  static const errPermission = 9;
  static const errLanguageNotSupported = 12;
  static const errLanguageUnavailable = 13;

  /// (any recogniser on the phone, an on-device one - Android 12+ only).
  Future<(bool, bool)> available() async {
    final m = await _channel.invokeMapMethod<String, dynamic>('available');
    return ((m?['any'] as bool?) ?? false, (m?['onDevice'] as bool?) ?? false);
  }

  Future<SpeechResult> listen({
    String lang = 'ar-EG',
    bool preferOffline = false,
  }) async {
    final m = await _channel.invokeMapMethod<String, dynamic>(
        'listen', {'lang': lang, 'preferOffline': preferOffline});
    if (m == null) return const SpeechResult(error: 5);
    return SpeechResult(
      text: m['text'] as String?,
      alternatives: ((m['alternatives'] as List?) ?? const []).cast<String>(),
      error: m['error'] as int?,
    );
  }

  /// Stop listening and recognise what was said so far.
  Future<void> stop() => _channel.invokeMethod('stop');

  Future<void> cancel() => _channel.invokeMethod('cancel');
}
