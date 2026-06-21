import 'dart:js_interop';

/// Thin bindings to the PWA install helpers defined in web/index.html.
/// All calls are guarded so they degrade gracefully if unavailable.

@JS('pwaIsStandalone')
external JSBoolean _isStandalone();

@JS('pwaInstallAvailable')
external JSBoolean _installAvailable();

@JS('pwaPromptInstall')
external JSPromise<JSString> _promptInstall();

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
