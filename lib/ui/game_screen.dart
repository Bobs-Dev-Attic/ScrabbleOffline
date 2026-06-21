import 'package:flutter/material.dart';

import '../models/tile.dart';
import '../models/tile_bag.dart';
import '../state/game_state.dart';
import 'board_widget.dart';
import 'rack_widget.dart';

/// Top-level gameplay screen wiring the board, rack, scoreboard, and controls
/// to the [GameState] controller.
class GameScreen extends StatefulWidget {
  final GameState game;
  const GameScreen({super.key, required this.game});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  bool _exchangeMode = false;
  final Set<int> _selectedForExchange = {};

  GameState get game => widget.game;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF263238),
      appBar: AppBar(
        title: const Text('Scrabble Offline'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'New Game',
            icon: const Icon(Icons.refresh),
            onPressed: _confirmNewGame,
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: game,
        builder: (context, _) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 900;
              return wide ? _wideLayout() : _narrowLayout();
            },
          );
        },
      ),
    );
  }

  Widget _wideLayout() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: _boardWidget(),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                _scoreboard(),
                const SizedBox(height: 12),
                _statusBar(),
                const Spacer(),
                _rack(),
                const SizedBox(height: 12),
                _controls(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _narrowLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _scoreboard(),
          const SizedBox(height: 10),
          _statusBar(),
          const SizedBox(height: 10),
          AspectRatio(aspectRatio: 1, child: _boardWidget()),
          const SizedBox(height: 12),
          _rack(),
          const SizedBox(height: 12),
          _controls(),
        ],
      ),
    );
  }

  Widget _boardWidget() => BoardWidget(
        game: game,
        onDropTile: _handleDrop,
        onRecall: game.recallTile,
      );

  Widget _rack() => RackWidget(
        game: game,
        exchangeMode: _exchangeMode,
        selectedForExchange: _selectedForExchange,
        onExchangeToggle: (idx) => setState(() {
          if (_selectedForExchange.contains(idx)) {
            _selectedForExchange.remove(idx);
          } else {
            _selectedForExchange.add(idx);
          }
        }),
      );

  Widget _scoreboard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF37474F),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          for (var i = 0; i < game.players.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (i == game.currentPlayerIndex && !game.gameOver)
                        const Icon(Icons.play_arrow,
                            color: Colors.lightGreenAccent, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        game.players[i].name,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: i == game.currentPlayerIndex
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${game.players[i].score}',
                    style: const TextStyle(
                      color: Colors.amberAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          const Divider(color: Colors.white24),
          Text(
            'Tiles in bag: ${game.bag.remaining}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _statusBar() {
    if (game.statusMessage.isEmpty) {
      return const SizedBox(height: 4);
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: game.gameOver
            ? const Color(0xFF4A148C)
            : const Color(0xFF455A64),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        game.statusMessage,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _controls() {
    if (game.gameOver) {
      return ElevatedButton.icon(
        onPressed: _confirmNewGame,
        icon: const Icon(Icons.refresh),
        label: const Text('New Game'),
      );
    }

    if (_exchangeMode) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: _selectedForExchange.isEmpty ? null : _confirmExchange,
            icon: const Icon(Icons.swap_horiz),
            label: Text('Exchange (${_selectedForExchange.length})'),
          ),
          OutlinedButton(
            onPressed: () => setState(() {
              _exchangeMode = false;
              _selectedForExchange.clear();
            }),
            child: const Text('Cancel'),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade700,
          ),
          onPressed: game.pending.isEmpty ? null : _play,
          icon: const Icon(Icons.check),
          label: const Text('Play'),
        ),
        OutlinedButton.icon(
          onPressed: game.pending.isEmpty ? null : game.recallAll,
          icon: const Icon(Icons.undo, color: Colors.white),
          label: const Text('Recall', style: TextStyle(color: Colors.white)),
        ),
        OutlinedButton.icon(
          onPressed: () => setState(() => _exchangeMode = true),
          icon: const Icon(Icons.swap_horiz, color: Colors.white),
          label: const Text('Exchange', style: TextStyle(color: Colors.white)),
        ),
        OutlinedButton.icon(
          onPressed: _confirmPass,
          icon: const Icon(Icons.skip_next, color: Colors.white),
          label: const Text('Pass', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  // --- Actions ---------------------------------------------------------------

  Future<void> _handleDrop(int rackIndex, int row, int col, Tile tile) async {
    if (tile.isBlank) {
      final letter = await _promptBlankLetter();
      if (letter == null) return;
      game.placeTile(rackIndex, row, col,
          tile: const Tile.blank().assignBlank(letter));
    } else {
      game.placeTile(rackIndex, row, col);
    }
  }

  void _play() {
    final result = game.commitTurn();
    if (result.valid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scored ${result.score} points!'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _confirmExchange() {
    game.exchange(_selectedForExchange.toList());
    setState(() {
      _exchangeMode = false;
      _selectedForExchange.clear();
    });
  }

  Future<void> _confirmPass() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pass turn?'),
        content: const Text('You will not score this turn.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Pass')),
        ],
      ),
    );
    if (ok == true) game.pass();
  }

  Future<void> _confirmNewGame() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start a new game?'),
        content: const Text('The current game will be discarded.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('New Game')),
        ],
      ),
    );
    if (ok == true) {
      game.newGame();
      setState(() {
        _exchangeMode = false;
        _selectedForExchange.clear();
      });
    }
  }

  Future<String?> _promptBlankLetter() async {
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Choose a letter for the blank'),
          content: SizedBox(
            width: 320,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final letter in kStandardDistribution.keys)
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () => Navigator.pop(ctx, letter),
                      child: Text(letter),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
