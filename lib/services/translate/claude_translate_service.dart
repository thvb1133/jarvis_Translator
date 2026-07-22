import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import '../../config/languages.dart';
import 'translate_service.dart';

/// Translation backed by Anthropic's Claude models.
///
/// Two modes:
/// - **Proxy** (recommended for web / Vercel): posts to [AppConfig.translateProxyUrl]
///   so the API key stays server-side.
/// - **Direct**: calls the Anthropic Messages API using [AppConfig.anthropicApiKey]
///   (used by the native apps).
class ClaudeTranslateService implements TranslateService {
  ClaudeTranslateService(this._config, {http.Client? client})
      : _client = client ?? http.Client();

  final AppConfig _config;
  final http.Client _client;

  bool get _useProxy => _config.hasTranslateProxy;

  @override
  String get name =>
      _useProxy ? 'Claude via proxy' : 'Claude ${_config.anthropicModel}';

  @override
  bool get isAvailable => _useProxy || _config.hasAnthropicKey;

  @override
  Future<String> translate({
    required String text,
    required String targetLanguageCode,
    String? sourceLanguageCode,
  }) async {
    if (text.trim().isEmpty) return '';
    if (!isAvailable) {
      throw StateError(
        'Claude translation needs ANTHROPIC_API_KEY or a TRANSLATE_PROXY_URL.',
      );
    }
    return _useProxy
        ? _translateViaProxy(text, targetLanguageCode, sourceLanguageCode)
        : _translateDirect(text, targetLanguageCode, sourceLanguageCode);
  }

  Future<String> _translateViaProxy(
    String text,
    String target,
    String? source,
  ) async {
    final response = await _client.post(
      Uri.parse(_config.translateProxyUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'text': text,
        'target': target,
        'source': source,
        'provider': 'claude',
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Translate proxy failed '
          '(${response.statusCode}): ${response.body}');
    }
    final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return (json['translation'] as String? ?? '').trim();
  }

  Future<String> _translateDirect(
    String text,
    String target,
    String? source,
  ) async {
    final targetName = SupportedLanguages.byCode(target).name;
    final sourceName = (source == null || source == SupportedLanguages.auto.code)
        ? 'the detected language'
        : SupportedLanguages.byCode(source).name;

    final response = await _client.post(
      Uri.parse('${_config.anthropicBaseUrl}/messages'),
      headers: {
        'x-api-key': _config.anthropicApiKey,
        'anthropic-version': '2023-06-01',
        'anthropic-dangerous-direct-browser-access': 'true',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _config.anthropicModel,
        'max_tokens': 1024,
        'system':
            'You are a professional live interpreter. Translate the user message '
                'from $sourceName into $targetName. Preserve meaning, tone and '
                'names. Respond with ONLY the translation, no quotes, no notes.',
        'messages': [
          {'role': 'user', 'content': text},
        ],
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Claude failed (${response.statusCode}): ${response.body}');
    }

    final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final content = json['content'] as List<dynamic>? ?? const [];
    final buffer = StringBuffer();
    for (final block in content) {
      if (block is Map<String, dynamic> && block['type'] == 'text') {
        buffer.write(block['text'] as String? ?? '');
      }
    }
    return buffer.toString().trim();
  }
}
