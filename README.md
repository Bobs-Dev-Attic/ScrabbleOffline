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

## Run locally

```bash
flutter pub get
flutter run -d chrome        # development
flutter test                 # run the engine unit tests
flutter build web --release  # production static bundle -> build/web
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
