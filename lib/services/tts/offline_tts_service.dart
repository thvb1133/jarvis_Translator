import 'tts_service.dart';

/// Offline text-to-speech placeholder for phase 2 (Piper).
class OfflineTtsService implements TtsService {
  @override
  String get name => 'Piper (offline · phase 2)';

  @override
  bool get isAvailable => false;

  @override
  Future<TtsResult> synthesize({
    required String text,
    required String languageCode,
  }) {
    throw UnimplementedError(
      'Offline TTS (Piper) lands in phase 2. Use the online provider.',
    );
  }
}
