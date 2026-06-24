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
              const SizedBox(height: 16),
              const _SectionTitle('Custom palettes'),
              for (final p in settings.customPalettes) _customPaletteTile(p),
              _newPaletteTile(),
              const SizedBox(height: 20),
              const _SectionTitle('Dictionary'),
              _permissiveTile(),
              _updateDictionaryTile(online),
              const SizedBox(height: 20),
              const _SectionTitle('Gameplay'),
              _bestMoveTile(),
              const SizedBox(height: 20),
              const _SectionTitle('Sounds'),
              _soundVolumeTile(),
              for (final k in SettingsController.soundKeys) _soundToggle(k),
              const SizedBox(height: 20),
              const _SectionTitle('App'),
              _updatesTile(online),
              _forceUpdateTile(),
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
    final selected = settings.isBuiltinActive(t.id);
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
        onTap: () => settings.setBuiltinTheme(t.id),
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

  /// A selectable saved custom palette, with edit/delete controls.
  Widget _customPaletteTile(CustomPalette p) {
    final theme = p.toTheme();
    final selected = settings.activeCustomId == p.id;
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
        onTap: () => settings.selectCustomPalette(p.id),
        leading: _swatch(theme),
        title: Text(p.name,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: const Text('Custom palette',
            style: TextStyle(color: Colors.white70, fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.check_circle, color: Colors.amberAccent),
              ),
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit, color: Colors.white54),
              onPressed: () => _openPaletteEditor(existing: p),
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline, color: Colors.white54),
              onPressed: () => _confirmDeletePalette(p),
            ),
          ],
        ),
      ),
    );
  }

  Widget _newPaletteTile() {
    final atMax =
        settings.customPalettes.length >= SettingsController.maxCustomPalettes;
    return Card(
      color: const Color(0x14FFFFFF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        enabled: !atMax,
        onTap: atMax ? null : () => _openPaletteEditor(),
        leading: Icon(Icons.add_circle_outline,
            color: atMax ? Colors.white30 : Colors.amberAccent),
        title: Text(atMax ? 'Palette limit reached' : 'New custom palette',
            style: TextStyle(
                color: atMax ? Colors.white38 : Colors.white,
                fontWeight: FontWeight.bold)),
        subtitle: Text(
            'Saved ${settings.customPalettes.length} / '
            '${SettingsController.maxCustomPalettes}',
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ),
    );
  }

  Future<void> _confirmDeletePalette(CustomPalette p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${p.name}"?'),
        content: const Text('This custom palette will be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await settings.deleteCustomPalette(p.id);
  }

  Future<void> _openPaletteEditor({CustomPalette? existing}) async {
    final result = await showDialog<CustomPalette>(
      context: context,
      builder: (ctx) => _PaletteEditorDialog(existing: existing),
    );
    if (result == null) return;
    final saved = await settings.saveCustomPalette(result);
    if (!mounted) return;
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You already have 5 custom palettes.')),
      );
    } else {
      // Selecting it immediately makes the preview the live theme.
      settings.selectCustomPalette(result.id);
    }
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

  Widget _forceUpdateTile() {
    return Card(
      color: const Color(0x22FFFFFF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: const Icon(Icons.cleaning_services, color: Colors.white70),
        title: const Text('Force update (clear cache)',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: const Text(
            'Clears cached files and reloads the latest version from the '
            'network. Use this if an update won\'t apply.',
            style: TextStyle(color: Colors.white70, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white54),
        onTap: _confirmForceUpdate,
      ),
    );
  }

  Future<void> _confirmForceUpdate() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Force update?'),
        content: const Text(
            'This clears the app\'s cached files and reloads the newest version '
            'from the network. Your saved game and settings are kept.\n\n'
            'You need to be online.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Force update')),
        ],
      ),
    );
    if (ok != true) return;
    pwaLog('Settings: force update / cache clear requested.');
    pwaHardReset(); // clears caches, unregisters SW, reloads fresh
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

  static const Map<String, String> _soundLabels = {
    'place': 'Tile placement',
    'play': 'Word played',
    'invalid': 'Invalid move',
    'pass': 'Pass',
    'swap': 'Swap',
    'suggest': 'Suggest',
    'celebrate': 'Celebrations & win',
  };

  Widget _soundVolumeTile() {
    return Card(
      color: const Color(0x22FFFFFF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            const Icon(Icons.volume_up, color: Colors.white70),
            const SizedBox(width: 8),
            const Text('Volume',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            Expanded(
              child: Slider(
                value: settings.soundVolume,
                activeColor: Colors.amberAccent,
                onChanged: settings.setSoundVolume,
                onChangeEnd: (v) {
                  if (v > 0) pwaPlaySound('place', v);
                },
              ),
            ),
            SizedBox(
              width: 40,
              child: Text('${(settings.soundVolume * 100).round()}%',
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _soundToggle(String key) {
    final on = settings.soundEnabled(key);
    return Card(
      color: const Color(0x22FFFFFF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: SwitchListTile(
        dense: true,
        value: on,
        activeThumbColor: Colors.amberAccent,
        title: Text(_soundLabels[key] ?? key,
            style: const TextStyle(color: Colors.white)),
        onChanged: (v) {
          settings.setSoundEnabled(key, v);
          if (v && settings.soundVolume > 0) {
            pwaPlaySound(key, settings.soundVolume); // preview
          }
        },
      ),
    );
  }

  Widget _bestMoveTile() {
    return Card(
      color: const Color(0x22FFFFFF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: SwitchListTile(
        value: settings.bestMoveFeedback,
        onChanged: settings.setBestMoveFeedback,
        activeThumbColor: Colors.amberAccent,
        secondary: const Icon(Icons.auto_awesome, color: Colors.white70),
        title: const Text('Best-move celebration',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: const Text(
          'Confetti when you play the highest-scoring move (no Suggest used). '
          'Otherwise, briefly shows the best play and its points before the '
          'next turn.',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ),
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

/// A fixed set of pleasant primary colors to seed custom palettes from.
const List<Color> _seedSwatches = [
  Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF00695C), Color(0xFF00838F),
  Color(0xFF1565C0), Color(0xFF283593), Color(0xFF4527A0), Color(0xFF6A1B9A),
  Color(0xFFAD1457), Color(0xFFC62828), Color(0xFFD84315), Color(0xFFEF6C00),
  Color(0xFFF9A825), Color(0xFF9E9D24), Color(0xFF558B2F), Color(0xFF37474F),
  Color(0xFF4E342E), Color(0xFF455A64),
];

/// Dialog to create or edit a custom palette: name it, pick a primary color
/// from a fixed set, and preview the generated board palette live.
class _PaletteEditorDialog extends StatefulWidget {
  final CustomPalette? existing;
  const _PaletteEditorDialog({this.existing});

  @override
  State<_PaletteEditorDialog> createState() => _PaletteEditorDialogState();
}

class _PaletteEditorDialogState extends State<_PaletteEditorDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? 'My palette');
  late int _seed = widget.existing?.seed ?? _seedSwatches.first.toARGB32();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  GameTheme get _preview =>
      GameTheme.fromSeed(customId: 'preview', label: 'Preview', seedArgb: _seed);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'New palette' : 'Edit palette'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                maxLength: 24,
                style: const TextStyle(
                    color: Color(0xFF22311F), fontWeight: FontWeight.w600),
                cursorColor: const Color(0xFF22311F),
                decoration: const InputDecoration(
                  labelText: 'Palette name',
                  labelStyle: TextStyle(color: Color(0xFF3A463E)),
                  floatingLabelStyle: TextStyle(
                      color: Color(0xFF22311F), fontWeight: FontWeight.bold),
                  counterStyle: TextStyle(color: Color(0xFF6B756A)),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF9AA89B)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF22311F), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text('Primary color',
                  style: TextStyle(
                      color: Color(0xFF3A463E), fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final c in _seedSwatches) _swatchDot(c),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Preview',
                  style: TextStyle(
                      color: Color(0xFF3A463E), fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _PalettePreview(theme: _preview),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF3A463E)),
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF2E7D32)),
          onPressed: () {
            final name = _name.text.trim().isEmpty
                ? 'My palette'
                : _name.text.trim();
            final id = widget.existing?.id ??
                DateTime.now().microsecondsSinceEpoch.toString();
            Navigator.pop(
                context, CustomPalette(id: id, name: name, seed: _seed));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _swatchDot(Color c) {
    final selected = c.toARGB32() == _seed;
    return GestureDetector(
      onTap: () => setState(() => _seed = c.toARGB32()),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? const Color(0xFF22311F) : Colors.black26,
            width: selected ? 3 : 1,
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 1)),
          ],
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 18)
            : null,
      ),
    );
  }
}

/// A compact board+tile preview rendered from a generated [GameTheme].
class _PalettePreview extends StatelessWidget {
  final GameTheme theme;
  const _PalettePreview({required this.theme});

  @override
  Widget build(BuildContext context) {
    final cells = [
      theme.cellTW,
      theme.cellDW,
      theme.cellTL,
      theme.cellDL,
      theme.cellStandard,
    ];
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.boardFrame,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          for (final c in cells)
            Container(
              width: 26,
              height: 26,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          // A sample tile.
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [theme.tileGradient.first, theme.tileGradient.last],
              ),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: theme.tileBorder),
            ),
            child: Text('A',
                style: TextStyle(
                    color: theme.tileText,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
