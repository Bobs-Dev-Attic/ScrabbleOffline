#!/usr/bin/env bash
# Builds the Flutter Web release bundle inside Vercel's build container.
# Vercel does not ship Flutter, so we fetch a pinned stable SDK on demand and
# compile to static assets in build/web (zero runtime/server dependencies).
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-stable}"
FLUTTER_DIR="$HOME/flutter"

if [ ! -d "$FLUTTER_DIR" ]; then
  echo "Fetching Flutter SDK ($FLUTTER_VERSION)…"
  git clone --depth 1 -b "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi

export PATH="$PATH:$FLUTTER_DIR/bin"

flutter config --enable-web --no-analytics
flutter pub get
# --no-web-resources-cdn bundles CanvasKit locally so the app loads with zero
# external CDN dependencies (truly offline, per the project requirements).
flutter build web --release --no-web-resources-cdn
