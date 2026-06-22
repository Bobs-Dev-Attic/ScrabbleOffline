// lib/ui/pwa_install.dart —
//
// Guarded dart:js_interop bindings to the PWA install/offline/update helpers defined
// in web/index.html.
//
// See docs/DESIGN.md for how this fits the overall architecture.

import 'dart:js_interop';

/// Thin bindings to the PWA install helpers defined in web/index.html.
/// All calls are guarded so they degrade gracefully if unavailable.

@JS('pwaIsStandalone')
external JSBoolean _isStandalone();

@JS('pwaInstallAvailable')
external JSBoolean _installAvailable();

@JS('pwaPromptInstall')
external JSPromise<JSString> _promptInstall();

@JS('pwaOfflineReady')
external JSBoolean _offlineReady();

@JS('pwaUpdateAvailable')
external JSBoolean _updateAvailable();

@JS('pwaCheckForUpdate')
external JSPromise<JSString> _checkForUpdate();

@JS('pwaApplyUpdate')
external void _applyUpdate();

@JS('pwaIsOnline')
external JSBoolean _isOnline();

@JS('pwaFetchText')
external JSPromise<JSString> _fetchText(JSString url);

@JS('pwaGetLog')
external JSString _getLog();

@JS('pwaClearLog')
external void _clearLog();

@JS('pwaLog')
external void _log(JSString msg);

/// True when the app is already running as an installed PWA.
bool pwaIsStandalone() {
  try {
    return _isStandalone().toDart;
  } catch (_) {
    return false;
  }
}

/// True when the browser has offered an install prompt we can trigger
/// (Android/desktop Chromium). iOS Safari never reports true.
bool pwaInstallAvailable() {
  try {
    return _installAvailable().toDart;
  } catch (_) {
    return false;
  }
}

/// Triggers the native install prompt. Returns 'accepted', 'dismissed', or
/// 'unavailable'.
Future<String> pwaPromptInstall() async {
  try {
    final result = await _promptInstall().toDart;
    return result.toDart;
  } catch (_) {
    return 'unavailable';
  }
}

/// True when the service worker controls the page — i.e. the app shell and
/// assets are cached and the app can launch offline.
bool pwaOfflineReady() {
  try {
    return _offlineReady().toDart;
  } catch (_) {
    return false;
  }
}

/// True when a newer deployed version has been downloaded and is ready to apply.
bool pwaUpdateAvailable() {
  try {
    return _updateAvailable().toDart;
  } catch (_) {
    return false;
  }
}

/// Asks the browser to check the server for a newer service worker, waiting
/// until the result is known. Resolves to 'updated' (a new version is
/// downloaded and ready), 'latest' (already current), 'error', or
/// 'unsupported'. This is reliable — it waits for the new worker to finish
/// installing rather than guessing with a fixed delay.
Future<String> pwaCheckForUpdate() async {
  try {
    final result = await _checkForUpdate().toDart;
    return result.toDart;
  } catch (_) {
    return 'error';
  }
}

/// Returns the PWA update log (newline-separated) for debugging in Settings.
String pwaGetLog() {
  try {
    return _getLog().toDart;
  } catch (_) {
    return '';
  }
}

/// Clears the PWA update log.
void pwaClearLog() {
  try {
    _clearLog();
  } catch (_) {}
}

/// Appends a line to the PWA update log (so the Dart side can record its own
/// steps alongside the service-worker events).
void pwaLog(String msg) {
  try {
    _log(msg.toJS);
  } catch (_) {}
}

/// Applies a pending update (activates the new worker and reloads).
void pwaApplyUpdate() {
  try {
    _applyUpdate();
  } catch (_) {}
}

/// Whether the browser currently reports an online connection.
bool pwaIsOnline() {
  try {
    return _isOnline().toDart;
  } catch (_) {
    return true;
  }
}

/// Fetches text fresh from the network (bypassing caches). Returns null on
/// failure (e.g. offline) or if the request takes longer than [timeout].
Future<String?> pwaFetchText(String url,
    {Duration timeout = const Duration(seconds: 20)}) async {
  try {
    final result = await _fetchText(url.toJS).toDart.timeout(timeout);
    return result.toDart;
  } catch (_) {
    return null;
  }
}
