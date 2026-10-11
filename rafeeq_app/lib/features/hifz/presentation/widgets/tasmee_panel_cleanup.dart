part of 'tasmee_panel.dart';

/// Native cleanup shares the same queue as a replacement recording.
extension _TasmeeCleanup on _TasmeePanelState {
  Future<void> _cleanupRecording() async {
    try {
      if (_nativeStarted) await _recorder.stop();
    } finally {
      await _amp?.cancel();
      _amp = null;
      _level = 0;
      if (_routeTouched || _nativeStarted) await restoreAudioRoute();
      _routeTouched = false;
      _nativeStarted = false;
      if (_liveStarted) await _engine.stopLive();
      _liveStarted = false;
      final directory = _recordingDirectory;
      _recordingDirectory = null;
      _wavPath = null;
      if (directory != null && await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }
  }

  Future<void> _queueCleanup(
    TasmeeRecordingLease? lease, {
    bool disposeRecorder = false,
  }) => TasmeeRecordingLease.run(() async {
    try {
      await _cleanupRecording();
    } catch (e) {
      _showCleanupError(e);
    } finally {
      lease?.finish();
      if (disposeRecorder) await _recorder.dispose();
    }
  });

  /// A 16 kHz mono WAV pushed to the app's external files folder as
  /// `tasmee_test.wav` is scored instead of the recording, once, then
  /// deleted - how a real reciter's audio is checked end to end on the
  /// emulator, whose microphone hears nothing (as `rafeeq_test.wav` is for
  /// Rafeeq). Null when there is no such file.
  Future<String?> _testClip() async {
    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) return null;
      final f = File(p.join(dir.path, 'tasmee_test.wav'));
      if (!f.existsSync()) return null;
      final copy = '${_wavPath!}.fed.wav';
      await f.copy(copy);
      await f.delete();
      return copy;
    } catch (_) {
      return null;
    }
  }
}
