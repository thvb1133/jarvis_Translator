/// Supported languages for the JARVIS Translator.
///
/// The list is intentionally easy to extend: add a new [Language] entry and it
/// automatically appears in the language selectors and is understood by the
/// online providers (which are driven by the BCP-47 / ISO codes below).
class Language {
  const Language({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.flag,
  });

  /// ISO 639-1 code (e.g. `en`, `hi`, `gu`). Used by STT/translate/TTS layers.
  final String code;

  /// English display name.
  final String name;

  /// Name written in the language itself.
  final String nativeName;

  /// Emoji flag used for a quick visual cue in the UI.
  final String flag;

  @override
  bool operator ==(Object other) =>
      other is Language && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

class SupportedLanguages {
  const SupportedLanguages._();

  /// Sentinel used for "let the engine auto-detect the spoken language".
  static const Language auto = Language(
    code: 'auto',
    name: 'Auto-detect',
    nativeName: 'Auto',
    flag: '🌐',
  );

  static const List<Language> all = [
    Language(code: 'gu', name: 'Gujarati', nativeName: 'ગુજરાતી', flag: '🇮🇳'),
    Language(code: 'hi', name: 'Hindi', nativeName: 'हिन्दी', flag: '🇮🇳'),
    Language(code: 'en', name: 'English', nativeName: 'English', flag: '🇬🇧'),
    Language(code: 'ar', name: 'Arabic', nativeName: 'العربية', flag: '🇸🇦'),
    Language(code: 'fr', name: 'French', nativeName: 'Français', flag: '🇫🇷'),
    Language(code: 'es', name: 'Spanish', nativeName: 'Español', flag: '🇪🇸'),
    Language(code: 'ko', name: 'Korean', nativeName: '한국어', flag: '🇰🇷'),
    Language(code: 'ja', name: 'Japanese', nativeName: '日本語', flag: '🇯🇵'),
  ];

  /// All entries including the auto-detect sentinel (useful for source pickers).
  static List<Language> get withAuto => [auto, ...all];

  static Language byCode(String code) {
    if (code == auto.code) return auto;
    return all.firstWhere(
      (l) => l.code == code,
      orElse: () => auto,
    );
  }
}
