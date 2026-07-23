import '../config/app_config.dart';
import 'chat/chat_service.dart';
import 'chat/claude_chat_service.dart';
import 'chat/openai_chat_service.dart';
import 'chat/proxy_chat_service.dart';
import 'chat/unavailable_chat_service.dart';
import 'stt/openai_stt_service.dart';
import 'stt/stt_service.dart';
import 'translate/claude_translate_service.dart';
import 'translate/free_translate_service.dart';
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
        chat = _resolveChat(config),
        cloudStt = OpenAiSttService(config),
        cloudTts = OpenAiTtsService(config),
        voiceInput = DeviceVoiceInput(),
        voiceOutput = DeviceVoiceOutput();

  final AppConfig config;

  final TranslateService translate;

  /// Kimchi's conversational companion backend.
  final ChatService chat;

  /// Cloud voice pipeline (used when [AppConfig.voiceEngine] is cloud).
  final SttService cloudStt;
  final TtsService cloudTts;

  /// Device / browser voice pipeline (used when voice engine is device).
  final VoiceInput voiceInput;
  final VoiceOutput voiceOutput;

  bool get usesDeviceVoice => config.voiceEngine == VoiceEngine.device;

  bool get _voiceReady {
    if (usesDeviceVoice) return true; // device speech is assumed available
    return cloudStt.isAvailable && cloudTts.isAvailable;
  }

  /// Whether the translator pipeline can run end-to-end right now.
  bool get isReady => config.canTranslate && _voiceReady;

  /// Whether Kimchi's companion (chat) mode can run end-to-end right now.
  bool get isReadyForChat => chat.isAvailable && _voiceReady;

  static TranslateService _resolveTranslate(AppConfig config) =>
      switch (config.translationProvider) {
        TranslationProvider.free => FreeTranslateService(config),
        TranslationProvider.openai => OpenAiTranslateService(config),
        TranslationProvider.claude => ClaudeTranslateService(config),
      };

  /// Chat backend selection is independent of the translator: prefer a proxy
  /// (keeps keys server-side), else whichever key is present, else unavailable.
  static ChatService _resolveChat(AppConfig config) {
    if (config.hasChatProxy) return ProxyChatService(config);
    if (config.hasOpenAiKey) return OpenAiChatService(config);
    if (config.hasAnthropicKey) return ClaudeChatService(config);
    return UnavailableChatService();
  }
}
