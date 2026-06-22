# SECURITY_REVIEW — Offline PWA Threat Model

## Executive summary

The app has a favorable baseline because gameplay is local-only: there are no accounts, payments, backend APIs, cloud databases, or multiplayer network channels. The main security concerns are therefore client-side integrity, supply chain, browser storage abuse/corruption, service-worker update behavior, legal/privacy transparency, and web hardening headers.

## Assets worth protecting

- User trust that the app works offline and does not transmit gameplay.
- Local saved games and preferences in browser storage.
- Dictionary assets and generated service worker integrity.
- Brand/legal posture around the product name and word-list licensing.
- Availability: avoiding startup crashes from corrupted local state or stale caches.

## Likely attacker or failure scenarios

1. A stale or compromised service worker serves broken assets.
2. A user or extension mutates Hive/IndexedDB data and crashes restore.
3. A future dictionary-update feature accepts unexpectedly large or malformed text.
4. A hosting misconfiguration allows weaker browser defaults than necessary.
5. A dependency or build script changes behavior unexpectedly in CI/Vercel.
6. Trademark/licensing complaints force urgent rebranding or dictionary replacement.

## Recommended controls

### Web platform hardening

- Move inline PWA helper JavaScript out of `web/index.html` so strict CSP can be deployed.
- Add security headers in `vercel.json`:
  - `Content-Security-Policy` with `default-src 'self'` and the minimum Flutter/CanvasKit allowances required.
  - `X-Content-Type-Options: nosniff`.
  - `Referrer-Policy: no-referrer`.
  - `Permissions-Policy: camera=(), microphone=(), geolocation=(), payment=(), usb=(), serial=()`.
  - `Cross-Origin-Opener-Policy: same-origin` after compatibility testing.

### Persistence hardening

- Store a single versioned snapshot object rather than several independent keys.
- Validate all restored fields before constructing game objects.
- Handle Hive exceptions and quota failures without exposing stack traces to users.
- Add a “Reset local data” action and optional save export/import.

### Service worker and update safety

- Keep update application user-initiated.
- Add a documented emergency rollback path for bad workers.
- Put a maximum runtime cache size/entry count in the service worker.
- Consider adding an asset manifest hash check for critical text assets.

### Privacy and compliance

- Publish plain-language privacy copy: no accounts, no telemetry, gameplay stored locally only.
- If analytics or crash reporting are ever added, make them opt-in and document data categories, retention, and processors.
- Confirm word-list licensing and product naming before public distribution.

### Supply chain

- Keep Flutter SDK pinning explicit in `vercel_build.sh`.
- Add automated dependency review and lockfile drift checks.
- Avoid dynamic script loads or runtime CDNs.

## Pen-test notes

Because this is a static offline PWA, classic API issues such as SQL injection, SSRF, IDOR, auth bypass, and server-side RCE are not applicable unless new networked services are added. Focus manual testing on CSP bypasses, service-worker cache poisoning, malformed local storage, denial-of-service via oversized dictionary text, and hostile browser-extension/local-storage mutation.
