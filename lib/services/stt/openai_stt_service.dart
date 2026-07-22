import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import 'stt_service.dart';

/// Online speech-to-text backed by OpenAI's audio transcription endpoint
/// (Whisper). Auto-detects the spoken language and returns its ISO code.
class OpenAiSttService implements SttService {
  OpenAiSttService(this._config, {http.Client? client})
      : _client = client ?? http.Client();

  final AppConfig _config;
  final http.Client _client;

  @override
  String get name => 'OpenAI Whisper (online)';

  @override
  bool get isAvailable => _config.hasOpenAiKey;

  @override
  Future<SttResult> transcribe({
    required String audioFilePath,
    String? languageHint,
  }) async {
    if (!isAvailable) {
      throw StateError('OpenAI API key is missing. Set OPENAI_API_KEY.');
    }

    final uri = Uri.parse('${_config.openAiBaseUrl}/audio/transcriptions');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer ${_config.openAiApiKey}'
      ..fields['model'] = _config.sttModel
      ..fields['response_format'] = 'verbose_json'
      ..files.add(await http.MultipartFile.fromPath('file', audioFilePath));

    if (languageHint != null && languageHint != 'auto') {
      request.fields['language'] = languageHint;
    }

    final streamed = await _client.send(request);
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw Exception('STT failed (${streamed.statusCode}): $body');
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    final text = (json['text'] as String? ?? '').trim();
    final detected = _mapWhisperLanguage(json['language'] as String?);

    return SttResult(text: text, detectedLanguageCode: detected);
  }

  /// Whisper's `verbose_json` returns full language names ("english"), so we
  /// map the common ones back to ISO 639-1 codes used across the app.
  String? _mapWhisperLanguage(String? raw) {
    if (raw == null) return null;
    const map = {
      'gujarati': 'gu',
      'hindi': 'hi',
      'english': 'en',
      'arabic': 'ar',
      'french': 'fr',
      'spanish': 'es',
      'korean': 'ko',
      'japanese': 'ja',
    };
    return map[raw.toLowerCase()] ?? raw.toLowerCase();
  }
}
