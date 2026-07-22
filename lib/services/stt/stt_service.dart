/// Result of a speech-to-text pass.
class SttResult {
  const SttResult({
    required this.text,
    required this.detectedLanguageCode,
  });

  /// Recognised transcript in the spoken language.
  final String text;

  /// ISO 639-1 code of the detected spoken language, or `null` if unknown.
  final String? detectedLanguageCode;

  bool get isEmpty => text.trim().isEmpty;
}

/// Speech-to-text provider interface.
///
/// Implementations must be swappable: the pipeline only ever talks to this
/// interface, never to a concrete provider. Online (OpenAI Whisper) and
/// offline (whisper.cpp) implementations both satisfy this contract.
abstract class SttService {
  /// Human readable provider name (for diagnostics / UI).
  String get name;

  /// Whether the provider is ready to be used (e.g. has credentials).
  bool get isAvailable;

  /// Transcribes the audio file at [audioFilePath].
  ///
  /// When [languageHint] is provided (an ISO code), the engine may use it to
  /// improve accuracy; when `null` the engine auto-detects the language.
  Future<SttResult> transcribe({
    required String audioFilePath,
    String? languageHint,
  });
}
