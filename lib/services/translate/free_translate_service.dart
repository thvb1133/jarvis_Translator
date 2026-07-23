import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import '../../config/languages.dart';
import 'translate_service.dart';

/// Completely free, **key-free** translation.
///
/// - **Proxy mode** (used on the Vercel deployment): posts `{provider: 'free'}`
///   to [AppConfig.translateProxyUrl]; the serverless function auto-detects the
///   source language server-side (no CORS issues, no key).
/// - **Direct mode** (used on localhost / native): calls the public
///   [MyMemory](https://mymemory.translated.net/doc/spec.php) API, which is free,
///   needs no key, and allows browser (CORS) requests. MyMemory needs a source
///   language, so pick the **Speaker** language when using the free translator
///   (it falls back to English if left on Auto-detect).
class FreeTranslateService implements TranslateService {
  FreeTranslateService(this._config, {http.Client? client})
      : _client = client ?? http.Client();

  final AppConfig _config;
  final http.Client _client;

  bool get _useProxy => _config.hasTranslateProxy;

  @override
  String get name => _useProxy ? 'Free (via proxy)' : 'Free (MyMemory)';

  @override
  bool get isAvailable => true;

  @override
  Future<String> translate({
    required String text,
    required String targetLanguageCode,
    String? sourceLanguageCode,
  }) async {
    if (text.trim().isEmpty) return '';
    return _useProxy
        ? _translateViaProxy(text, targetLanguageCode, sourceLanguageCode)
        : _translateViaMyMemory(text, targetLanguageCode, sourceLanguageCode);
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
        'provider': 'free',
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Translate proxy failed (${response.statusCode}): ${response.body}',
      );
    }
    final json =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return (json['translation'] as String? ?? '').trim();
  }

  Future<String> _translateViaMyMemory(
    String text,
    String target,
    String? source,
  ) async {
    // MyMemory has no auto-detect; fall back to English when the speaker
    // language is left on Auto.
    final src = (source == null || source == SupportedLanguages.auto.code)
        ? 'en'
        : source;
    if (src == target) return text;

    final uri = Uri.parse('https://api.mymemory.translated.net/get').replace(
      queryParameters: {'q': text, 'langpair': '$src|$target'},
    );
    final response = await _client.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Free translation failed (${response.statusCode}): ${response.body}',
      );
    }
    final json =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final data = json['responseData'] as Map<String, dynamic>?;
    final translated = (data?['translatedText'] as String? ?? '').trim();
    if (translated.isEmpty) {
      throw Exception('Free translation returned no text.');
    }
    return translated;
  }
}
