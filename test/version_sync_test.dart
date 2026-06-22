import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scrabble_offline/app_info.dart';

/// Guards that the displayed app version stays in sync with CHANGELOG.md
/// (the single source of truth). If this fails, run:
///   python3 tool/sync_version.py
void main() {
  test('app version matches the top CHANGELOG.md entry and pubspec', () {
    final changelog = File('CHANGELOG.md').readAsStringSync();
    final topEntry =
        RegExp(r'^##\s*\[(\d+\.\d+\.\d+)\]', multiLine: true)
            .firstMatch(changelog);
    expect(topEntry, isNotNull,
        reason: 'CHANGELOG.md should have a "## [X.Y.Z]" entry');
    final changelogVersion = topEntry!.group(1);

    expect(kAppVersion, changelogVersion,
        reason: 'kAppVersion (lib/app_info.dart) must match the top CHANGELOG '
            'entry — run: python3 tool/sync_version.py');

    final pubspec = File('pubspec.yaml').readAsStringSync();
    final pubMatch = RegExp(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)',
            multiLine: true)
        .firstMatch(pubspec);
    expect(pubMatch, isNotNull, reason: 'pubspec.yaml needs a "X.Y.Z+N" version');
    expect(pubMatch!.group(1), changelogVersion,
        reason: 'pubspec.yaml version must match the top CHANGELOG entry — '
            'run: python3 tool/sync_version.py');

    // The build number (pubspec +N and kAppBuild) is the count of changelog
    // releases, so they must agree.
    final changelogCount =
        RegExp(r'^##\s*\[\d+\.\d+\.\d+\]', multiLine: true)
            .allMatches(changelog)
            .length;
    expect(int.parse(pubMatch.group(2)!), changelogCount,
        reason: 'pubspec build number must equal the number of CHANGELOG '
            'entries — run: python3 tool/sync_version.py');
    expect(kAppBuild, changelogCount,
        reason: 'kAppBuild (lib/app_info.dart) must equal the number of '
            'CHANGELOG entries — run: python3 tool/sync_version.py');
  });
}
