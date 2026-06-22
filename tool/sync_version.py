#!/usr/bin/env python3
"""Keep the app version in sync with CHANGELOG.md.

CHANGELOG.md is the single source of truth: the topmost ``## [X.Y.Z]`` entry
defines the current release. This script propagates that version into:

  - lib/app_info.dart   -> kAppVersion (shown on the home screen + Settings)
  - pubspec.yaml        -> version: X.Y.Z+<build>

The build number is the number of released versions in the changelog, so it
increases monotonically with each new entry.

Usage:
  python3 tool/sync_version.py          # rewrite app_info.dart + pubspec.yaml
  python3 tool/sync_version.py --check   # verify they match; exit 1 if not
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHANGELOG = os.path.join(ROOT, "CHANGELOG.md")
APP_INFO = os.path.join(ROOT, "lib", "app_info.dart")
PUBSPEC = os.path.join(ROOT, "pubspec.yaml")

VERSION_HEADING = re.compile(r"^##\s*\[(\d+\.\d+\.\d+)\]", re.MULTILINE)


def read(path):
    with io.open(path, encoding="utf-8") as f:
        return f.read()


def write(path, text):
    with io.open(path, "w", encoding="utf-8") as f:
        f.write(text)


def changelog_version():
    """Return (version, build_number) from CHANGELOG.md."""
    text = read(CHANGELOG)
    matches = VERSION_HEADING.findall(text)
    if not matches:
        sys.exit("sync_version: no '## [X.Y.Z]' entries found in CHANGELOG.md")
    version = matches[0]          # topmost entry = current release
    build = len(matches)          # one build number per released version
    return version, build


def apply(app_info, pubspec, version, build):
    new_app_info = re.sub(
        r"kAppVersion\s*=\s*'[^']*'",
        "kAppVersion = '{}'".format(version),
        app_info,
    )
    new_pubspec = re.sub(
        r"(?m)^version:\s*.*$",
        "version: {}+{}".format(version, build),
        pubspec,
    )
    return new_app_info, new_pubspec


def main():
    check = "--check" in sys.argv[1:]
    version, build = changelog_version()
    app_info = read(APP_INFO)
    pubspec = read(PUBSPEC)
    new_app_info, new_pubspec = apply(app_info, pubspec, version, build)

    in_sync = new_app_info == app_info and new_pubspec == pubspec
    if check:
        if in_sync:
            print("sync_version: OK — version {} (+{}) in sync.".format(
                version, build))
            return 0
        print("sync_version: OUT OF SYNC. Run 'python3 tool/sync_version.py'.")
        print("  CHANGELOG.md top version: {} (build {})".format(version, build))
        return 1

    if in_sync:
        print("sync_version: already in sync at {}+{}.".format(version, build))
        return 0
    write(APP_INFO, new_app_info)
    write(PUBSPEC, new_pubspec)
    print("sync_version: set version to {}+{} (from CHANGELOG.md).".format(
        version, build))
    return 0


if __name__ == "__main__":
    sys.exit(main())
