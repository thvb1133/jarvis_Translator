import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import 'translate_service.dart';

/// **Free, key-free, no-payment** translation.
///
/// Uses a public Google translation endpoint that needs no account, API key, or
/// billing. It also **auto-detects** the source language (`sl=auto`).
///
/// - **Native (Android/desktop):** calls the endpoint directly — works out of
///   the box with no setup.
/// - **Web:** browsers block this endpoint via CORS, so on the web set
///   [AppConfig.translateProxyUrl] (e.g. `/api/translate` on the Vercel deploy)
///   and the request is made server-side instead. Still no key required.
class FreeTranslateService implements TranslateService {
  FreeTranslateService(this._config, {http.Client? client})
      : _client = client ?? http.Client();

  final AppConfig _config;
  final http.Client _client;

  bool get _useProxy => _config.hasTranslateProxy;

  @override
  String get name => _useProxy ? 'Free (via proxy)' : 'Free translation';

  /// No key or payment is ever required.
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

  Future<String> _translateDirect(
    String text,
    String target,
    String? source,
  ) async {
    final sl = (source == null || source.isEmpty || source == 'auto')
        ? 'auto'
        : source;
    final uri = Uri.https('translate.googleapis.com', '/translate_a/single', {
      'client': 'gtx',
      'sl': sl,
      'tl': target,
      'dt': 't',
      'q': text,
    });

    final response = await _client.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Free translation failed (${response.statusCode}). '
        'On the web, configure a translate proxy (see README).',
      );
    }
    return _extractTranslation(utf8.decode(response.bodyBytes));
  }

  /// The endpoint returns a nested JSON array; the first element holds the
  /// translated sentence fragments as `[[translated, original, ...], ...]`.
  static String _extractTranslation(String body) {
    final decoded = jsonDecode(body) as List<dynamic>;
    final segments = decoded.isNotEmpty ? decoded[0] as List<dynamic>? : null;
    if (segments == null) return '';
    final buffer = StringBuffer();
    for (final segment in segments) {
      if (segment is List && segment.isNotEmpty && segment[0] is String) {
        buffer.write(segment[0] as String);
      }
    }
    return buffer.toString().trim();
  }
}
