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
external void _checkForUpdate();

@JS('pwaApplyUpdate')
external void _applyUpdate();

@JS('pwaIsOnline')
external JSBoolean _isOnline();

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

/// Asks the browser to check the server for a newer service worker.
void pwaCheckForUpdate() {
  try {
    _checkForUpdate();
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
