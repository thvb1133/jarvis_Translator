#!/usr/bin/env bash
# Vercel build script for the Kimchi Jarvis Flutter web app.
#
# Kept in a script (instead of inline in vercel.json) because Vercel limits
# `buildCommand` to 256 characters. Clones the Flutter SDK, then builds the web
# app configured for the free translator + device voice, with the serverless
# proxies wired up so translation and Kimchi chat work on the deployed site.
set -euo pipefail

if [ -d flutter ]; then
  (cd flutter && git pull --ff-only || true)
else
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi

export PATH="$PATH:$PWD/flutter/bin"

flutter config --enable-web --no-analytics
flutter pub get
flutter build web --release \
  --dart-define=TRANSLATE_PROXY_URL=/api/translate \
  --dart-define=CHAT_PROXY_URL=/api/chat \
  --dart-define=TRANSLATION_PROVIDER=free \
  --dart-define=VOICE_ENGINE=device
