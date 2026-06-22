import 'package:flutter/material.dart';

import '../app_info.dart';
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
  bool _updatingDict = false;
  String? _dictMsg;

  SettingsController get settings => widget.settings;

  Future<void> _checkUpdates() async {
    setState(() {
      _checkingUpdate = true;
      _updateMsg = 'Checking…';
    });
    pwaCheckForUpdate();
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    setState(() {
      _checkingUpdate = false;
      _updateMsg = pwaUpdateAvailable()
          ? 'Update available.'
          : "You're on the latest version.";
    });
  }

  Future<void> _updateDictionary() async {
    setState(() {
      _updatingDict = true;
      _dictMsg = 'Updating…';
    });
    final dict = widget.game.dictionary;
    final raw = await pwaFetchText('assets/assets/dictionary.txt');
    if (raw != null && mounted) {
      final n = dict.refreshFromRaw(raw);
      if (dict.permissive) {
        final ext = await pwaFetchText('assets/assets/dictionary_extended.txt');
        if (ext != null) dict.refreshExtendedFromRaw(ext);
      }
      setState(() {
        _updatingDict = false;
        _dictMsg = 'Updated — $n words loaded.';
      });
    } else if (mounted) {
      setState(() {
        _updatingDict = false;
        _dictMsg = 'Could not update (are you online?).';
      });
    }
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
                const Expanded(
                  child: Text('Version v$kAppVersion',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
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
                      : const Text('Check for updates'),
                ),
              ],
            ),
            if (_updateMsg != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 36),
                child: Text(_updateMsg!,
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
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
                        backgroundColor: Colors.amber.shade700),
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
