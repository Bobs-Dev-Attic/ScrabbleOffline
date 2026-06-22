// lib/ui/settings_screen.dart —
//
// Settings UI: board theme selection, dictionary mode, and update/version actions.
//
// See docs/DESIGN.md for how this fits the overall architecture.

import 'dart:convert';

import 'package:flutter/material.dart';

import '../app_info.dart';
import '../engine/dictionary.dart';
import '../state/game_state.dart';
import '../state/settings.dart';
import 'game_theme.dart';
import 'pwa_install.dart';

/// Settings: board theme / mode selection and the expanded dictionary toggle.
class SettingsScreen extends StatefulWidget {
  final SettingsController settings;
  final GameState game;

  const SettingsScreen({super.key, required this.settings, required this.game});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;
  bool _checkingUpdate = false;
  String? _updateMsg;
  String? _availableVersion;
  bool _updatingDict = false;
  String? _dictMsg;

  SettingsController get settings => widget.settings;

  /// Reliable, informative update check:
  /// 1. fetch the server's version.json fresh to learn the available version;
  /// 2. ask the service worker to check + download a new version, awaiting the
  ///    real result (no fixed-delay guessing — fixes the "run it twice" issue);
  /// 3. report current vs. available version and what to do next.
  Future<void> _checkUpdates() async {
    setState(() {
      _checkingUpdate = true;
      _availableVersion = null;
      _updateMsg = 'Contacting server…';
    });
    pwaLog('Settings: Check for updates tapped (current v$kAppVersion build $kAppBuild).');

    // 1. What version is on the server right now?
    String? serverVer;
    int? serverBuild;
    final raw = await pwaFetchText('version.json');
    if (raw != null) {
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        serverVer = m['version']?.toString();
        serverBuild = int.tryParse('${m['build_number']}');
        pwaLog('server version.json: v$serverVer build $serverBuild');
      } catch (e) {
        pwaLog('version.json parse error: $e');
      }
    } else {
      pwaLog('version.json fetch failed (offline?).');
    }
    if (mounted) {
      setState(() {
        _availableVersion =
            serverVer != null ? 'v$serverVer (build ${serverBuild ?? '?'})' : null;
        _updateMsg = 'Checking for a new app version…';
      });
    }

    // 2. Ask the service worker to check and download any new version.
    final status = await pwaCheckForUpdate();
    if (!mounted) return;

    // 3. Build a clear message.
    final newerByVersion = serverBuild != null && serverBuild > kAppBuild;
    String msg;
    if (status == 'updated') {
      msg = 'Update ready'
          '${serverVer != null ? ': v$serverVer (build $serverBuild)' : ''}.'
          '\nTap “Update now” to install and reload.';
    } else if (newerByVersion) {
      msg = 'A new version is available'
          '${serverVer != null ? ': v$serverVer (build $serverBuild)' : ''}.'
          '\nStill downloading — tap Check again in a moment.';
    } else if (status == 'latest') {
      msg = "You're on the latest version (v$kAppVersion, build $kAppBuild).";
    } else if (status == 'unsupported') {
      msg = 'Updates aren\'t available in this browser context.';
    } else {
      msg = 'Couldn\'t complete the check (are you online?).';
    }
    pwaLog('Settings: check finished — status=$status, newerByVersion=$newerByVersion.');
    setState(() {
      _checkingUpdate = false;
      _updateMsg = msg;
    });
  }

  void _showUpdateLog() {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final log = pwaGetLog();
        return AlertDialog(
          title: const Text('Update log'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: SelectableText(
                log.isEmpty ? 'No update events recorded yet.' : log,
                style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Color(0xFF3A463E)),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                pwaClearLog();
                Navigator.pop(ctx);
              },
              child: const Text('Clear'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateDictionary() async {
    setState(() {
      _updatingDict = true;
      _dictMsg = 'Updating…';
    });
    pwaLog('Settings: Update word list tapped.');
    final dict = widget.game.dictionary;
    final raw = await pwaFetchText('assets/assets/dictionary.txt');
    if (!mounted) return;
    if (raw == null) {
      pwaLog('Settings: word list fetch failed (offline?).');
      setState(() {
        _updatingDict = false;
        _dictMsg = 'Could not update (are you online?).';
      });
      return;
    }
    // Validate the response before replacing the live dictionary, so a proxy
    // error page or truncated download can't wipe it out.
    final n = dict.refreshFromRawValidated(raw);
    if (n < 0) {
      pwaLog('Settings: word list rejected — response failed validation '
          '(${raw.length} bytes).');
      setState(() {
        _updatingDict = false;
        _dictMsg = 'Update rejected — the response didn\'t look like a '
            'word list. Kept the current dictionary.';
      });
      return;
    }
    if (dict.permissive) {
      final ext = await pwaFetchText('assets/assets/dictionary_extended.txt');
      if (ext != null && Dictionary.looksLikeWordList(ext)) {
        dict.refreshExtendedFromRaw(ext);
      } else {
        pwaLog('Settings: expanded supplement skipped (missing/invalid).');
      }
    }
    pwaLog('Settings: word list updated — $n words.');
    if (!mounted) return;
    setState(() {
      _updatingDict = false;
      _dictMsg = 'Updated — $n words loaded.';
    });
  }

  Future<void> _togglePermissive(bool value) async {
    if (value) {
      setState(() => _busy = true);
      await widget.game.dictionary.loadExtended();
      widget.game.dictionary.permissive = true;
      setState(() => _busy = false);
    } else {
      widget.game.dictionary.permissive = false;
    }
    settings.setPermissive(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = GameThemeScope.of(context);
    return Scaffold(
      backgroundColor: theme.scaffold,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: theme.appBar,
        foregroundColor: Colors.white,
      ),
      body: AnimatedBuilder(
        animation: settings,
        builder: (context, _) {
          final online = pwaIsOnline();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _SectionTitle('Board theme'),
              for (final t in GameTheme.all) _themeTile(t),
              const SizedBox(height: 20),
              const _SectionTitle('Dictionary'),
              _permissiveTile(),
              _updateDictionaryTile(online),
              const SizedBox(height: 20),
              const _SectionTitle('App'),
              _updatesTile(online),
              _updateLogTile(),
              const SizedBox(height: 20),
              const _SectionTitle('Privacy & data'),
              _privacyTile(),
              _resetDataTile(),
            ],
          );
        },
      ),
    );
  }

  Widget _themeTile(GameTheme t) {
    final selected = settings.themeId == t.id;
    return Card(
      color: const Color(0x22FFFFFF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected ? Colors.amberAccent : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        onTap: () => settings.setTheme(t.id),
        leading: _swatch(t),
        title: Text(t.label,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(t.description,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        trailing: selected
            ? const Icon(Icons.check_circle, color: Colors.amberAccent)
            : Icon(t.icon, color: Colors.white54),
      ),
    );
  }

  /// A miniature preview of the theme's board colors.
  Widget _swatch(GameTheme t) {
    final cells = [
      t.cellTW,
      t.cellDL,
      t.cellCenter,
      t.tileGradient.first,
    ];
    return Container(
      width: 44,
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: t.boardFrame,
        borderRadius: BorderRadius.circular(8),
      ),
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (final c in cells)
            Container(
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }

  Widget _updateDictionaryTile(bool online) {
    final dict = widget.game.dictionary;
    final count = dict.wordCount +
        (dict.permissive && dict.extendedLoaded ? dict.extendedCount : 0);
    return Card(
      color: const Color(0x22FFFFFF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: const Icon(Icons.sync, color: Colors.white70),
        title: const Text('Update word list',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(
          _dictMsg ??
              '$count words loaded.${online ? '' : ' Connect to update.'}',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        trailing: ElevatedButton(
          onPressed: (online && !_updatingDict) ? _updateDictionary : null,
          child: _updatingDict
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Update'),
        ),
      ),
    );
  }

  Widget _updatesTile(bool online) {
    final updateReady = pwaUpdateAvailable();
    return Card(
      color: const Color(0x22FFFFFF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white70),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Current version',
                          style: TextStyle(color: Colors.white54, fontSize: 11)),
                      const Text('v$kAppVersion (build $kAppBuild)',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      if (_availableVersion != null &&
                          _availableVersion != 'v$kAppVersion (build $kAppBuild)')
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('Available: $_availableVersion',
                              style: TextStyle(
                                  color: Colors.amber.shade300,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: (online && !_checkingUpdate) ? _checkUpdates : null,
                  child: _checkingUpdate
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Check'),
                ),
              ],
            ),
            if (_checkingUpdate || _updateMsg != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 36),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_checkingUpdate) ...[
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(_updateMsg ?? '',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            if (!online)
              const Padding(
                padding: EdgeInsets.only(top: 8, left: 36),
                child: Text('Offline — connect to check for updates.',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
              ),
            if (updateReady)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7E57C2),
                        foregroundColor: Colors.white),
                    onPressed: pwaApplyUpdate,
                    icon: const Icon(Icons.system_update_alt),
                    label: const Text('Update now'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _updateLogTile() {
    return Card(
      color: const Color(0x22FFFFFF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: const Icon(Icons.receipt_long, color: Colors.white70),
        title: const Text('Update log',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: const Text('Recent install / update events for debugging.',
            style: TextStyle(color: Colors.white70, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white54),
        onTap: _showUpdateLog,
      ),
    );
  }

  Widget _privacyTile() {
    return Card(
      color: const Color(0x22FFFFFF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: const Padding(
        padding: EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline, color: Colors.white70),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'This game runs entirely on your device. There are no accounts, '
                'no sign-in, and no gameplay or analytics data ever leaves your '
                'device. Your saved game and preferences are stored locally in '
                'your browser and can be removed anytime below.',
                style: TextStyle(color: Colors.white70, fontSize: 12.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resetDataTile() {
    return Card(
      color: const Color(0x22FFFFFF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: const Icon(Icons.delete_outline, color: Colors.white70),
        title: const Text('Reset local data',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: const Text(
            'Erase the saved game and preferences stored in this browser.',
            style: TextStyle(color: Colors.white70, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white54),
        onTap: _confirmResetData,
      ),
    );
  }

  Future<void> _confirmResetData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset local data?'),
        content: const Text(
            'This erases your saved game and resets preferences to defaults. '
            'This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.game.persistence.clear();
    widget.game.dictionary.permissive = false;
    await settings.resetToDefaults();
    pwaLog('Settings: local data reset by user.');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Local data cleared.')),
    );
  }

  Widget _permissiveTile() {
    return Card(
      color: const Color(0x22FFFFFF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: SwitchListTile(
        value: settings.permissiveDictionary,
        onChanged: _busy ? null : _togglePermissive,
        activeThumbColor: Colors.amberAccent,
        secondary: _busy
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.menu_book, color: Colors.white70),
        title: const Text('Expanded / Casual dictionary',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: const Text(
          'Accepts many more English words — including slang and edgy words '
          'the official Scrabble list excludes. The computer still plays only '
          'standard words.',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: Colors.white60,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
