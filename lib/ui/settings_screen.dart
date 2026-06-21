import 'package:flutter/material.dart';

import '../state/game_state.dart';
import '../state/settings.dart';
import 'game_theme.dart';

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

  SettingsController get settings => widget.settings;

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
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _SectionTitle('Board theme'),
              for (final t in GameTheme.all) _themeTile(t),
              const SizedBox(height: 20),
              const _SectionTitle('Dictionary'),
              _permissiveTile(),
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
