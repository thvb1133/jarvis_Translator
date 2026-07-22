import 'stt_service.dart';

/// Offline STT placeholder for phase 2 (whisper.cpp).
///
/// It implements the same [SttService] contract so it can be dropped in behind
/// the interface without touching the pipeline. The actual native binding is
/// intentionally deferred to phase 2.
class OfflineSttService implements SttService {
  @override
  String get name => 'whisper.cpp (offline · phase 2)';

  @override
  bool get isAvailable => false;

  @override
  Future<SttResult> transcribe({
    required String audioFilePath,
    String? languageHint,
  }) {
    throw UnimplementedError(
      'Offline STT (whisper.cpp) lands in phase 2. Use the online provider.',
    );
  }
}
