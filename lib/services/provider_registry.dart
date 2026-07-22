import '../config/app_config.dart';
import 'stt/openai_stt_service.dart';
import 'stt/stt_service.dart';
import 'translate/claude_translate_service.dart';
import 'translate/openai_translate_service.dart';
import 'translate/translate_service.dart';
import 'tts/openai_tts_service.dart';
import 'tts/tts_service.dart';
import 'voice/device_voice_input.dart';
import 'voice/device_voice_output.dart';
import 'voice/voice_io.dart';

/// Resolves the concrete providers for the current configuration. Everything
/// downstream depends only on the interfaces, so choosing a translator
/// (OpenAI ⇄ Claude) or a voice engine (cloud ⇄ device/browser) happens here.
class ProviderRegistry {
  ProviderRegistry(this.config)
      : translate = _resolveTranslate(config),
        cloudStt = OpenAiSttService(config),
        cloudTts = OpenAiTtsService(config),
        voiceInput = DeviceVoiceInput(),
        voiceOutput = DeviceVoiceOutput();

  final AppConfig config;

  final TranslateService translate;

  /// Cloud voice pipeline (used when [AppConfig.voiceEngine] is cloud).
  final SttService cloudStt;
  final TtsService cloudTts;

  /// Device / browser voice pipeline (used when voice engine is device).
  final VoiceInput voiceInput;
  final VoiceOutput voiceOutput;

  bool get usesDeviceVoice => config.voiceEngine == VoiceEngine.device;

  /// Whether the pipeline can run end-to-end right now.
  bool get isReady {
    if (!config.canTranslate) return false;
    if (usesDeviceVoice) return true; // device speech is assumed available
    return cloudStt.isAvailable && cloudTts.isAvailable;
  }

  static TranslateService _resolveTranslate(AppConfig config) =>
      switch (config.translationProvider) {
        TranslationProvider.openai => OpenAiTranslateService(config),
        TranslationProvider.claude => ClaudeTranslateService(config),
      };
}
