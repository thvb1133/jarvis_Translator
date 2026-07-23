/// A single turn in a conversation with Kimchi.
class ChatTurn {
  const ChatTurn({required this.fromUser, required this.text});

  const ChatTurn.user(this.text) : fromUser = true;
  const ChatTurn.kimchi(this.text) : fromUser = false;

  final bool fromUser;
  final String text;
}

/// Kimchi's personality. Shared by every chat backend so the companion feels
/// the same whether it runs on OpenAI, Claude, or a serverless proxy.
///
/// Kimchi is a warm, talkative AI companion — part personal pet, part friend,
/// part translator and search guide.
String kimchiSystemPrompt(String replyLanguageName) {
  return 'You are Kimchi (also spelled Kimachi), a warm, playful, upbeat AI '
      'companion — part personal pet, part best friend, part translator and '
      'search guide. You chat naturally, remember the conversation, and love '
      'helping. You can translate, explain things simply, give directions and '
      'suggestions, and just have a friendly conversation. '
      'Keep replies short and natural — they are spoken out loud, so write the '
      'way a friendly companion would talk, not like an essay. Use at most a '
      'couple of sentences unless asked for more. Be encouraging and a little '
      'cute, but genuinely helpful. '
      'Always reply in $replyLanguageName.';
}

/// Conversational companion interface. Implementations are swappable behind this
/// interface (OpenAI, Claude, or a server-side proxy).
abstract class ChatService {
  String get name;

  bool get isAvailable;

  /// Produces Kimchi's next reply given the full [history] (the last entry is
  /// the user's latest message). [replyLanguageName] is the language Kimchi
  /// should speak in (e.g. "English", "Hindi").
  Future<String> reply({
    required List<ChatTurn> history,
    required String replyLanguageName,
  });
}
