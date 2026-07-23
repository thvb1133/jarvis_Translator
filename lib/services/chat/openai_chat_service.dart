import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import 'chat_service.dart';

/// Kimchi companion powered by an OpenAI chat model.
class OpenAiChatService implements ChatService {
  OpenAiChatService(this._config, {http.Client? client})
      : _client = client ?? http.Client();

  final AppConfig _config;
  final http.Client _client;

  @override
  String get name => 'Kimchi · OpenAI ${_config.translateModel}';

  @override
  bool get isAvailable => _config.hasOpenAiKey;

  @override
  Future<String> reply({
    required List<ChatTurn> history,
    required String replyLanguageName,
  }) async {
    if (!isAvailable) {
      throw StateError('OpenAI API key is missing. Set OPENAI_API_KEY.');
    }

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': kimchiSystemPrompt(replyLanguageName)},
      for (final turn in history)
        {'role': turn.fromUser ? 'user' : 'assistant', 'content': turn.text},
    ];

    final response = await _client.post(
      Uri.parse('${_config.openAiBaseUrl}/chat/completions'),
      headers: {
        'Authorization': 'Bearer ${_config.openAiApiKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _config.translateModel,
        'temperature': 0.7,
        'messages': messages,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Kimchi (OpenAI) failed '
          '(${response.statusCode}): ${response.body}');
    }

    final json =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final choices = json['choices'] as List<dynamic>? ?? const [];
    if (choices.isEmpty) return '';
    final message = choices.first['message'] as Map<String, dynamic>;
    return (message['content'] as String? ?? '').trim();
  }
}
