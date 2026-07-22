import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../config/languages.dart';
import '../core/audio/audio_playback.dart';
import '../core/audio/audio_recorder.dart';
import '../services/provider_registry.dart';
import 'transcript_entry.dart';

/// High-level status the UI reacts to (drives the orb animation + hints).
enum PipelineStatus { idle, listening, thinking, speaking, error }

/// Orchestrates the end-to-end live translation pipeline. Two voice paths share
/// the same translate stage:
///
/// - **Cloud:** record file → OpenAI STT → translate → OpenAI TTS → play.
/// - **Device/browser:** live recognition → translate → device speech.
///
/// The mic is muted while speaking to avoid translating our own output.
class PipelineController extends ChangeNotifier {
  PipelineController({
    required AppConfig config,
    required ProviderRegistry registry,
    MicRecorder? recorder,
    AudioPlayback? playback,
  })  : _config = config,
        _registry = registry,
        _recorder = recorder ?? MicRecorder(),
        _playback = playback ?? AudioPlayback();

  AppConfig _config;
  AppConfig get config => _config;

  ProviderRegistry _registry;
  ProviderRegistry get registry => _registry;

  final MicRecorder _recorder;
  final AudioPlayback _playback;

  PipelineStatus _status = PipelineStatus.idle;
  PipelineStatus get status => _status;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  final ValueNotifier<double> audioLevel = ValueNotifier<double>(0);
  StreamSubscription<double>? _levelSub;

  Language _sourceLanguage = SupportedLanguages.auto;
  Language get sourceLanguage => _sourceLanguage;

  Language _targetLanguage = SupportedLanguages.byCode('en');
  Language get targetLanguage => _targetLanguage;

  final List<TranscriptEntry> _transcript = [];
  List<TranscriptEntry> get transcript => List.unmodifiable(_transcript);

  VoiceEngine get voiceEngine => _config.voiceEngine;
  TranslationProvider get translationProvider => _config.translationProvider;

  bool get isBusy =>
      _status == PipelineStatus.thinking || _status == PipelineStatus.speaking;

  bool get isReady => _registry.isReady;

  void setVoiceEngine(VoiceEngine engine) {
    if (engine == _config.voiceEngine) return;
    _config = _config.copyWith(voiceEngine: engine);
    _registry = ProviderRegistry(_config);
    resetError();
    notifyListeners();
  }

  void setTranslationProvider(TranslationProvider provider) {
    if (provider == _config.translationProvider) return;
    _config = _config.copyWith(translationProvider: provider);
    _registry = ProviderRegistry(_config);
    resetError();
    notifyListeners();
  }

  void setSourceLanguage(Language language) {
    _sourceLanguage = language;
    notifyListeners();
  }

  void setTargetLanguage(Language language) {
    _targetLanguage = language;
    notifyListeners();
  }

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

  Future<void> startListening() async {
    if (_status != PipelineStatus.idle) return;
    _setError(null);
    try {
      if (_registry.usesDeviceVoice) {
        final ok = await _registry.voiceInput.init();
        if (!ok) {
          _fail('Speech recognition is unavailable here. Try Cloud voice.');
          return;
        }
        await _registry.voiceInput.start(
          localeId: _sourceLanguage == SupportedLanguages.auto
              ? null
              : _sourceLanguage.sttLocaleId,
          onLevel: (v) => audioLevel.value = v,
        );
      } else {
        await _recorder.start();
        _levelSub?.cancel();
        _levelSub = _recorder.amplitudeStream().listen(
              (v) => audioLevel.value = v,
              onError: (_) {},
            );
      }
      _setStatus(PipelineStatus.listening);
    } catch (e) {
      _fail('Could not start listening: $e');
    }
  }

  Future<void> stopAndTranslate() async {
    if (_status != PipelineStatus.listening) return;
    try {
      if (_registry.usesDeviceVoice) {
        final result = await _registry.voiceInput.stop();
        await _resetLevel();
        await _translateAndSpeakDevice(result.text, result.detectedLanguageCode);
      } else {
        final audioPath = await _recorder.stop();
        await _stopLevelStream();
        if (audioPath == null) {
          _setStatus(PipelineStatus.idle);
          return;
        }
        await _runCloudPipeline(audioPath);
      }
    } catch (e) {
      await _stopLevelStream();
      _fail('$e');
    }
  }

  Future<void> _runCloudPipeline(String audioPath) async {
    _setStatus(PipelineStatus.thinking);
    final sttResult = await _registry.cloudStt.transcribe(
      audioFilePath: audioPath,
      languageHint: _sourceLanguage == SupportedLanguages.auto
          ? null
          : _sourceLanguage.code,
    );
    if (sttResult.isEmpty) {
      _setStatus(PipelineStatus.idle);
      return;
    }
    final detected = sttResult.detectedLanguageCode ?? _sourceLanguage.code;
    final translated = await _registry.translate.translate(
      text: sttResult.text,
      targetLanguageCode: _targetLanguage.code,
      sourceLanguageCode: detected,
    );
    _addTranscript(sttResult.text, translated, detected);

    _setStatus(PipelineStatus.speaking);
    final tts = await _registry.cloudTts.synthesize(
      text: translated,
      languageCode: _targetLanguage.code,
    );
    await _playback.playBytes(tts.bytes, format: tts.format);
    _setStatus(PipelineStatus.idle);
  }

  Future<void> _translateAndSpeakDevice(String text, String? detectedCode) async {
    if (text.trim().isEmpty) {
      _setStatus(PipelineStatus.idle);
      return;
    }
    _setStatus(PipelineStatus.thinking);
    final source = detectedCode ??
        (_sourceLanguage == SupportedLanguages.auto
            ? null
            : _sourceLanguage.code);
    final translated = await _registry.translate.translate(
      text: text,
      targetLanguageCode: _targetLanguage.code,
      sourceLanguageCode: source,
    );
    _addTranscript(text, translated, source ?? _sourceLanguage.code);

    _setStatus(PipelineStatus.speaking);
    await _registry.voiceOutput.speak(
      translated,
      bcp47Locale: _targetLanguage.locale,
    );
    _setStatus(PipelineStatus.idle);
  }

  void _addTranscript(String original, String translated, String sourceCode) {
    _transcript.add(
      TranscriptEntry(
        originalText: original,
        translatedText: translated,
        sourceLanguageCode: sourceCode,
        targetLanguageCode: _targetLanguage.code,
      ),
    );
    notifyListeners();
  }

  Future<void> _stopLevelStream() async {
    await _levelSub?.cancel();
    _levelSub = null;
    audioLevel.value = 0;
  }

  Future<void> _resetLevel() async {
    audioLevel.value = 0;
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

  void resetError() {
    if (_status == PipelineStatus.error) {
      _status = PipelineStatus.idle;
      _errorMessage = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _levelSub?.cancel();
    audioLevel.dispose();
    _recorder.dispose();
    _playback.dispose();
    super.dispose();
  }
}
