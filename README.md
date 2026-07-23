# Kimchi Jarvis (Kimachi)

**Kimchi Jarvis** — called **Kimachi** — is a cross-platform **live voice
translator** built with **Flutter** — one codebase targeting **Android** and
**Desktop (Windows / Linux / macOS)** (plus web for quick testing).

> 💸 **Runs 100% free, no API key, no payment.** The default **Free** translator
> (public MyMemory API) plus the **Device/browser** voice engine need no account
> at all. OpenAI/Claude are optional upgrades (those require paid API credits).

It listens to whoever is speaking, **auto-detects the spoken language**,
translates it, and **speaks the translation out loud** in the other person's
language — like a live human interpreter for a group.

Supported languages out of the box: **Gujarati, Hindi, English, Arabic, French,
Spanish, Korean, Japanese** — and the list is trivial to extend (see
[`lib/config/languages.dart`](lib/config/languages.dart)).

---

## ⚡ Free mode — no API key, no payment (default)

You do **not** need an OpenAI/Claude key or any billing to use this app. Out of
the box it runs on:

- **Free translator** — a public, key-free translation engine that also
  **auto-detects** the spoken language.
- **Device / browser voice** — the built-in speech recognition and text-to-speech
  on your phone/computer/browser (free, no key).

So the default is **Translator: Free** + **Voice: Device** = a fully working live
translator at **$0**. You can still switch to OpenAI or Claude in the top toggles
if you have a key and want the highest quality.

### Run it on your computer (localhost)

```bash
# 1. Install Flutter once: https://docs.flutter.dev/get-started/install
# 2. From the project folder:
flutter pub get

# 3a. Desktop app (recommended for free mode — no key needed):
flutter run -d macos      # or: -d windows / -d linux

# 3b. Android phone/emulator plugged in:
flutter run -d android

# 3c. Web on localhost:
flutter run -d chrome
```

Press and hold the orb, speak, and it translates and speaks back — no key.

> **Web note:** the free translator's endpoint is blocked by browsers (CORS), so
> on the **web** free translation works through the tiny server proxy included
> here — which is exactly what the **Vercel** deploy below sets up automatically.
> The **desktop and Android** apps call it directly and need no proxy.

### Deploy it online for free (Vercel) — zero secrets

This repo is preconfigured so a Vercel import "just works" with **no API keys**:

1. Push this repo to GitHub (already done).
2. Go to **https://vercel.com/new**, sign in with GitHub, and **Import**
   `jarvis_Translator`.
3. Framework Preset: **Other** (Vercel auto-reads [`vercel.json`](vercel.json)).
   Leave everything default — **do not add any environment variable**.
4. Click **Deploy**.

That's it. Vercel builds the Flutter web app and serves the free translation
proxy at `/api/translate`, so the live site translates for free. (I can't log
into your Vercel account for you, but these are the only clicks needed — no
payment, no keys.)

---

## 🐾 Meet Kimchi — your talkative AI companion

Flip the top toggle from **Translate** to **Kimchi** and the orb becomes a
friendly, talkative companion — part pet, part friend, part translator and
search guide. Hold the orb, talk to Kimchi, and Kimchi **talks back out loud**,
remembering the conversation.

- Ask it to translate, explain something, give suggestions, or just chat.
- Kimchi replies in the language you pick under **"Kimchi speaks"**.
- Listening/speaking use the same voice engines as the translator (free Device
  voice, or Cloud/OpenAI).

**Kimchi needs a brain (an LLM), so companion mode needs a key** — there is no
free chat engine like there is for translation. Use **one** of:

- `OPENAI_API_KEY` or `ANTHROPIC_API_KEY` at run time (native/desktop), or
- the **Vercel** deploy with a key set server-side (recommended for web): add
  `ANTHROPIC_API_KEY` (or `OPENAI_API_KEY`) in Vercel → Settings → Environment
  Variables. The build already points Kimchi at the `/api/chat` proxy, so your
  key stays off the browser.

```bash
# Talk to Kimchi locally with a Claude key (free device voice):
flutter run --dart-define=ANTHROPIC_API_KEY=sk-ant-... \
            --dart-define=VOICE_ENGINE=device

# ...or with an OpenAI key (cloud voice + Kimchi in one key):
flutter run --dart-define=OPENAI_API_KEY=sk-...
```

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
│   ├── stt/                   # SttService interface + OpenAI Whisper (cloud STT)
│   ├── translate/             # TranslateService + OpenAI + Claude (direct or via proxy)
│   ├── tts/                   # TtsService interface + OpenAI (cloud TTS)
│   ├── voice/                 # VoiceInput/VoiceOutput + device/browser speech engines
│   └── provider_registry.dart # picks translator + voice engine
├── pipeline/
│   ├── pipeline_controller.dart # orchestrates the full flow + app state
│   └── transcript_entry.dart
└── ui/
    ├── home_screen.dart
    ├── theme/app_theme.dart
    └── widgets/                # jarvis_orb, space_background, transcript_view, language_selector

api/translate.js               # (repo root) Vercel serverless proxy — keeps the key server-side
```

### Two independent choices (both toggleable in the UI)

**Translator**
- **Free** *(default)* — a public, key-free endpoint with auto-detect. No account
  or payment. Best paired with the Device voice engine for a fully $0 setup.
- **OpenAI** — a GPT chat model (needs an OpenAI key).
- **Claude** — Anthropic. Great for translation; **note Claude does text only —
  it has no speech-to-text or text-to-speech**, so pair it with the Device voice
  engine below for a full voice translator.

**Voice engine (listening + speaking)**
- **Cloud** — OpenAI Whisper (STT) + OpenAI TTS. Highest quality; needs an
  OpenAI key.
- **Device** — the device's / browser's built-in speech via `speech_to_text` +
  `flutter_tts`. **Free, no key, works offline on device**, and works in the
  browser — this is what makes a **Claude-key-only** web deployment possible.

So a **Claude-only** setup = **Translator: Claude** + **Voice engine: Device**.

---

## (Optional) Upgrade quality with an API key

**You don't need this for free mode above.** A paid key only buys higher-quality
translation/voice. If you want it, pick the path that matches how you run it.

### OpenAI (recommended — one key does speech-to-text, translation, and voice)

1. Go to **https://platform.openai.com/signup** and create an account (or log in).
2. Add billing: **Settings → Billing → Add payment method** and load a few
   dollars of credit (the API is pay-as-you-go and separate from ChatGPT Plus).
3. Open **https://platform.openai.com/api-keys → Create new secret key**.
4. Copy the key (starts with `sk-...`). **You only see it once** — save it safely.

### Anthropic / Claude (text translation only — pair with the free Device voice)

1. Go to **https://console.anthropic.com** and sign in.
2. **Settings → Billing** and add credit.
3. **API Keys → Create Key**, copy the key (starts with `sk-ant-...`).

> Claude has no speech engine, so a Claude-only build uses the browser/device
> voice for listening and speaking (see the Vercel deploy below).

### Where to put the key

| Where you run it            | Where the key goes                                                        |
| --------------------------- | ------------------------------------------------------------------------- |
| **Local / desktop / mobile**| Pass it on the command line via `--dart-define` (see Setup below).        |
| **Cursor Cloud Agent**      | Dashboard → **Cloud Agents → Secrets** → add `OPENAI_API_KEY`.            |
| **GitHub Actions (Pages/APK)** | Repo **Settings → Secrets and variables → Actions → New repository secret** → add `OPENAI_API_KEY`. |
| **Vercel (secure web)**     | Project **Settings → Environment Variables** → add `ANTHROPIC_API_KEY`.   |

> ⚠️ **Never commit a key to the repo**, and never paste a real key into a
> **public** website build — a web bundle ships the key in client-side JS where
> anyone can read it. For public web, use the **Vercel** path (key stays on the
> server) or the **Device** voice engine (no key). Real keys are best used in the
> native apps or behind the proxy.

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

### 3. Provide keys via `--dart-define` (never hardcoded)

Secrets are read from the environment via `--dart-define`, which maps cleanly
onto CI / Cloud Agent / Vercel secrets.

**Option A — Claude only (device/browser voice):** no OpenAI key needed.

```bash
flutter run --dart-define=ANTHROPIC_API_KEY=sk-ant-... \
            --dart-define=TRANSLATION_PROVIDER=claude \
            --dart-define=VOICE_ENGINE=device
```

**Option B — OpenAI (cloud voice covers STT + translate + TTS):**

```bash
flutter run --dart-define=OPENAI_API_KEY=sk-...
```

#### Configurable environment values

| Variable                 | Default                        | Purpose                                        |
| ------------------------ | ------------------------------ | ---------------------------------------------- |
| `TRANSLATION_PROVIDER`   | auto (`openai`/`claude`)       | Which translator to use                        |
| `VOICE_ENGINE`           | `device` on web, else `cloud`  | `cloud` (OpenAI) or `device` (built-in speech) |
| `OPENAI_API_KEY`         | _(empty)_                      | OpenAI key (cloud voice + OpenAI translate)    |
| `OPENAI_BASE_URL`        | `https://api.openai.com/v1`    | Override for proxies / gateways                |
| `OPENAI_STT_MODEL`       | `whisper-1`                    | Speech-to-text model                           |
| `OPENAI_TRANSLATE_MODEL` | `gpt-4o-mini`                  | OpenAI translation model                       |
| `OPENAI_TTS_MODEL`       | `gpt-4o-mini-tts`              | Text-to-speech model                           |
| `OPENAI_TTS_VOICE`       | `alloy`                        | Voice used for spoken output                   |
| `ANTHROPIC_API_KEY`      | _(empty)_                      | Claude key (translation)                       |
| `ANTHROPIC_MODEL`        | `claude-3-5-sonnet-latest`     | Claude model                                   |
| `TRANSLATE_PROXY_URL`    | _(empty)_                      | If set, translation goes through this URL (keeps keys server-side; e.g. `/api/translate`) |

> Without any usable key/proxy, the app still launches and shows the JARVIS UI
> with a banner explaining what to add. You can also flip **Translator** and
> **Voice engine** live from the toggles at the top of the screen.

### 4. Run

```bash
# Android (device/emulator attached)
flutter run -d android --dart-define=ANTHROPIC_API_KEY=sk-ant-... --dart-define=VOICE_ENGINE=device

# Desktop
flutter run -d linux   --dart-define=OPENAI_API_KEY=sk-...
flutter run -d macos   --dart-define=OPENAI_API_KEY=sk-...
flutter run -d windows --dart-define=OPENAI_API_KEY=sk-...

# Web (quick UI testing) — uses device/browser voice by default
flutter run -d chrome  --dart-define=ANTHROPIC_API_KEY=sk-ant-... --dart-define=TRANSLATION_PROVIDER=claude
```

> Note on `flutter run -d chrome` locally: the Anthropic API blocks direct
> browser calls (CORS), so for local *web* use either run the native app, or run
> behind the Vercel proxy (below) which is the intended web path.

---

## Live web demo & deployment

The web UI auto-deploys to **GitHub Pages** via
[`.github/workflows/deploy-web.yml`](.github/workflows/deploy-web.yml):

**https://thvb1133.github.io/jarvis_Translator/**

**Required one-time setup (repo owner):** open **Settings → Pages → Source:
GitHub Actions**. GitHub does not allow a workflow's default token to enable
Pages on its own, so this single toggle must be done by hand once. After that,
every push to `main` (or a `cursor/**` branch) deploys automatically, and the
workflow can also be triggered manually from the Actions tab.

> **GitHub Pages is a static host with no serverless functions**, so it's a
> **UI + browser-voice demo**; live translation from the browser is blocked by
> provider CORS. For a fully working web app with translation, use the **Vercel**
> deployment below (it ships a serverless proxy). The **native Android/desktop
> apps** take a key at run time and are the most flexible way to use a real key.

---

## Deploy to Vercel with a Claude API key only

This repo is Vercel-ready: [`vercel.json`](vercel.json) builds the Flutter web
app, and [`api/translate.js`](api/translate.js) is a serverless function that
calls Claude **server-side**, so your key never touches the browser. The web
build is configured to use the **device/browser voice** engine, so **the only
secret you need is your Claude key**.

**Steps:**

1. Push this repo to GitHub (already done) and go to
   [vercel.com/new](https://vercel.com/new) → **Import** `jarvis_Translator`.
2. Vercel reads `vercel.json` automatically (Framework Preset: **Other**). No
   changes needed — it clones Flutter and runs `flutter build web`.
3. In **Settings → Environment Variables**, add:
   - `ANTHROPIC_API_KEY` = your Claude key (`sk-ant-...`)
   - _(optional)_ `ANTHROPIC_MODEL` to pin a specific model.
4. **Deploy.** The build produces `build/web`, and requests to `/api/translate`
   are handled by the serverless function using your key.

That's it — open the Vercel URL, press and hold the orb, and speak. Listening
and speaking use the browser's built-in speech; translation runs through Claude
on the server.

> **Browser support:** speech recognition in the browser works best in
> Chrome/Edge. Grant microphone permission when prompted. If a browser lacks
> speech recognition, switch **Voice engine → Cloud** and add an `OPENAI_API_KEY`
> instead.

---

## Get the Android app (APK)

The [`build-android`](.github/workflows/build-android.yml) workflow builds an
installable APK on every push and on demand:

1. Open the repo's **Actions** tab → **Build Android APK** → a green run (or
   click **Run workflow** to trigger one).
2. Download **`jarvis-translator-apk`** from the run's **Summary → Artifacts**.
3. Copy the APK to your Android phone and install it (enable "install from
   unknown sources" when prompted).

To bake a key into the APK so it translates immediately, add `OPENAI_API_KEY`
(or `ANTHROPIC_API_KEY` / `TRANSLATE_PROXY_URL`) as a repo **Actions secret**
first. Without a key the app still installs and runs the UI; the free **Device**
voice engine works with no key (only translation needs one).

For Play Store distribution you additionally need a Google Play developer account
and app signing — out of scope for this repo's automated build.

---

## Using it

1. Pick the **Translate to** language (and optionally set the speaker language,
   or leave it on **Auto-detect**).
2. **Press and hold the orb** to talk (push-to-talk). Release to translate.
3. The app transcribes, translates, and **speaks** the result; the mic is muted
   while it speaks to avoid echo.
4. The **transcript** panel shows every utterance (original + translation).

### Roadmap

- [x] MVP: end-to-end pipeline (push-to-talk → detect → translate → speak),
      JARVIS orb + space UI, on-screen transcripts.
- [x] Live "talking" orb visualizer that reacts to the mic.
- [x] Claude translator + Vercel serverless proxy (Claude-key-only web deploy).
- [x] Device/browser voice engine (free, on-device, key-free).
- [ ] Hands-free voice-activity detection (VAD) in addition to push-to-talk.
- [ ] Group / multi-speaker sessions.
- [ ] Higher-quality on-device offline translation (NLLB-200).
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
