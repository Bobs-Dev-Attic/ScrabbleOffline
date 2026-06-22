# TODO — Senior Review Backlog

Prioritized backlog from a cross-functional review of ScrabbleOffline. Use this as a living planning document, not a rigid specification. The app is intentionally offline-first and static-hosted; recommendations preserve that architecture unless explicitly marked as optional.

> **Status legend:** ✅ done · ⚠️ partially done · ⏸️ deferred (measure first) · 🔵 decision recorded · ⬜ open.
> P0/P1 items were triaged on 2026-06-22 (v1.10.0).

## P0 — Security, privacy, and correctness must-haves

1. ✅ **Add defensive load validation and recovery for persisted Hive state.**
   - _Done (v1.10.0): `GamePersistence` now stores a single versioned snapshot; `load()` validates board cells, player count, rack size, and current index, and on any failure clears the bad data and reports `lastLoadError` (the Home "Continue" button shows a recovery message instead of crashing). Covered by `test/persistence_test.dart`._
   - `GamePersistence.load()` currently casts local Hive values directly. A corrupted browser storage entry, stale schema, or malicious DevTools edit can throw during startup/continue and strand the user.
   - Add schema/version metadata, bounds checks for board dimensions, rack sizes, current player index, tile counts, and safe fallback to `clear()` plus a friendly recovery message.
   - Add tests with malformed `board_matrix`, `player_pool`, `bag_state`, and `meta` payloads.

2. ⚠️ **Define and enforce Content Security Policy (CSP) and security headers.**
   - _Partial (v1.10.0): added `X-Content-Type-Options: nosniff`, `Referrer-Policy: no-referrer`, `X-Frame-Options: SAMEORIGIN`, and a restrictive `Permissions-Policy` in `vercel.json`. A strict CSP is deferred: Flutter/CanvasKit needs `wasm-unsafe-eval` and the PWA helpers are inline; externalizing that script + a hash-based CSP is the remaining work and low-value for a no-secrets, same-origin app._
   - `web/index.html` contains inline JavaScript for PWA helpers, which blocks a strict nonce/hash-based CSP today.
   - Move PWA helper code to a static external JS file or generate a stable script hash during build.
   - Add Vercel headers: `Content-Security-Policy`, `X-Content-Type-Options: nosniff`, `Referrer-Policy: no-referrer`, `Permissions-Policy` denying sensors/camera/microphone/geolocation, and `Cross-Origin-Opener-Policy` where compatible.

3. ✅ **Make dictionary update paths integrity-aware.**
   - _Done (v1.10.0): `Dictionary.looksLikeWordList` enforces size/line/min-count limits and an alphabetic sample check; `refreshFromRawValidated` leaves the live dictionary untouched on a bad response, and `pwaFetchText` has a 20s timeout. SHA manifest left as optional (same-origin only). Covered by `test/dictionary_validation_test.dart`._
   - Fresh dictionary fetches are same-origin and optional, but they should be treated as untrusted text.
   - Add max-size limits, line-count limits, character allowlists, timeout handling, and a post-fetch sanity check before `refreshFromRaw()` replaces the trie.
   - Optional: publish a build-time dictionary manifest with SHA-256 hashes and verify downloaded text before accepting it.

4. 🔵 **Document legal/trademark posture.**
   - _Decision (2026-06-22): treated as a personal / portfolio project — no action taken. Revisit (non-infringing name + disclaimer + word-list provenance) before any wider public release._
   - “Scrabble” is a trademark in many jurisdictions. Confirm whether the project is private/internal, educational, or public-facing.
   - If public, consider a non-infringing product name, disclaimer, and review of dictionary licensing/word-list provenance.

## P1 — Performance, memory usage, and reliability

5. ⏸️ **Profile trie and move-generation memory on low-end mobile devices.**
   - _Deferred (v1.10.0): nothing is observably slow; revisit only if profiling on real devices shows a problem. Keep `test/perf_test.dart` as the guardrail._
   - Loading ~178k words into object-heavy trie nodes can be memory-expensive in Flutter Web.
   - Benchmark startup memory, time-to-interactive, and AI/suggest latency on Android Chrome and iOS Safari.
   - Consider a compact DAWG, double-array trie, minimal perfect hash for validation, or compressed binary dictionary asset if heap usage is high.

6. ⏸️ **Move expensive AI/suggestion generation off the UI isolate where possible.**
   - _Deferred (v1.10.0): Flutter web doesn't truly parallelize `compute`/isolates (dart2js), and generation is fast for normal racks. The suggestion cycle is already capped at 25. Revisit with a search cap only if lag appears._
   - `MoveGenerator.generate()` may block rendering for large racks/boards, especially after mid-game branching increases.
   - Use `compute`, web workers, chunked generation, cancellation tokens, or difficulty-specific search caps.
   - Add hard latency budgets: e.g., Suggest <300 ms perceived, AI easy/medium <750 ms, hard with progress indicator/cancel.

7. ✅ **Bound caches and history.**
   - _Done (v1.10.0): move history is capped at the most recent 200 entries (`GameState.kMaxHistory`); the suggestion cycle was already capped at 25. SW runtime cache cap left as optional._
   - Add explicit maximums for suggestion cycles, move history entries displayed/persisted, service-worker runtime cached responses, and any generated-move lists.
   - Avoid holding full move lists when only top-k candidates are needed for AI difficulty selection.

8. ✅ **Make persistence atomic and observable.**
   - _Done (v1.10.0): one versioned snapshot written in a single `put` (no partial blends); load failures surface via `lastLoadError`. A dedicated quota-failure UI / "download backup" escape hatch remains optional follow-up._
   - `save()` performs multiple independent writes. A browser crash or quota failure between writes can produce partial snapshots.
   - Prefer one versioned snapshot key, then update a small pointer/current marker after successful serialization.
   - Surface quota/storage failures to the UI and add a “download backup / reset local data” escape hatch.

9. ✅ **Add lifecycle cleanup for timers and notifiers.**
   - _Done (v1.10.0): `GameState.dispose()` cancels the ghost-fade timers, and the ghost/AI async callbacks bail out when `_disposed`._
   - `GameState` owns timers for AI/ghost behavior. Override `dispose()` and cancel all timers to avoid leaks in tests and hot reload sessions.

## P2 — UX design and accessibility

10. **Improve first-run clarity and rules affordances.**
    - Add a compact onboarding panel that explains offline mode, pass-and-play vs computer, drag/drop, blank tile assignment, and scoring basics.
    - Include a “why was this move invalid?” details dialog that lists exact validation failure causes.

11. **Upgrade accessibility semantics.**
    - Add keyboard controls for tile selection/placement, focus order for board cells, semantic labels for premium cells and tiles, and high-contrast checks for each theme.
    - Ensure animations respect reduced-motion preferences beyond the battery-saver theme.

12. **Reduce mobile drag friction.**
    - Dragging on dense 15×15 grids is hard on small phones.
    - Add tap-to-select tile then tap board cell placement, larger hit targets, zoom/pan mode, and haptic-style visual feedback.

13. **Make AI and Suggest transparent.**
    - Explain difficulty behavior in the dialog.
    - For Suggest, show score preview and affected words, but avoid making the feature feel like an auto-solver unless intentionally marketed that way.

## P3 — Engineering best practices and maintainability

14. **Add architecture decision records (ADRs).**
    - Capture why Hive, Flutter Web, Vercel static hosting, trie validation, and custom service worker were chosen.
    - Include rejected alternatives and revisit triggers.

15. **Expand CI checks.**
    - Run `flutter analyze`, `flutter test`, service-worker generation smoke tests, version-sync test, web release build, and optionally Lighthouse/PWA audits.
    - Add dependency review and secret scanning even though the app has no backend.

16. **Add fuzz/property tests for referee and persistence.**
    - Generate random boards/racks/placements and verify invariants: no overlapping commits, scores non-negative, all pending placements cleared after recall/commit, tile totals conserved.

17. **Document release and rollback procedures.**
    - Include Vercel deployment flow, cache-busting/update behavior, how to verify offline install, and how to recover from a bad service worker.

## P4 — Product, growth, and executive considerations

18. **Clarify target market and positioning.**
    - Decide whether this is a casual offline word-game, a Scrabble training tool, a PWA portfolio demo, or an accessibility-first board-game app.
    - Messaging, feature priorities, and legal risk differ by positioning.

19. **Add privacy and data-retention copy.**
    - The offline architecture is a strength: clearly state that gameplay stays on-device and no account is required.
    - Document exactly what is stored locally and how users can erase it.

20. **Consider optional non-invasive analytics only if product goals require it.**
    - Default should remain no telemetry.
    - If analytics are introduced, make them opt-in, privacy-preserving, and compatible with offline mode and applicable privacy laws.

21. **Plan brand-safe expansion features.**
    - Candidate improvements: multiple language dictionaries, daily local challenges, puzzle mode, local multiplayer variants, tutorial mode, import/export saves, and theme packs.
