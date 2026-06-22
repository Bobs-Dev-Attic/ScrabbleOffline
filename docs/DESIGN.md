# Scrabble Offline — Design Documentation

A 100% offline, standalone Scrabble game built with **Flutter Web** and
deployed as a static **Progressive Web App** (PWA) on Vercel. There are no
servers, no cloud services, and no network calls during gameplay: word
validation, the AI opponent, and persistence all run on-device.

This document explains how the app is structured and why. For the
chronological list of changes, see [`CHANGELOG.md`](../CHANGELOG.md). For the
high-level product spec, see [`CLAUDE.md`](../CLAUDE.md).

---

## 1. Goals & constraints

- **No cloud dependencies.** No Firebase/AWS/external DB. Everything is in the
  asset bundle or local storage.
- **Fully offline at runtime.** After the first load the app must launch and
  play with no network (including airplane mode once installed).
- **Static deployment.** `flutter build web --release` produces static assets
  that fit Vercel's free tier.
- **Local validation.** Words are checked on-device via an in-memory prefix
  tree (Trie) with `O(L)` lookups.
- **State persistence.** Game state is written locally after every valid turn.

---

## 2. Layered architecture

The code is organized into four layers under `lib/`, with dependencies
pointing downward only (UI → state → engine → models):

```
lib/
├── models/     Pure data: Tile, TileBag, Player, Board (no Flutter imports)
├── engine/     Pure logic: Trie, Dictionary, Referee, MoveGenerator, AiPlayer
├── state/      Controllers: GameState (ChangeNotifier), Settings, Persistence
└── ui/         Widgets: HomeScreen (main.dart), GameScreen, Board, Rack, …
```

- **`models/`** and **`engine/`** are plain Dart with no UI dependencies, which
  keeps them fast and unit-testable (see `test/`).
- **`state/`** owns mutable game/session state and notifies the UI.
- **`ui/`** is declarative and reads from `state/` via `AnimatedBuilder`.

Each source file begins with a short header comment describing its role.

---

## 3. Data models (`lib/models/`)

### Tile (`tile.dart`)
Immutable: `letter`, point `value`, and blank-tile tracking. Blanks carry an
assigned letter for play but score zero.

### TileBag (`tile_bag.dart`)
Instantiated with the standard 100-tile English distribution
(`kStandardDistribution`) and shuffled with **Fisher–Yates**. Supports drawing
and returning tiles (for swaps).

### Player (`player.dart`)
`score`, a `rack` of up to `kRackCapacity` (7) tiles, and an `isAI` flag for
pass-and-play and bot seats. Each physical rack tile also gets a stable,
ephemeral **id** (`rackIds`) so the UI can animate reordering smoothly without
the ids being persisted.

### Board (`board.dart`)
A 15×15 grid. Each cell has a `CellType` premium classification
(standard, DL, TL, DW, TW, center) and an optional committed `Tile`.

---

## 4. Engine (`lib/engine/`)

### Trie (`trie.dart`)
An in-memory prefix tree. `contains` and `hasPrefix` are `O(L)` in the query
length and case-insensitive. `clear()` allows rebuilding in place (used by the
"Update word list" action) while keeping the same `Trie` instance, so holders
like the move generator stay valid. The `root` is exposed for traversal.

### Dictionary (`dictionary.dart`)
Loads `assets/dictionary.txt` into the Trie at boot via `rootBundle`. An
optional **expanded supplement** (`assets/dictionary_extended.txt`) is lazily
loaded into a `Set` and consulted only when **permissive mode** is on — this is
the "casual / edgy words" toggle. `refreshFromRaw` rebuilds the list from fresh
text for the in-app dictionary update.

### Referee (`referee.dart`)
The scoring authority. For a set of `Placement`s it:
1. verifies the tiles share a single axis and form a **contiguous** chain
   connected to existing tiles (the first move must cross the center);
2. extracts the main word and all **perpendicular cross-words** via
   bidirectional sweeps;
3. validates every formed word against the `Dictionary`;
4. scores: letter values × letter multipliers (DL/TL), then × word multipliers
   (DW/TW) per word, plus a **+50 bingo bonus** when all 7 tiles are used.

Returns a `MoveResult` (validity, scored words, total).

### MoveGenerator (`move_generator.dart`)
Anchor-based generation of all legal moves for a given rack and board, across
both axes, using the Trie for prefix pruning and the Referee for
validation/scoring. Produces a list of fully-scored `GeneratedMove`s. Used by
**both** the AI and the human **Suggest** feature.

### AiPlayer (`ai_player.dart`)
Wraps the generator. `AiDifficulty` selects which candidate to play:
- **hard** — the highest-scoring move;
- **medium** — a strong-but-not-optimal move;
- **easy** — generally avoids the very best move;
- falls back to exchanging tiles or passing when no move exists.

---

## 5. State management (`lib/state/`)

### GameState (`game_state.dart`) — the hub
A `ChangeNotifier` that owns the live game: players, board, bag, current turn,
pending (uncommitted) placements, the AI turn, the Suggest cycle + ghost tiles,
the play-history log, and persistence triggers. The UI listens via
`AnimatedBuilder`, so any `notifyListeners()` rebuilds the relevant widgets.

Key responsibilities:
- **Turn flow:** place/recall/move pending tiles, validate & commit via the
  Referee, refill racks, advance turns, run AI turns, detect game end.
- **Suggest:** rearranges the rack to lead with a suggested word and shows
  translucent **ghost tiles** on the board; repeated presses cycle through
  alternatives. Ghosts hold briefly, then fade out over `kGhostFadeMs` (~8.5s),
  whether or not the player starts placing (see `_scheduleGhostFade` /
  `_beginGhostFade`).
- **History:** every committed move, pass, and swap appends a `MoveLogEntry`
  for the on-screen play-history strip.
- **Persistence:** after each valid turn the state is saved (below).

### Settings (`settings.dart`)
An observable, Hive-persisted `SettingsController` for the selected board theme
(`AppThemeId`) and dictionary mode (permissive on/off).

### Persistence (`persistence.dart`)
A thin Hive layer. The game serializes to a single box,
`scrabble_game_state`, under three keys — `board_matrix`, `player_pool`,
`bag_state` — and is reloaded on launch. No native binaries are required, which
keeps the web build simple.

---

## 6. UI layer (`lib/ui/` + `main.dart`)

- **`main.dart`** is the entry point and `HomeScreen`: it bootstraps Hive, the
  dictionary, and settings, shows offline-ready/update indicators and the
  Install button, and hosts the new-game flow (opponents + difficulty).
- **`game_screen.dart`** composes the scoreboard (one row: player columns +
  bag), status bar, board, rack, action controls (Pass/Swap/Recall/Suggest/
  Play), and the scrolling play-history strip. It adapts between a wide and a
  narrow (mobile) layout.
- **`board_widget.dart`** renders the grid and committed / pending / ghost
  tiles, and hosts `DragTarget`s. Rack tiles (`RackDragData`) and pending tiles
  (`BoardDragData`) can be dropped onto empty cells; ghost tiles use
  `AnimatedOpacity` keyed to `GameState.ghostsFading`.
- **`rack_widget.dart`** is an animated, reorderable rack (drag to the board, to
  another tile to reorder, or back to recall).
- **`tile_widget.dart`** draws a tile with an optional 3D bevel/gloss.
- **`animated_background.dart`** is the drifting gradient backdrop (static under
  the battery-saver theme).

### Theming (`game_theme.dart`)
Each `AppThemeId` maps to a `GameTheme` (palette + behavior flags such as
`animated`, `richDecoration`, `flashy`). A `GameThemeScope` `InheritedWidget`
publishes the active theme so widgets rebuild reactively when it changes via
`SettingsController`.

---

## 7. Offline & PWA strategy

Making a Flutter web app reliably installable and offline-capable required
working around Flutter's defaults:

- **No runtime CDN.** Built with `--no-web-resources-cdn` and a bundled Roboto
  font so CanvasKit/fonts never hit `gstatic` at runtime.
- **Stable icon font.** Built with `--no-tree-shake-icons` so Material icon
  codepoints don't shift between builds (which previously caused blank icons
  when an old cached font met new code).
- **Real service worker.** Flutter's generated `flutter_service_worker.js` is a
  no-op that caches nothing. After each build, `tool/build_sw.py` overwrites it
  with a caching worker that **precaches** the app shell, CanvasKit, fonts, and
  dictionaries (`cache: 'reload'`), serves a navigation fallback to
  `index.html`, treats `?fresh` requests as network-first (for the in-app
  dictionary/update checks), and applies a new version on demand via a
  `SKIP_WAITING` message (no surprise auto-refresh). The script also disables
  Flutter's own registration so it can't clobber ours; we register the worker
  from `web/index.html`.
- **JS interop.** `lib/ui/pwa_install.dart` exposes guarded bindings
  (`pwaInstallAvailable`, `pwaPromptInstall`, `pwaOfflineReady`,
  `pwaUpdateAvailable`, `pwaCheckForUpdate`, `pwaApplyUpdate`, `pwaIsOnline`,
  `pwaFetchText`) to helpers defined in `web/index.html`.

`vercel.json` serves assets with `must-revalidate` (no long-lived immutable
caching) so updates propagate; the service worker provides the offline cache.

---

## 8. Build & deployment

- **Local build:**
  `flutter build web --release --no-web-resources-cdn --no-tree-shake-icons`
  then `python3 tool/build_sw.py`.
- **Vercel:** `vercel.json` runs `vercel_build.sh`, which clones the Flutter
  SDK, runs the same build, then `tool/build_sw.py`. Output is `build/web`;
  all routes rewrite to `/index.html` (SPA).
- **Versioning:** bump `kAppVersion` in `lib/app_info.dart` and `version:` in
  `pubspec.yaml`, and add a `CHANGELOG.md` entry.
- **Icons:** regenerated by `tool/generate_icons.py` (cream "S₁" tile with a red
  no-Wi-Fi badge on board green).

---

## 9. Testing

Unit/logic tests live in `test/` and run with `flutter test` (no browser
needed) because the engine and models are UI-free:

- `engine_test.dart` — Trie, TileBag, Referee scoring/validation.
- `ai_test.dart` — move generation and difficulty selection.
- `game_flow_test.dart` — a full human→computer turn cycle.
- `dictionary_modes_test.dart` — standard vs. permissive validation.
- `rack_suggest_test.dart` — reorder, Suggest cycling, live preview score,
  pending-tile moves, multi-computer setup, and ghost-fade timing (using
  `fake_async`).
- `perf_test.dart` — dictionary/validation performance sanity.

---

## 10. Directory map

```
lib/            Dart source (models / engine / state / ui), see §2
assets/         dictionary.txt, dictionary_extended.txt, fonts/
web/            index.html (+ PWA helpers), manifest.json, icons/
tool/           build_sw.py (service worker), generate_icons.py
test/           unit/logic tests
docs/DESIGN.md  this document
CHANGELOG.md    release notes
CLAUDE.md       product spec / architectural boundaries
vercel.json     Vercel build + headers + SPA rewrites
vercel_build.sh build script run by Vercel
```
