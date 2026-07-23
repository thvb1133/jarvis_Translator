import 'chat_service.dart';

/// Placeholder used when no chat backend is configured (no OpenAI/Claude key
/// and no proxy). Kimchi's companion mode needs an LLM, and there is no
/// reliable free/key-free chat endpoint, so this simply reports unavailable and
/// the UI prompts the user to add a key or proxy.
class UnavailableChatService implements ChatService {
  @override
  String get name => 'Kimchi (needs a key)';

  @override
  bool get isAvailable => false;

  @override
  Future<String> reply({
    required List<ChatTurn> history,
    required String replyLanguageName,
  }) {
    throw StateError(
      'Kimchi companion needs an OpenAI or Claude key (or a chat proxy).',
    );
  }
}
