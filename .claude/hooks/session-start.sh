#!/bin/bash
# Prepares a Claude Code on the web session to build, test, and lint this
# Flutter Web project: installs the Flutter SDK (if missing) and fetches
# dependencies. Idempotent and non-interactive.
set -euo pipefail

# Only run in remote (web) sessions; local machines already have Flutter.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

FLUTTER_DIR="/opt/flutter"
LOG="/tmp/flutter-setup.log"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"

trap 'echo "Flutter setup failed — last log lines:"; tail -n 25 "$LOG" 2>/dev/null' ERR

{
  # Install the stable Flutter SDK only if it is not already present.
  if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
    git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$FLUTTER_DIR"
  fi

  git config --global --add safe.directory "$FLUTTER_DIR" || true
  git config --global --add safe.directory "$PROJECT_DIR" || true

  export PATH="$PATH:$FLUTTER_DIR/bin"

  flutter config --enable-web --no-analytics
  flutter precache --web
  (cd "$PROJECT_DIR" && flutter pub get)
} >"$LOG" 2>&1

# Persist Flutter on PATH for the rest of the session.
echo "export PATH=\"\$PATH:$FLUTTER_DIR/bin\"" >> "$CLAUDE_ENV_FILE"

echo "Flutter ready: $("$FLUTTER_DIR/bin/flutter" --version 2>/dev/null | head -n 1). Dependencies fetched."
