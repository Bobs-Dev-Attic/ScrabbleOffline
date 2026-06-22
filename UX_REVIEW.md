# UX_REVIEW — Design Critique and Improvement Ideas

## Strengths

- Offline-first positioning is clear and valuable.
- Drag-and-drop board interaction maps well to physical tile play.
- Theme support, installability, AI opponent, and Suggest provide good casual-player value.
- Move history and live score/bag information reduce cognitive load.

## Friction points to investigate

1. **Small-screen precision.** A 15×15 board is dense on phones. Drag targets may be too small for many users.
2. **Invalid move explanations.** Players need actionable feedback, not only a generic failure message.
3. **Blank tile flow.** Blank assignment must be fast and reversible, especially on touch screens.
4. **AI trust.** Users benefit from knowing whether Easy/Medium/Hard means speed, optimality, or intentionally weaker choices.
5. **Suggest expectations.** Suggest can feel like a hint, a cheat, or a teaching tool. Decide and label it accordingly.
6. **Accessibility.** Drag-only workflows can exclude keyboard, switch-control, and screen-reader users.

## Recommended UX backlog

- Add tap-to-place as an alternative to drag-and-drop.
- Add board zoom or focus mode for mobile.
- Add semantic labels: tile letter/value, board coordinates, premium square type, occupied state.
- Add a move-review panel with formed words, premium multipliers, bingo bonus, and invalid-rule explanations.
- Respect reduced-motion settings for background and tile animations.
- Add high-contrast theme validation and a color-blind-safe premium-square palette.
- Add first-run onboarding and an always-available quick rules/help page.
- Add local data controls: Continue, New Game, Reset Saved Game, and privacy explanation.

## Marketing/product positioning

Possible positioning options:

- **“Offline word-board practice PWA”** — safest if public branding must avoid trademark risk.
- **“No-account family pass-and-play word game”** — emphasizes privacy and shared-device use.
- **“Scrabble-style training sandbox”** — emphasizes AI, Suggest, and dictionaries, but needs legal review.

The best message is probably privacy-first and offline-first: instant install, no signup, no tracking, works in airplane mode.
