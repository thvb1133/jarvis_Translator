/// Text translation provider interface.
///
/// Implementations are swappable behind this interface. The MVP uses an
/// OpenAI chat model; phase 2 adds an offline NLLB-200 implementation.
abstract class TranslateService {
  String get name;

  bool get isAvailable;

  /// Translates [text] into [targetLanguageCode] (ISO 639-1).
  ///
  /// [sourceLanguageCode] is optional; when omitted the provider should infer
  /// the source language from the text itself.
  Future<String> translate({
    required String text,
    required String targetLanguageCode,
    String? sourceLanguageCode,
  });
}
