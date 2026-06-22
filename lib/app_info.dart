/// App version shown on the home screen and in Settings.
///
/// CHANGELOG.md is the single source of truth: this constant is kept in sync
/// with its topmost `## [X.Y.Z]` entry by `tool/sync_version.py` (run during
/// the build). To release, add a CHANGELOG entry and run that script — do not
/// edit this value by hand.
const String kAppVersion = '1.12.0';

/// Build number for this release (the `+N` in pubspec). Also kept in sync from
/// CHANGELOG.md by `tool/sync_version.py`. Used to compare against the server's
/// version.json when checking for updates.
const int kAppBuild = 15;
