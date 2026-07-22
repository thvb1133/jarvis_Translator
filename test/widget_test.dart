import 'package:flutter_test/flutter_test.dart';

import 'package:jarvis_translator/config/app_config.dart';
import 'package:jarvis_translator/app.dart';

void main() {
  testWidgets('JARVIS app renders the orb screen', (tester) async {
    const config = AppConfig(
      openAiApiKey: '',
      openAiBaseUrl: 'https://api.openai.com/v1',
      sttModel: 'whisper-1',
      translateModel: 'gpt-4o-mini',
      ttsModel: 'gpt-4o-mini-tts',
      ttsVoice: 'alloy',
      anthropicApiKey: '',
      anthropicBaseUrl: 'https://api.anthropic.com/v1',
      anthropicModel: 'claude-3-5-sonnet-latest',
      translateProxyUrl: '',
      translationProvider: TranslationProvider.openai,
      voiceEngine: VoiceEngine.cloud,
    );

    await tester.pumpWidget(const JarvisApp(config: config));
    await tester.pump();

    expect(find.text('JARVIS'), findsOneWidget);
    expect(find.text('LIVE VOICE TRANSLATOR'), findsOneWidget);
  });
}
