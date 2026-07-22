/// A single utterance shown in the on-screen transcript: the recognised
/// original text plus its translation.
class TranscriptEntry {
  TranscriptEntry({
    required this.originalText,
    required this.translatedText,
    required this.sourceLanguageCode,
    required this.targetLanguageCode,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  final String originalText;
  final String translatedText;
  final String sourceLanguageCode;
  final String targetLanguageCode;
  final DateTime timestamp;
}
