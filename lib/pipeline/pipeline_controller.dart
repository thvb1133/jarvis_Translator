import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../config/languages.dart';
import '../core/audio/audio_playback.dart';
import '../core/audio/audio_recorder.dart';
import '../services/provider_registry.dart';
import 'transcript_entry.dart';

/// High-level status the UI reacts to (drives the orb animation + hints).
enum PipelineStatus { idle, listening, thinking, speaking, error }

/// Orchestrates the end-to-end live translation pipeline:
/// capture → speech-to-text (auto-detect) → translate → text-to-speech → play.
///
/// The mic is muted while speaking to avoid the app translating its own output.
class PipelineController extends ChangeNotifier {
  PipelineController({
    required this.config,
    required this.registry,
    MicRecorder? recorder,
    AudioPlayback? playback,
  })  : _recorder = recorder ?? MicRecorder(),
        _playback = playback ?? AudioPlayback();

  final AppConfig config;
  final ProviderRegistry registry;
  final MicRecorder _recorder;
  final AudioPlayback _playback;

  PipelineStatus _status = PipelineStatus.idle;
  PipelineStatus get status => _status;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// Source language for a session. `auto` means "detect the spoken language".
  Language _sourceLanguage = SupportedLanguages.auto;
  Language get sourceLanguage => _sourceLanguage;

  /// Language the translation is spoken/shown in.
  Language _targetLanguage =
      SupportedLanguages.byCode('en');
  Language get targetLanguage => _targetLanguage;

  final List<TranscriptEntry> _transcript = [];
  List<TranscriptEntry> get transcript => List.unmodifiable(_transcript);

  bool get isBusy =>
      _status == PipelineStatus.thinking || _status == PipelineStatus.speaking;

  bool get isReady => registry.isReady;

  void setSourceLanguage(Language language) {
    _sourceLanguage = language;
    notifyListeners();
  }

  void setTargetLanguage(Language language) {
    _targetLanguage = language;
    notifyListeners();
  }

  /// Swaps source and target (auto-detect can't be a target, so it stays).
  void swapLanguages() {
    if (_sourceLanguage == SupportedLanguages.auto) return;
    final tmp = _sourceLanguage;
    _sourceLanguage = _targetLanguage;
    _targetLanguage = tmp;
    notifyListeners();
  }

  void clearTranscript() {
    _transcript.clear();
    notifyListeners();
  }

  /// Push-to-talk: begin capturing microphone audio.
  Future<void> startListening() async {
    if (_status != PipelineStatus.idle) return;
    _setError(null);
    try {
      await _recorder.start();
      _setStatus(PipelineStatus.listening);
    } catch (e) {
      _fail('Could not start recording: $e');
    }
  }

  /// Push-to-talk release: stop capture and run the translation pipeline.
  Future<void> stopAndTranslate() async {
    if (_status != PipelineStatus.listening) return;
    String? audioPath;
    try {
      audioPath = await _recorder.stop();
    } catch (e) {
      _fail('Could not stop recording: $e');
      return;
    }

    if (audioPath == null) {
      _setStatus(PipelineStatus.idle);
      return;
    }

    await _runPipeline(audioPath);
  }

  Future<void> _runPipeline(String audioPath) async {
    _setStatus(PipelineStatus.thinking);
    try {
      final sttResult = await registry.stt.transcribe(
        audioFilePath: audioPath,
        languageHint: _sourceLanguage == SupportedLanguages.auto
            ? null
            : _sourceLanguage.code,
      );

      if (sttResult.isEmpty) {
        _setStatus(PipelineStatus.idle);
        return;
      }

      final detectedCode =
          sttResult.detectedLanguageCode ?? _sourceLanguage.code;

      final translated = await registry.translate.translate(
        text: sttResult.text,
        targetLanguageCode: _targetLanguage.code,
        sourceLanguageCode: detectedCode,
      );

      _transcript.add(
        TranscriptEntry(
          originalText: sttResult.text,
          translatedText: translated,
          sourceLanguageCode: detectedCode,
          targetLanguageCode: _targetLanguage.code,
        ),
      );
      notifyListeners();

      // Mic stays muted (we are not recording) for the whole spoken segment.
      _setStatus(PipelineStatus.speaking);
      final tts = await registry.tts.synthesize(
        text: translated,
        languageCode: _targetLanguage.code,
      );
      await _playback.playBytes(tts.bytes, format: tts.format);

      _setStatus(PipelineStatus.idle);
    } catch (e) {
      _fail('$e');
    }
  }

  void _setStatus(PipelineStatus status) {
    _status = status;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
  }

  void _fail(String message) {
    if (kDebugMode) debugPrint('[JARVIS] pipeline error: $message');
    _errorMessage = message;
    _status = PipelineStatus.error;
    notifyListeners();
  }

  /// Clears an error state back to idle so the user can retry.
  void resetError() {
    if (_status == PipelineStatus.error) {
      _status = PipelineStatus.idle;
      _errorMessage = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _recorder.dispose();
    _playback.dispose();
    super.dispose();
  }
}
