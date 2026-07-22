import 'translate_service.dart';

/// Offline translation placeholder for phase 2 (NLLB-200).
class OfflineTranslateService implements TranslateService {
  @override
  String get name => 'NLLB-200 (offline · phase 2)';

  @override
  bool get isAvailable => false;

  @override
  Future<String> translate({
    required String text,
    required String targetLanguageCode,
    String? sourceLanguageCode,
  }) {
    throw UnimplementedError(
      'Offline translation (NLLB-200) lands in phase 2. Use the online provider.',
    );
  }
}
