import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import '../../config/languages.dart';
import 'translate_service.dart';

/// Online translation backed by an OpenAI chat model. Produces a faithful,
/// speakable translation with no extra commentary.
class OpenAiTranslateService implements TranslateService {
  OpenAiTranslateService(this._config, {http.Client? client})
      : _client = client ?? http.Client();

  final AppConfig _config;
  final http.Client _client;

  @override
  String get name => 'OpenAI ${_config.translateModel} (online)';

  @override
  bool get isAvailable => _config.hasOpenAiKey;

  @override
  Future<String> translate({
    required String text,
    required String targetLanguageCode,
    String? sourceLanguageCode,
  }) async {
    if (!isAvailable) {
      throw StateError('OpenAI API key is missing. Set OPENAI_API_KEY.');
    }
    if (text.trim().isEmpty) return '';

    final targetName = SupportedLanguages.byCode(targetLanguageCode).name;
    final sourceName = (sourceLanguageCode == null ||
            sourceLanguageCode == SupportedLanguages.auto.code)
        ? 'the detected language'
        : SupportedLanguages.byCode(sourceLanguageCode).name;

    final systemPrompt =
        'You are a professional live interpreter. Translate the user message '
        'from $sourceName into $targetName. Preserve meaning, tone and names. '
        'Respond with ONLY the translation, no quotes, no explanations.';

    final uri = Uri.parse('${_config.openAiBaseUrl}/chat/completions');
    final response = await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer ${_config.openAiApiKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _config.translateModel,
        'temperature': 0.2,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': text},
        ],
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Translate failed (${response.statusCode}): ${response.body}',
      );
    }

    final json = jsonDecode(utf8.decode(response.bodyBytes))
        as Map<String, dynamic>;
    final choices = json['choices'] as List<dynamic>? ?? const [];
    if (choices.isEmpty) return '';
    final message = choices.first['message'] as Map<String, dynamic>;
    return (message['content'] as String? ?? '').trim();
  }
}
