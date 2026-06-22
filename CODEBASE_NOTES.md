# CODEBASE_NOTES — Fast Context for Coding Agents

This file is optimized for Codex/Claude-style agents to reduce repeated repository exploration.

## Product shape

ScrabbleOffline is a Flutter Web PWA that runs entirely on-device. No backend, Firebase, account system, or remote gameplay exists. Static hosting targets Vercel.

## Core commands

```bash
flutter pub get
flutter analyze
flutter test
flutter build web --release --no-web-resources-cdn --no-tree-shake-icons
python3 tool/build_sw.py
python3 tool/sync_version.py
```

If Flutter is missing in the environment, inspect `vercel_build.sh` and `.claude/hooks/session-start.sh` before adding new tooling.

## Important files

- `README.md` — quick project overview, run/deploy instructions, version workflow.
- `CLAUDE.md` — high-level product/architecture boundaries.
- `docs/DESIGN.md` — detailed architecture and PWA/service-worker notes.
- `TODO.md` — prioritized review backlog across security, memory, UX, legal, and product.
- `lib/main.dart` — bootstraps Hive, dictionary, settings, home screen, PWA indicators.
- `lib/state/game_state.dart` — central controller for turn flow, AI turns, suggestions, history, and persistence triggers.
- `lib/state/persistence.dart` — Hive save/load layer.
- `lib/state/settings.dart` — persisted theme and dictionary mode.
- `lib/engine/dictionary.dart` — asset dictionary loading and permissive dictionary supplement.
- `lib/engine/referee.dart` — move validation and scoring authority.
- `lib/engine/move_generator.dart` — legal move generation for AI and Suggest.
- `tool/build_sw.py` — replaces Flutter's default worker with the offline caching worker after release builds.
- `web/index.html` — PWA install/update helper JavaScript and manual service-worker registration.
- `vercel.json` / `vercel_build.sh` — static deployment configuration.

## Architectural constraints to preserve

- Keep gameplay and validation offline by default.
- Avoid introducing network dependencies, accounts, server functions, or third-party SDKs unless the user explicitly asks.
- Keep model/engine code UI-free so tests stay fast.
- Prefer deterministic, pure-Dart tests for engine changes.
- If changing versioned behavior, update `CHANGELOG.md` first and run `python3 tool/sync_version.py`.

## Common risk areas

- Persistence currently assumes valid Hive payloads; harden before changing schema.
- Dictionary and trie loading can dominate startup memory/time on mobile web.
- Move generation can become expensive; avoid UI-isolate blocking when adding AI/Suggest features.
- Inline PWA helper script in `web/index.html` complicates strict CSP.
- Service-worker changes must be verified with a release build plus `tool/build_sw.py`; debug `flutter run` is not enough.

## Testing guidance

- For engine/model/state changes, run `flutter test` and targeted tests in `test/`.
- For UI-only changes, run `flutter analyze`; use screenshots if visual output changes.
- For PWA/offline changes, run release build, `python3 tool/build_sw.py`, then inspect generated `build/web/flutter_service_worker.js` and test offline behavior in a browser.
