import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../config/app_config.dart';
import 'tts_service.dart';

/// Online text-to-speech backed by OpenAI's speech endpoint. Returns natural
/// sounding MP3 audio for the translated text.
class OpenAiTtsService implements TtsService {
  OpenAiTtsService(this._config, {http.Client? client})
      : _client = client ?? http.Client();

  final AppConfig _config;
  final http.Client _client;

  @override
  String get name => 'OpenAI ${_config.ttsModel} (online)';

  @override
  bool get isAvailable => _config.hasOpenAiKey;

  @override
  Future<TtsResult> synthesize({
    required String text,
    required String languageCode,
  }) async {
    if (!isAvailable) {
      throw StateError('OpenAI API key is missing. Set OPENAI_API_KEY.');
    }

    final uri = Uri.parse('${_config.openAiBaseUrl}/audio/speech');
    final response = await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer ${_config.openAiApiKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _config.ttsModel,
        'voice': _config.ttsVoice,
        'input': text,
        'response_format': 'mp3',
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'TTS failed (${response.statusCode}): ${response.body}',
      );
    }

    return TtsResult(
      bytes: Uint8List.fromList(response.bodyBytes),
      format: 'mp3',
    );
  }
}
