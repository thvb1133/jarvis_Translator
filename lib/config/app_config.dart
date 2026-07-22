import 'package:flutter/foundation.dart';

/// Which family of providers should back the translation pipeline.
///
/// The MVP ships the [online] path (OpenAI). [offline] is reserved for phase 2
/// (whisper.cpp + NLLB-200 + Piper) and is wired through the same interfaces.
enum ProviderMode { online, offline }

/// Central, read-only configuration for the app.
///
/// Secrets are **never** hardcoded. They are read from the environment via
/// `--dart-define` (e.g. `--dart-define=OPENAI_API_KEY=sk-...`) which maps
/// cleanly onto Cloud Agent / CI secrets and local `.env`-style workflows.
class AppConfig {
  const AppConfig({
    required this.openAiApiKey,
    required this.openAiBaseUrl,
    required this.sttModel,
    required this.translateModel,
    required this.ttsModel,
    required this.ttsVoice,
    required this.providerMode,
  });

  final String openAiApiKey;
  final String openAiBaseUrl;
  final String sttModel;
  final String translateModel;
  final String ttsModel;
  final String ttsVoice;
  final ProviderMode providerMode;

  bool get hasOpenAiKey => openAiApiKey.trim().isNotEmpty;

  /// Builds config from compile-time environment values.
  factory AppConfig.fromEnvironment() {
    const key = String.fromEnvironment('OPENAI_API_KEY', defaultValue: '');
    const baseUrl = String.fromEnvironment(
      'OPENAI_BASE_URL',
      defaultValue: 'https://api.openai.com/v1',
    );
    const stt = String.fromEnvironment(
      'OPENAI_STT_MODEL',
      defaultValue: 'whisper-1',
    );
    const translate = String.fromEnvironment(
      'OPENAI_TRANSLATE_MODEL',
      defaultValue: 'gpt-4o-mini',
    );
    const tts = String.fromEnvironment(
      'OPENAI_TTS_MODEL',
      defaultValue: 'gpt-4o-mini-tts',
    );
    const voice = String.fromEnvironment(
      'OPENAI_TTS_VOICE',
      defaultValue: 'alloy',
    );
    const mode = String.fromEnvironment(
      'PROVIDER_MODE',
      defaultValue: 'online',
    );

    return const AppConfig(
      openAiApiKey: key,
      openAiBaseUrl: baseUrl,
      sttModel: stt,
      translateModel: translate,
      ttsModel: tts,
      ttsVoice: voice,
      providerMode:
          mode == 'offline' ? ProviderMode.offline : ProviderMode.online,
    );
  }

  void debugLogStatus() {
    if (kDebugMode) {
      debugPrint('[JARVIS] provider mode: ${providerMode.name}');
      debugPrint('[JARVIS] OpenAI key present: $hasOpenAiKey');
    }
  }
}
