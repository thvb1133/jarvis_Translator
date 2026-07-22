import 'package:flutter_tts/flutter_tts.dart';

import 'voice_io.dart';

/// [VoiceOutput] backed by `flutter_tts`, which uses the device's native
/// text-to-speech on Android/iOS/macOS/Windows and the browser's speech
/// synthesis on web. Free and key-free.
class DeviceVoiceOutput implements VoiceOutput {
  DeviceVoiceOutput() {
    // Make speak() await until playback completes so the caller can keep the
    // mic muted for the whole spoken segment (echo avoidance).
    _tts.awaitSpeakCompletion(true);
  }

  final FlutterTts _tts = FlutterTts();

  @override
  String get name => 'Device / browser TTS';

  @override
  bool get isAvailable => true;

  @override
  Future<void> speak(String text, {required String bcp47Locale}) async {
    if (text.trim().isEmpty) return;
    try {
      await _tts.setLanguage(bcp47Locale);
    } catch (_) {
      // Fall back to the engine default if the locale isn't installed.
    }
    await _tts.stop();
    await _tts.speak(text);
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
  }
}
