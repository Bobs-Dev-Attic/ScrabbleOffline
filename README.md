# ScrabbleOffline

A 100% offline, standalone **Scrabble** game built with **Flutter Web** and
optimized for static deployment on **Vercel**. No cloud, no Firebase, no API
calls — all word validation, scoring, and state persistence happen entirely
on-device.

## Features

- **15×15 board** with the official premium-square layout (DL, TL, DW, TW, ★).
- **Pass-and-play** for two players with live scoreboard and bag counter.
- **Drag-and-drop** tiles from the rack onto the board (`Draggable` /
  `DragTarget`), with tap-to-recall and a one-tap **Recall** rollback.
- **Offline word validation** via an in-memory **Prefix Tree (Trie)** compiled
  at boot from `assets/dictionary.txt` (~178k TWL words). Lookups are `O(L)`.
- **Full referee engine**: single-axis + contiguity checks, center-square first
  move, board connectivity, perpendicular cross-word extraction, premium-square
  multipliers, and the **+50 Bingo** bonus.
- **Blank tiles**: assign any letter on placement; scored as zero.
- **Exchange** and **Pass** actions with standard end-game scoring.
- **Local persistence** with Hive — the game auto-saves after every valid turn
  and can be **Continued** on next load.

## Architecture

```
lib/
  models/        Pure-Dart domain models
    tile.dart        Immutable Tile (+ blank handling)
    tile_bag.dart    Standard 100-tile distribution, Fisher-Yates shuffle
    player.dart      Score, rack (max 7), isAI flag
    board.dart       15x15 GameBoard, Cell types & multipliers
  engine/        Offline algorithms
    trie.dart        Prefix tree for O(L) validation
    dictionary.dart  Loads assets/dictionary.txt via rootBundle
    referee.dart     Validation + cross-word scoring engine
  state/
    game_state.dart  ChangeNotifier game controller
    persistence.dart Hive persistence (box: scrabble_game_state)
  ui/
    board_widget.dart, rack_widget.dart, tile_widget.dart, game_screen.dart
  main.dart        Bootstrapping (dictionary + Hive) and home screen
```

State management uses `ChangeNotifier` + `AnimatedBuilder`. Persistence writes
three keys (`board_matrix`, `player_pool`, `bag_state`) to the
`scrabble_game_state` Hive box after each committed turn.

## Documentation

- **[`docs/DESIGN.md`](docs/DESIGN.md)** — full design documentation:
  architecture layers, data models, algorithms, persistence, theming, and the
  offline/PWA strategy.
- **[`CHANGELOG.md`](CHANGELOG.md)** — release notes / running list of updates.
- **[`CLAUDE.md`](CLAUDE.md)** — the product spec and architectural boundaries.

The displayed app version lives in `lib/app_info.dart` (`kAppVersion`) and
`pubspec.yaml`; bump both and add a `CHANGELOG.md` entry per release.

## Run locally

```bash
flutter pub get
flutter run -d chrome        # development
flutter test                 # run the engine unit tests

# production static bundle -> build/web
flutter build web --release --no-web-resources-cdn --no-tree-shake-icons
python3 tool/build_sw.py     # generate the offline caching service worker
```

## Deploy to Vercel

The repo ships a `vercel.json` and `vercel_build.sh`. Because Vercel's build
image does not include Flutter, the build script fetches a pinned stable SDK and
compiles to `build/web`, which is served as fully static assets.

- **Build command:** `bash vercel_build.sh`
- **Output directory:** `build/web`

Import the repo in Vercel (or `vercel --prod`); no environment variables or
server functions are required.

## Swapping the dictionary

Replace `assets/dictionary.txt` with any newline-delimited word list (uppercase,
2–15 letters). It is compiled into the Trie at startup.

## Developing from a mobile device

This repo is set up so the whole loop runs in the cloud — no local toolchain
needed. You drive it from the Claude Code web/mobile app.

- **Zero setup per session.** A `SessionStart` hook
  (`.claude/hooks/session-start.sh`) auto-installs the Flutter SDK and runs
  `flutter pub get` when a web session starts, so builds, tests, and lints are
  ready immediately. It only runs in web sessions and is idempotent.
- **The dev loop:** describe a change → Claude edits code → runs
  `flutter analyze` + `flutter test` → `flutter build web --release
  --no-web-resources-cdn` → commits and pushes.
- **See it without running anything.** Claude can render the built app in a
  headless browser and send you a screenshot in chat, so you can review UI
  changes on your phone.
- **Deploy = push to `main`.** Vercel auto-builds on push; Claude verifies the
  live deployment (and reads build logs to diagnose failures) via the Vercel
  connector.
- **Tip:** keep requests small and specific — easier to review on a phone and
  faster to verify.
