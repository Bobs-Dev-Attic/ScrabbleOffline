// lib/main.dart —
//
// Application entry point. Bootstraps Hive, the dictionary, and settings, then
// renders the home screen and the new-game (opponents/difficulty) flow.
//
// See docs/DESIGN.md for how this fits the overall architecture.

import 'dart:async';

import 'package:flutter/material.dart';

import 'app_info.dart';
import 'engine/ai_player.dart';
import 'engine/dictionary.dart';
import 'state/game_state.dart';
import 'state/persistence.dart';
import 'state/settings.dart';
import 'ui/animated_background.dart';
import 'ui/game_screen.dart';
import 'ui/game_theme.dart';
import 'ui/pwa_install.dart';
import 'ui/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ScrabbleApp());
}

/// Holds the bootstrapped, app-wide singletons.
class AppServices {
  final GameState game;
  final SettingsController settings;
  AppServices(this.game, this.settings);
}

class ScrabbleApp extends StatefulWidget {
  const ScrabbleApp({super.key});

  @override
  State<ScrabbleApp> createState() => _ScrabbleAppState();
}

class _ScrabbleAppState extends State<ScrabbleApp> {
  late final Future<AppServices> _bootstrap = _initialize();

  Future<AppServices> _initialize() async {
    final dictionary = Dictionary();
    final persistence = GamePersistence();
    final settings = SettingsController();
    await Future.wait([
      dictionary.load(),
      persistence.init(),
    ]);
    await settings.init(); // after Hive is initialized by persistence
    if (settings.permissiveDictionary) {
      await dictionary.loadExtended();
      dictionary.permissive = true;
    }
    return AppServices(
      GameState(dictionary: dictionary, persistence: persistence),
      settings,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppServices>(
      future: _bootstrap,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _bareApp(const _LoadingScreen(), GameTheme.classic);
        }
        if (snapshot.hasError) {
          return _bareApp(_ErrorScreen(error: '${snapshot.error}'),
              GameTheme.classic);
        }
        final services = snapshot.data!;
        return AnimatedBuilder(
          animation: services.settings,
          builder: (context, _) {
            final theme = services.settings.theme;
            return MaterialApp(
              title: 'Scrabble Offline',
              debugShowCheckedModeBanner: false,
              theme: theme.materialTheme,
              builder: (context, child) =>
                  GameThemeScope(theme: theme, child: child!),
              home: HomeScreen(
                game: services.game,
                settings: services.settings,
              ),
            );
          },
        );
      },
    );
  }

  Widget _bareApp(Widget home, GameTheme theme) => MaterialApp(
        title: 'Scrabble Offline',
        debugShowCheckedModeBanner: false,
        theme: theme.materialTheme,
        home: home,
      );
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF1B5E20),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('SCRABBLE',
                style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 6,
                    color: Colors.white)),
            SizedBox(height: 8),
            Text('Offline Edition', style: TextStyle(color: Colors.white70)),
            SizedBox(height: 24),
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text('Compiling dictionary…',
                style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String error;
  const _ErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFB71C1C),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Failed to start:\n$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}

/// Landing screen offering New Game / Continue / Settings.
class HomeScreen extends StatefulWidget {
  final GameState game;
  final SettingsController settings;
  const HomeScreen({super.key, required this.game, required this.settings});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GameState get game => widget.game;
  SettingsController get settings => widget.settings;

  Timer? _pwaTimer;
  bool _offlineReady = false;
  bool _updateAvailable = false;
  int _ticks = 0;

  @override
  void initState() {
    super.initState();
    // Poll the PWA cache/update state so the indicator stays current.
    pwaCheckForUpdate();
    _pwaTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _ticks++;
      // Re-check the server for updates occasionally while online.
      if (_ticks % 15 == 0 && pwaIsOnline()) pwaCheckForUpdate();
      final ready = pwaOfflineReady();
      final update = pwaUpdateAvailable();
      if (ready != _offlineReady || update != _updateAvailable) {
        setState(() {
          _offlineReady = ready;
          _updateAvailable = update;
        });
      }
    });
  }

  @override
  void dispose() {
    _pwaTimer?.cancel();
    super.dispose();
  }

  void _open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(game: game, settings: settings),
      ),
    );
  }

  Future<void> _startVsComputer(BuildContext context) async {
    const ink = Color(0xFF3A463E);
    final difficulty = await showDialog<AiDifficulty>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Choose difficulty'),
        children: [
          for (final d in AiDifficulty.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, d),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      switch (d) {
                        AiDifficulty.easy => Icons.sentiment_satisfied,
                        AiDifficulty.medium => Icons.sentiment_neutral,
                        AiDifficulty.hard => Icons.whatshot,
                      },
                      color: const Color(0xFF1B5E20),
                    ),
                    const SizedBox(width: 14),
                    Text(d.label,
                        style: const TextStyle(fontSize: 16, color: ink)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
    if (difficulty == null || !context.mounted) return;

    final opponents = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('How many computer opponents?'),
        children: [
          for (final n in [1, 2, 3])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, n),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    // Fixed-width icon column so every label starts at the
                    // same x (consistent indentation).
                    SizedBox(
                      width: 78,
                      child: Row(
                        children: [
                          for (var i = 0; i < n; i++)
                            const Icon(Icons.smart_toy,
                                size: 20, color: Color(0xFF1B5E20)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('$n computer${n > 1 ? 's' : ''}',
                        style: const TextStyle(fontSize: 16, color: ink)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
    if (opponents == null || !context.mounted) return;

    game.newGame(
      humanPlayers: 1,
      computerPlayers: opponents,
      difficulty: difficulty,
    );
    _open(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = GameThemeScope.of(context);
    final hasSave = game.persistence.hasSavedGame;
    return Scaffold(
      backgroundColor: theme.scaffold,
      body: AnimatedBackground(
        theme: theme,
        child: Stack(children: [
        Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('SCRABBLE',
                style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                    color: Colors.white)),
            const SizedBox(height: 4),
            Text(
              'Offline • ${game.dictionary.wordCount} words'
              '${settings.permissiveDictionary ? ' + expanded' : ''}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            _pwaStatusChip(),
            const SizedBox(height: 24),
            _homeButton(
              context,
              icon: Icons.people,
              label: 'Pass & Play',
              color: Colors.amber.shade700,
              onPressed: () {
                game.newGame();
                _open(context);
              },
            ),
            const SizedBox(height: 12),
            _homeButton(
              context,
              icon: Icons.smart_toy,
              label: 'vs Computer',
              color: Colors.lightBlue.shade700,
              onPressed: () => _startVsComputer(context),
            ),
            if (hasSave) ...[
              const SizedBox(height: 12),
              _homeButton(
                context,
                icon: Icons.history,
                label: 'Continue',
                color: Colors.white24,
                onPressed: () {
                  final saved = game.persistence.load();
                  if (saved != null) {
                    game.restore(saved);
                    _open(context);
                  } else {
                    // The save was corrupt and has been reset; stay on the home
                    // screen and tell the user instead of opening a broken game.
                    final msg = game.persistence.lastLoadError ??
                        'No saved game to continue.';
                    setState(() {}); // refresh: the Continue button disappears
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(msg)),
                    );
                  }
                },
              ),
            ],
            const SizedBox(height: 12),
            _homeButton(
              context,
              icon: Icons.settings,
              label: 'Settings',
              color: Colors.white24,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      SettingsScreen(settings: settings, game: game),
                ),
              ),
            ),
            if (!pwaIsStandalone()) ...[
              const SizedBox(height: 12),
              _homeButton(
                context,
                icon: Icons.download_for_offline,
                label: 'Install app',
                color: Colors.teal.shade700,
                onPressed: () => _installApp(context),
              ),
            ],
          ],
        ),
        ),
        const Positioned(
          right: 12,
          bottom: 8,
          child: Text('v$kAppVersion',
              style: TextStyle(color: Colors.white38, fontSize: 11)),
        ),
        ]),
      ),
    );
  }

  /// Small status chip showing offline-cache readiness and update availability.
  Widget _pwaStatusChip() {
    if (_updateAvailable) {
      return _chip(
        icon: Icons.system_update_alt,
        label: 'Update available — tap to update',
        color: Colors.amber.shade700,
        onTap: pwaApplyUpdate,
      );
    }
    if (_offlineReady) {
      return _chip(
        icon: Icons.cloud_done,
        label: 'Ready to play offline',
        color: Colors.green.shade600,
      );
    }
    return _chip(
      icon: null,
      label: 'Preparing offline…',
      color: Colors.white24,
      showSpinner: true,
    );
  }

  Widget _chip({
    required IconData? icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
    bool showSpinner = false,
  }) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSpinner)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          else if (icon != null)
            Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: content,
    );
  }

  /// Triggers the browser's PWA install prompt, or shows manual steps when the
  /// prompt isn't available (e.g. iOS Safari, or already installed).
  Future<void> _installApp(BuildContext context) async {
    if (pwaInstallAvailable()) {
      final outcome = await pwaPromptInstall();
      if (!context.mounted) return;
      if (outcome == 'accepted') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Installing Scrabble Offline…')),
        );
        return;
      }
      if (outcome == 'dismissed') return;
    }
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Install Scrabble Offline'),
        content: const Text(
          'Add it to your home screen to play full-screen and offline.\n\n'
          '• iPhone/iPad (Safari): tap the Share button, then '
          '"Add to Home Screen".\n\n'
          '• Android (Chrome): open the ⋮ menu, then "Install app" / '
          '"Add to Home screen".\n\n'
          'If you don\'t see the option, the app may already be installed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _homeButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 220,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          backgroundColor: color,
          foregroundColor: Colors.white,
        ),
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}
