import '../config/app_config.dart';
import 'stt/offline_stt_service.dart';
import 'stt/openai_stt_service.dart';
import 'stt/stt_service.dart';
import 'translate/offline_translate_service.dart';
import 'translate/openai_translate_service.dart';
import 'translate/translate_service.dart';
import 'tts/offline_tts_service.dart';
import 'tts/openai_tts_service.dart';
import 'tts/tts_service.dart';

/// Resolves the concrete STT / translate / TTS providers for a given
/// [ProviderMode]. Everything downstream depends only on the interfaces, so
/// swapping providers (online ⇄ offline, or a different vendor) happens here
/// and nowhere else.
class ProviderRegistry {
  ProviderRegistry(this.config)
      : stt = _resolveStt(config),
        translate = _resolveTranslate(config),
        tts = _resolveTts(config);

  final AppConfig config;
  final SttService stt;
  final TranslateService translate;
  final TtsService tts;

  bool get isReady => stt.isAvailable && translate.isAvailable && tts.isAvailable;

  static SttService _resolveStt(AppConfig config) =>
      switch (config.providerMode) {
        ProviderMode.online => OpenAiSttService(config),
        ProviderMode.offline => OfflineSttService(),
      };

  static TranslateService _resolveTranslate(AppConfig config) =>
      switch (config.providerMode) {
        ProviderMode.online => OpenAiTranslateService(config),
        ProviderMode.offline => OfflineTranslateService(),
      };

  static TtsService _resolveTts(AppConfig config) =>
      switch (config.providerMode) {
        ProviderMode.online => OpenAiTtsService(config),
        ProviderMode.offline => OfflineTtsService(),
      };
}
