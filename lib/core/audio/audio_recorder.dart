import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart' as rec;

/// Thin cross-platform wrapper around the `record` package used for
/// push-to-talk capture. Records to a WAV file that the online STT provider
/// can consume directly.
class MicRecorder {
  final rec.AudioRecorder _recorder = rec.AudioRecorder();
  String? _currentPath;

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  /// Requests microphone permission where the platform requires it.
  Future<bool> ensurePermission() async {
    if (await _recorder.hasPermission()) return true;
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<void> start() async {
    if (_isRecording) return;
    final granted = await ensurePermission();
    if (!granted) {
      throw StateError('Microphone permission was denied.');
    }

    final dir = await getTemporaryDirectory();
    final path = p.join(
      dir.path,
      'jarvis_${DateTime.now().millisecondsSinceEpoch}.wav',
    );
    _currentPath = path;

    await _recorder.start(
      const rec.RecordConfig(
        encoder: rec.AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
    _isRecording = true;
  }

  /// Emits a normalized microphone level in the range [0, 1] while recording,
  /// used to drive the orb's live audio visualizer. Maps dBFS (which is <= 0)
  /// onto a friendly range and degrades gracefully where a platform doesn't
  /// report amplitude (the stream simply stays near 0).
  Stream<double> amplitudeStream({
    Duration interval = const Duration(milliseconds: 100),
  }) {
    return _recorder.onAmplitudeChanged(interval).map((amp) {
      const minDb = -45.0;
      final current = amp.current.isFinite ? amp.current : minDb;
      return ((current - minDb) / -minDb).clamp(0.0, 1.0);
    });
  }

  /// Stops recording and returns the path of the captured WAV file (or null).
  Future<String?> stop() async {
    if (!_isRecording) return null;
    final path = await _recorder.stop();
    _isRecording = false;
    return path ?? _currentPath;
  }

  Future<void> dispose() async {
    await _recorder.dispose();
  }
}
