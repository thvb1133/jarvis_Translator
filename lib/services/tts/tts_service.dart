import 'dart:typed_data';

/// Synthesised speech audio plus the container format it is encoded in.
class TtsResult {
  const TtsResult({required this.bytes, required this.format});

  /// Raw audio bytes ready to be written to a file / played back.
  final Uint8List bytes;

  /// File extension / container of [bytes] (e.g. `mp3`, `wav`).
  final String format;
}

/// Text-to-speech provider interface.
///
/// Implementations are swappable behind this interface. The MVP uses OpenAI
/// TTS; phase 2 adds an offline Piper implementation.
abstract class TtsService {
  String get name;

  bool get isAvailable;

  /// Synthesises spoken audio for [text] in [languageCode] (ISO 639-1).
  Future<TtsResult> synthesize({
    required String text,
    required String languageCode,
  });
}
