import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'voice_io.dart';

/// [VoiceInput] backed by `speech_to_text`, which uses the device's native
/// speech recognizer on Android/iOS/macOS and the browser's Web Speech API on
/// web. Free, key-free, and works offline on devices that ship offline models.
class DeviceVoiceInput implements VoiceInput {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _initialized = false;
  bool _available = true;
  String _lastWords = '';

  @override
  String get name => 'Device / browser speech';

  @override
  bool get isAvailable => _available;

  @override
  Future<bool> init() async {
    if (_initialized) return _available;
    try {
      _available = await _speech.initialize(
        onError: (_) {},
        onStatus: (_) {},
      );
    } catch (_) {
      _available = false;
    }
    _initialized = true;
    return _available;
  }

  @override
  Future<void> start({
    String? localeId,
    void Function(double level)? onLevel,
  }) async {
    if (!_initialized) await init();
    if (!_available) {
      throw StateError('Speech recognition is not available on this device.');
    }
    _lastWords = '';
    await _speech.listen(
      onResult: (result) => _lastWords = result.recognizedWords,
      onSoundLevelChange: onLevel == null
          ? null
          : (level) {
              // Levels are roughly dB-scaled and platform dependent; map to 0..1.
              final normalized = ((level + 2) / 12).clamp(0.0, 1.0);
              onLevel(normalized);
            },
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        localeId: localeId,
      ),
    );
  }

  @override
  Future<SttResult> stop() async {
    await _speech.stop();
    return SttResult(text: _lastWords.trim(), detectedLanguageCode: null);
  }

  @override
  Future<void> cancel() async {
    await _speech.cancel();
  }
}
