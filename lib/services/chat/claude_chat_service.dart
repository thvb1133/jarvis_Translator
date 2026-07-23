import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import 'chat_service.dart';

/// Kimchi companion powered by Anthropic's Claude models.
class ClaudeChatService implements ChatService {
  ClaudeChatService(this._config, {http.Client? client})
      : _client = client ?? http.Client();

  final AppConfig _config;
  final http.Client _client;

  @override
  String get name => 'Kimchi · Claude ${_config.anthropicModel}';

  @override
  bool get isAvailable => _config.hasAnthropicKey;

  @override
  Future<String> reply({
    required List<ChatTurn> history,
    required String replyLanguageName,
  }) async {
    if (!isAvailable) {
      throw StateError('Claude needs ANTHROPIC_API_KEY.');
    }

    final messages = [
      for (final turn in history)
        {'role': turn.fromUser ? 'user' : 'assistant', 'content': turn.text},
    ];

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
        'system': kimchiSystemPrompt(replyLanguageName),
        'messages': messages,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Kimchi (Claude) failed '
          '(${response.statusCode}): ${response.body}');
    }

    final json =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
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
