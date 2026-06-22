#!/usr/bin/env bash
# Builds the Flutter Web release bundle inside Vercel's build container.
# Vercel does not ship Flutter, so we fetch a pinned stable SDK on demand and
# compile to static assets in build/web (zero runtime/server dependencies).
set -euo pipefail

# Pin to an explicit SDK tag for reproducible builds (overridable via env).
# Matches the version used in development; bump deliberately.
FLUTTER_VERSION="${FLUTTER_VERSION:-3.44.2}"
FLUTTER_DIR="$HOME/flutter"

if [ ! -d "$FLUTTER_DIR" ]; then
  echo "Fetching Flutter SDK ($FLUTTER_VERSION)…"
  git clone --depth 1 -b "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi

export PATH="$PATH:$FLUTTER_DIR/bin"

flutter config --enable-web --no-analytics
flutter pub get
# Keep the displayed app version in lockstep with CHANGELOG.md (single source
# of truth): propagates the top changelog version into app_info.dart/pubspec.
python3 tool/sync_version.py
# --no-web-resources-cdn bundles CanvasKit locally so the app loads with zero
# external CDN dependencies (truly offline, per the project requirements).
# --no-tree-shake-icons ships the full Material Icons font with stable
# codepoints, so a cached older icon font can't mismatch newer code (which
# otherwise makes icons render blank after an update).
flutter build web --release --no-web-resources-cdn --no-tree-shake-icons

# Replace Flutter's no-op service worker with a caching one so the installed
# PWA launches fully offline (e.g. airplane mode).
python3 tool/build_sw.py
