import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import 'chat_service.dart';

/// Kimchi companion routed through a server-side proxy (e.g. a Vercel
/// serverless function at `/api/chat`) so the API key stays off the client.
/// This is the recommended setup for the public web build.
class ProxyChatService implements ChatService {
  ProxyChatService(this._config, {http.Client? client})
      : _client = client ?? http.Client();

  final AppConfig _config;
  final http.Client _client;

  @override
  String get name => 'Kimchi · proxy';

  @override
  bool get isAvailable => _config.hasChatProxy;

  @override
  Future<String> reply({
    required List<ChatTurn> history,
    required String replyLanguageName,
  }) async {
    if (!isAvailable) {
      throw StateError('No CHAT_PROXY_URL configured.');
    }

    final response = await _client.post(
      Uri.parse(_config.chatProxyUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'language': replyLanguageName,
        'messages': [
          for (final turn in history)
            {'role': turn.fromUser ? 'user' : 'assistant', 'content': turn.text},
        ],
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Kimchi proxy failed '
          '(${response.statusCode}): ${response.body}');
    }

    final json =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return (json['reply'] as String? ?? '').trim();
  }
}
