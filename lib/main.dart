import 'package:flutter/material.dart';

import 'engine/dictionary.dart';
import 'state/game_state.dart';
import 'state/persistence.dart';
import 'ui/game_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ScrabbleApp());
}

class ScrabbleApp extends StatelessWidget {
  const ScrabbleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scrabble Offline',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E20),
          brightness: Brightness.dark,
        ),
        // Bundled locally so the app never fetches fonts from a CDN at runtime.
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: const BootstrapScreen(),
    );
  }
}

/// Bootstraps the dictionary trie and Hive store, then offers to continue a
/// saved game or start a new one. All work here is fully offline.
class BootstrapScreen extends StatefulWidget {
  const BootstrapScreen({super.key});

  @override
  State<BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<BootstrapScreen> {
  late Future<GameState> _bootstrap;

  @override
  void initState() {
    super.initState();
    _bootstrap = _initialize();
  }

  Future<GameState> _initialize() async {
    final dictionary = Dictionary();
    final persistence = GamePersistence();
    await Future.wait([
      dictionary.load(),
      persistence.init(),
    ]);
    return GameState(dictionary: dictionary, persistence: persistence);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GameState>(
      future: _bootstrap,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _LoadingScreen();
        }
        if (snapshot.hasError) {
          return _ErrorScreen(error: '${snapshot.error}');
        }
        return _HomeScreen(game: snapshot.data!);
      },
    );
  }
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

/// Landing screen offering New Game / Continue.
class _HomeScreen extends StatelessWidget {
  final GameState game;
  const _HomeScreen({required this.game});

  void _open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GameScreen(game: game)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSave = game.persistence.hasSavedGame;
    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      body: Center(
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
            Text('Offline • ${game.dictionary.wordCount} words loaded',
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 40),
            SizedBox(
              width: 220,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.amber.shade700,
                ),
                onPressed: () {
                  game.newGame();
                  _open(context);
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('New Game'),
              ),
            ),
            if (hasSave) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: 220,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Colors.white),
                  ),
                  onPressed: () {
                    final saved = game.persistence.load();
                    if (saved != null) game.restore(saved);
                    _open(context);
                  },
                  icon: const Icon(Icons.history, color: Colors.white),
                  label: const Text('Continue',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
