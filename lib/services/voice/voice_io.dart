import '../stt/stt_service.dart' show SttResult;

export '../stt/stt_service.dart' show SttResult;

/// Live microphone input that both captures and recognizes speech in one step
/// (as the device / browser speech engine does), as opposed to the file-based
/// [SttService].
abstract class VoiceInput {
  String get name;

  bool get isAvailable;

  /// Prepares the engine; returns false if speech recognition is unavailable.
  Future<bool> init();

  /// Begins listening. [onLevel] receives a normalized 0..1 audio level for the
  /// orb visualizer. [localeId] hints the spoken language (device engines can't
  /// reliably auto-detect, so a hint is used when available).
  Future<void> start({
    String? localeId,
    void Function(double level)? onLevel,
  });

  /// Stops listening and returns the final recognized text.
  Future<SttResult> stop();

  Future<void> cancel();
}

/// Direct text-to-speech that speaks immediately through the device / browser,
/// as opposed to the bytes-returning [TtsService].
abstract class VoiceOutput {
  String get name;

  bool get isAvailable;

  /// Speaks [text] in [bcp47Locale] (e.g. `hi-IN`) and completes when finished.
  Future<void> speak(String text, {required String bcp47Locale});

  Future<void> stop();
}
