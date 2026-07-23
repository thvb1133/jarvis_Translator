import 'package:flutter/foundation.dart';

/// Which service translates text.
///
/// - [free]: a public, key-free, no-payment endpoint (auto-detects language).
///   This is the default so the app works with zero setup.
/// - [openai] / [claude]: higher-quality paid providers (need an API key).
enum TranslationProvider { free, openai, claude }

/// Which engine handles listening (STT) and speaking (TTS).
///
/// - [cloud]: OpenAI Whisper + OpenAI TTS (needs an OpenAI key).
/// - [device]: the device / browser's built-in speech engines via
///   `speech_to_text` + `flutter_tts` — free, no key, works offline on device,
///   and is what makes a **Claude-key-only** web deployment possible.
enum VoiceEngine { cloud, device }

/// Central, read-only configuration. Secrets are **never** hardcoded — they are
/// read from the environment via `--dart-define`, which maps cleanly onto CI /
/// Cloud Agent / Vercel secrets.
class AppConfig {
  const AppConfig({
    required this.openAiApiKey,
    required this.openAiBaseUrl,
    required this.sttModel,
    required this.translateModel,
    required this.ttsModel,
    required this.ttsVoice,
    required this.anthropicApiKey,
    required this.anthropicBaseUrl,
    required this.anthropicModel,
    required this.translateProxyUrl,
    required this.translationProvider,
    required this.voiceEngine,
  });

  // OpenAI
  final String openAiApiKey;
  final String openAiBaseUrl;
  final String sttModel;
  final String translateModel;
  final String ttsModel;
  final String ttsVoice;

  // Anthropic (Claude)
  final String anthropicApiKey;
  final String anthropicBaseUrl;
  final String anthropicModel;

  /// When set, translation requests go to this URL (a server-side proxy such as
  /// a Vercel serverless function) instead of calling a provider directly. This
  /// keeps the API key off the client — the recommended setup for web.
  final String translateProxyUrl;

  final TranslationProvider translationProvider;
  final VoiceEngine voiceEngine;

  bool get hasOpenAiKey => openAiApiKey.trim().isNotEmpty;
  bool get hasAnthropicKey => anthropicApiKey.trim().isNotEmpty;
  bool get hasTranslateProxy => translateProxyUrl.trim().isNotEmpty;

  /// Whether translation is possible with the current settings.
  bool get canTranslate => switch (translationProvider) {
        // Free needs no key or payment — always available.
        TranslationProvider.free => true,
        TranslationProvider.openai => hasOpenAiKey || hasTranslateProxy,
        TranslationProvider.claude => hasAnthropicKey || hasTranslateProxy,
      };

  AppConfig copyWith({
    TranslationProvider? translationProvider,
    VoiceEngine? voiceEngine,
  }) {
    return AppConfig(
      openAiApiKey: openAiApiKey,
      openAiBaseUrl: openAiBaseUrl,
      sttModel: sttModel,
      translateModel: translateModel,
      ttsModel: ttsModel,
      ttsVoice: ttsVoice,
      anthropicApiKey: anthropicApiKey,
      anthropicBaseUrl: anthropicBaseUrl,
      anthropicModel: anthropicModel,
      translateProxyUrl: translateProxyUrl,
      translationProvider: translationProvider ?? this.translationProvider,
      voiceEngine: voiceEngine ?? this.voiceEngine,
    );
  }

  factory AppConfig.fromEnvironment() {
    const openAiKey = String.fromEnvironment('OPENAI_API_KEY', defaultValue: '');
    const openAiBase = String.fromEnvironment('OPENAI_BASE_URL',
        defaultValue: 'https://api.openai.com/v1');
    const stt = String.fromEnvironment('OPENAI_STT_MODEL', defaultValue: 'whisper-1');
    const openAiTranslate =
        String.fromEnvironment('OPENAI_TRANSLATE_MODEL', defaultValue: 'gpt-4o-mini');
    const tts = String.fromEnvironment('OPENAI_TTS_MODEL', defaultValue: 'gpt-4o-mini-tts');
    const voice = String.fromEnvironment('OPENAI_TTS_VOICE', defaultValue: 'alloy');

    const anthropicKey = String.fromEnvironment('ANTHROPIC_API_KEY', defaultValue: '');
    const anthropicBase = String.fromEnvironment('ANTHROPIC_BASE_URL',
        defaultValue: 'https://api.anthropic.com/v1');
    const anthropicModel = String.fromEnvironment('ANTHROPIC_MODEL',
        defaultValue: 'claude-3-5-sonnet-latest');

    const proxy = String.fromEnvironment('TRANSLATE_PROXY_URL', defaultValue: '');
    const providerRaw = String.fromEnvironment('TRANSLATION_PROVIDER', defaultValue: '');
    const engineRaw = String.fromEnvironment('VOICE_ENGINE', defaultValue: '');

    // Sensible defaults: on the web the device/browser speech engine is the
    // key-free voice path, so default to it there; native defaults to cloud.
    const defaultEngine = kIsWeb ? VoiceEngine.device : VoiceEngine.cloud;
    final engine = switch (engineRaw) {
      'device' => VoiceEngine.device,
      'cloud' => VoiceEngine.cloud,
      _ => defaultEngine,
    };

    final provider = switch (providerRaw) {
      'free' => TranslationProvider.free,
      'claude' => TranslationProvider.claude,
      'openai' => TranslationProvider.openai,
      // No explicit choice: pick a provider that will actually work with the
      // configured secrets, else fall back to the key-free Free engine.
      _ => openAiKey.isNotEmpty
          ? TranslationProvider.openai
          : (anthropicKey.isNotEmpty
              ? TranslationProvider.claude
              : TranslationProvider.free),
    };

    return AppConfig(
      openAiApiKey: openAiKey,
      openAiBaseUrl: openAiBase,
      sttModel: stt,
      translateModel: openAiTranslate,
      ttsModel: tts,
      ttsVoice: voice,
      anthropicApiKey: anthropicKey,
      anthropicBaseUrl: anthropicBase,
      anthropicModel: anthropicModel,
      translateProxyUrl: proxy,
      translationProvider: provider,
      voiceEngine: engine,
    );
  }

  void debugLogStatus() {
    if (kDebugMode) {
      debugPrint('[JARVIS] translator: ${translationProvider.name}');
      debugPrint('[JARVIS] voice engine: ${voiceEngine.name}');
      debugPrint('[JARVIS] canTranslate: $canTranslate '
          '(openai=$hasOpenAiKey claude=$hasAnthropicKey proxy=$hasTranslateProxy)');
    }
  }
}
