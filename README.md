# JARVIS Translator

A cross-platform **live voice translator** built with **Flutter** — one codebase
targeting **Android** and **Desktop (Windows / Linux / macOS)** (plus web for
quick testing).

It listens to whoever is speaking, **auto-detects the spoken language**,
translates it, and **speaks the translation out loud** in the other person's
language — like a live human interpreter for a group.

Supported languages out of the box: **Gujarati, Hindi, English, Arabic, French,
Spanish, Korean, Japanese** — and the list is trivial to extend (see
[`lib/config/languages.dart`](lib/config/languages.dart)).

---

## The JARVIS look

- A large, glowing **sun-like orb** in the center that pulses while listening and
  speaking (custom-painted, no external assets required).
- **Blue-to-black space background** with a slowly twinkling starfield.
- Cinematic, minimal, dark UI.

---

## Architecture

The pipeline is **capture → speech-to-text → translate → text-to-speech → play**,
and every stage sits behind a swappable interface so providers (online vendor,
offline engine, or a different vendor entirely) can be swapped in one place.

```
lib/
├── config/
│   ├── app_config.dart        # reads secrets from the environment (never hardcoded)
│   └── languages.dart         # supported languages (easy to extend)
├── core/audio/
│   ├── audio_recorder.dart    # push-to-talk capture (WAV, 16 kHz mono)
│   └── audio_playback.dart    # plays synthesized speech, mic stays muted meanwhile
├── services/
│   ├── stt/                   # SttService interface + OpenAI (online) + whisper.cpp (offline, phase 2)
│   ├── translate/             # TranslateService interface + OpenAI (online) + NLLB-200 (offline, phase 2)
│   ├── tts/                   # TtsService interface + OpenAI (online) + Piper (offline, phase 2)
│   └── provider_registry.dart # selects online/offline implementations
├── pipeline/
│   ├── pipeline_controller.dart # orchestrates the full flow + app state
│   └── transcript_entry.dart
└── ui/
    ├── home_screen.dart
    ├── theme/app_theme.dart
    └── widgets/                # jarvis_orb, space_background, transcript_view, language_selector
```

### Provider modes (hybrid)

- **Online (primary, shipped in the MVP):** best accuracy + full language
  coverage via OpenAI — speech-to-text (Whisper), translation (a GPT chat
  model), and natural text-to-speech.
- **Offline (phase 2, interfaces in place):** whisper.cpp (STT), NLLB-200
  (translation), Piper (TTS) for common languages, wired through the same
  interfaces so the UI and pipeline don't change.

A realtime speech-to-speech path (for lower latency) can be added as another
implementation behind the same STT/TTS interfaces.

---

## Setup

### 1. Prerequisites

- [Flutter](https://docs.flutter.dev/get-started/install) 3.3+ (Dart 3.3+).
- Platform toolchains as needed: Android SDK, or desktop build tooling for your
  OS. Run `flutter doctor` to check.

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Provide your API key (as a secret — never hardcoded)

The app reads secrets from the environment via `--dart-define`, which maps
cleanly onto CI / Cloud Agent secrets. **OpenAI** is recommended to start because
one provider covers speech→text, translation, and natural voice.

```bash
flutter run --dart-define=OPENAI_API_KEY=sk-your-key-here
```

If you're using a Cloud Agent, add `OPENAI_API_KEY` under **Cloud Agents →
Secrets** and pass it through as a `--dart-define` in your run command.

#### Configurable environment values

| Variable                 | Default              | Purpose                                  |
| ------------------------ | -------------------- | ---------------------------------------- |
| `OPENAI_API_KEY`         | _(required)_         | OpenAI API key                           |
| `OPENAI_BASE_URL`        | `https://api.openai.com/v1` | Override for proxies / gateways   |
| `OPENAI_STT_MODEL`       | `whisper-1`          | Speech-to-text model                     |
| `OPENAI_TRANSLATE_MODEL` | `gpt-4o-mini`        | Translation model                        |
| `OPENAI_TTS_MODEL`       | `gpt-4o-mini-tts`    | Text-to-speech model                     |
| `OPENAI_TTS_VOICE`       | `alloy`              | Voice used for spoken output             |
| `PROVIDER_MODE`          | `online`             | `online` or `offline` (phase 2)          |

> Without a key, the app still launches and shows the JARVIS UI, but displays a
> banner explaining that translation is disabled until a key is provided.

### 4. Run

```bash
# Android (device/emulator attached)
flutter run -d android --dart-define=OPENAI_API_KEY=sk-...

# Desktop
flutter run -d linux   --dart-define=OPENAI_API_KEY=sk-...
flutter run -d macos   --dart-define=OPENAI_API_KEY=sk-...
flutter run -d windows --dart-define=OPENAI_API_KEY=sk-...

# Web (quick UI testing)
flutter run -d chrome  --dart-define=OPENAI_API_KEY=sk-...
```

---

## Using it

1. Pick the **Translate to** language (and optionally set the speaker language,
   or leave it on **Auto-detect**).
2. **Press and hold the orb** to talk (push-to-talk). Release to translate.
3. The app transcribes, translates, and **speaks** the result; the mic is muted
   while it speaks to avoid echo.
4. The **transcript** panel shows every utterance (original + translation).

### Roadmap

- [x] MVP: online pipeline end-to-end (push-to-talk → detect → translate →
      speak), JARVIS orb + space UI, on-screen transcripts.
- [ ] Hands-free voice-activity detection (VAD) in addition to push-to-talk.
- [ ] Group / multi-speaker sessions.
- [ ] Offline fallback (whisper.cpp + NLLB-200 + Piper).
- [ ] Realtime speech-to-speech for lower latency.

---

## Permissions

- **Microphone** — required for capture (requested at runtime on Android; enabled
  via entitlements on desktop).
- **Network** — required to reach the online providers.

## Security

API keys are **never** hardcoded. They are injected at build/run time via
`--dart-define` and read in [`lib/config/app_config.dart`](lib/config/app_config.dart).
Do not commit real keys to the repo.
