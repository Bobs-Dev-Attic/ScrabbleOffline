#!/usr/bin/env python3
"""Post-build step: replace Flutter's no-op service worker with one that
precaches the app shell + assets so the installed PWA launches fully offline.

Flutter's generated flutter_service_worker.js unregisters itself and caches
nothing, so an installed PWA hangs on the splash in airplane mode. We overwrite
it (the bootstrap already registers flutter_service_worker.js) with a real
cache-first worker.
"""
import hashlib
import json
import os

ROOT = "build/web"
SW = os.path.join(ROOT, "flutter_service_worker.js")

# CanvasKit ships several variants; only these are loaded by the default
# (non-wasm) CanvasKit build, across Chrome and Safari. The rest (skwasm,
# wimp, experimental, *.symbols) are skipped to keep the cache lean — runtime
# caching still picks up anything actually fetched.
CANVASKIT_KEEP = {
    "canvaskit/canvaskit.js",
    "canvaskit/canvaskit.wasm",
    "canvaskit/chromium/canvaskit.js",
    "canvaskit/chromium/canvaskit.wasm",
}


def included(rel):
    if rel in ("flutter_service_worker.js", ".last_build_id"):
        return False
    if rel.endswith(".symbols"):
        return False
    if rel.startswith("canvaskit/"):
        return rel in CANVASKIT_KEEP
    return True


def main():
    files = []
    for dirpath, _, names in os.walk(ROOT):
        for n in names:
            rel = os.path.relpath(os.path.join(dirpath, n), ROOT).replace(os.sep, "/")
            if included(rel):
                files.append(rel)
    files.sort()

    h = hashlib.sha256()
    for rel in files:
        h.update(rel.encode())
        h.update(str(os.path.getsize(os.path.join(ROOT, rel))).encode())
    version = h.hexdigest()[:16]

    resources = json.dumps(files, indent=2)
    sw = """'use strict';
// Offline caching service worker for Scrabble Offline (PWA).
const CACHE = 'scrabble-offline-%s';
const RESOURCES = %s;

self.addEventListener('install', (event) => {
  // No skipWaiting(): a new version waits so the app can show "update available".
  // (On a first install there is no active worker, so it activates immediately.)
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE);
    // Cache individually so one failure doesn't abort the whole install.
    await Promise.allSettled(RESOURCES.map((url) => cache.add(url)));
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)));
    await self.clients.claim();
  })());
});

self.addEventListener('message', (event) => {
  if (event.data === 'SKIP_WAITING') self.skipWaiting();
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return; // pass through cross-origin

  event.respondWith((async () => {
    const cache = await caches.open(CACHE);
    const cached = await cache.match(req, { ignoreSearch: true });
    if (cached) return cached;
    try {
      const resp = await fetch(req);
      if (resp && resp.status === 200 && resp.type === 'basic') {
        cache.put(req, resp.clone());
      }
      return resp;
    } catch (err) {
      // Offline: fall back to the app shell for navigations.
      if (req.mode === 'navigate') {
        const shell = (await cache.match('index.html')) || (await cache.match('./'));
        if (shell) return shell;
      }
      throw err;
    }
  })());
});
""" % (version, resources)

    with open(SW, "w") as f:
        f.write(sw)
    print(f"Service worker written: {len(files)} resources, version {version}")

    # Disable Flutter's own (no-op, self-unregistering) service worker
    # registration so it can't clobber the caching worker we register from
    # index.html. Only the load() call-site property is renamed.
    bootstrap = os.path.join(ROOT, "flutter_bootstrap.js")
    with open(bootstrap) as f:
        content = f.read()
    patched = content.replace(
        "serviceWorkerSettings: {", "serviceWorkerSettingsDisabled: {", 1)
    if patched != content:
        with open(bootstrap, "w") as f:
            f.write(patched)
        print("Disabled Flutter's built-in service worker registration.")
    else:
        print("WARNING: serviceWorkerSettings call-site not found in bootstrap.")


if __name__ == "__main__":
    main()
