import 'package:flutter/material.dart';

import '../models/tile.dart';
import '../models/tile_bag.dart';
import '../state/game_state.dart';
import '../state/settings.dart';
import 'animated_background.dart';
import 'board_widget.dart';
import 'game_theme.dart';
import 'rack_widget.dart';
import 'settings_screen.dart';

/// Top-level gameplay screen wiring the board, rack, scoreboard, and controls
/// to the [GameState] controller.
class GameScreen extends StatefulWidget {
  final GameState game;
  final SettingsController settings;
  const GameScreen({super.key, required this.game, required this.settings});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  bool _exchangeMode = false;
  final Set<int> _selectedForExchange = {};

  GameState get game => widget.game;

  GameTheme get _theme => GameThemeScope.of(context);

  @override
  Widget build(BuildContext context) {
    final theme = GameThemeScope.of(context);
    return Scaffold(
      backgroundColor: theme.scaffold,
      appBar: AppBar(
        title: const Text('Scrabble Offline'),
        backgroundColor: theme.appBar,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Menu',
            icon: const Icon(Icons.settings),
            onSelected: (value) {
              switch (value) {
                case 'new':
                  _confirmNewGame();
                case 'settings':
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          SettingsScreen(settings: widget.settings, game: game),
                    ),
                  );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'new',
                child: ListTile(
                  leading: Icon(Icons.refresh),
                  title: Text('New Game'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.tune),
                  title: Text('Settings'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: AnimatedBackground(
        theme: theme,
        child: AnimatedBuilder(
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

  Widget _rack() {
    if (game.isComputerTurn) return _computerRack();
    return RackWidget(
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
  }

  /// Face-down rack shown during the computer's turn (its tiles stay hidden).
  Widget _computerRack() {
    final count = game.currentPlayer.rack.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: _theme.rack,
        borderRadius: BorderRadius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final slot = constraints.maxWidth / 7;
          final spacing = (slot * 0.12).clamp(2.0, 6.0);
          final size = (slot - spacing).clamp(20.0, 60.0);
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < count; i++) ...[
                if (i > 0) SizedBox(width: spacing),
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8D6E63), Color(0xFF5D4037)],
                    ),
                    borderRadius: BorderRadius.circular(size * 0.14),
                    border: Border.all(color: const Color(0xFF4E342E)),
                  ),
                  child: Center(
                    child: Icon(Icons.smart_toy,
                        color: Colors.white54, size: size * 0.45),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Compact single-row scoreboard: one column per player plus a bag column.
  Widget _scoreboard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: _theme.panel,
        borderRadius: BorderRadius.circular(8),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < game.players.length; i++)
              Expanded(child: _scoreColumn(i)),
            const VerticalDivider(color: Colors.white24, width: 8),
            _bagColumn(),
          ],
        ),
      ),
    );
  }

  Widget _scoreColumn(int i) {
    final isCurrent = i == game.currentPlayerIndex && !game.gameOver;
    final player = game.players[i];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      decoration: BoxDecoration(
        color: isCurrent ? _theme.appBar : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: isCurrent
            ? Border.all(color: _theme.accent.withValues(alpha: 0.6))
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (player.isAI)
                const Padding(
                  padding: EdgeInsets.only(right: 3),
                  child: Icon(Icons.smart_toy, color: Colors.white54, size: 14),
                ),
              Flexible(
                child: Text(
                  player.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight:
                        isCurrent ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
          Text(
            '${player.score}',
            style: const TextStyle(
              color: Colors.amberAccent,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bagColumn() {
    return SizedBox(
      width: 56,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inventory_2, color: Colors.white60, size: 16),
          const SizedBox(height: 2),
          Text(
            '${game.bag.remaining}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Text('bag', style: TextStyle(color: Colors.white54, fontSize: 10)),
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
        color: game.gameOver ? const Color(0xFF4A148C) : _theme.panel,
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

    if (game.isComputerTurn) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Text(
            '${game.currentPlayer.name} is thinking…',
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
        ],
      );
    }

    if (_exchangeMode) {
      return Row(
        children: [
          _action(
            icon: Icons.swap_horiz,
            label: 'Swap (${_selectedForExchange.length})',
            color: Colors.teal,
            onPressed: _selectedForExchange.isEmpty ? null : _confirmExchange,
          ),
          _action(
            icon: Icons.close,
            label: 'Cancel',
            color: const Color(0xFF546E7A),
            onPressed: () => setState(() {
              _exchangeMode = false;
              _selectedForExchange.clear();
            }),
          ),
        ],
      );
    }

    final hasPending = game.pending.isNotEmpty;
    return Row(
      children: [
        _action(
          icon: Icons.check,
          label: 'Play',
          color: Colors.green.shade700,
          onPressed: hasPending ? _play : null,
        ),
        _action(
          icon: Icons.lightbulb,
          label: 'Suggest',
          color: Colors.amber.shade800,
          onPressed: _suggest,
        ),
        _action(
          icon: Icons.undo,
          label: 'Recall',
          color: const Color(0xFF546E7A),
          onPressed: hasPending ? game.recallAll : null,
        ),
        _action(
          icon: Icons.swap_horiz,
          label: 'Swap',
          color: const Color(0xFF546E7A),
          onPressed: () => setState(() => _exchangeMode = true),
        ),
        _action(
          icon: Icons.skip_next,
          label: 'Pass',
          color: const Color(0xFF546E7A),
          onPressed: _confirmPass,
        ),
      ],
    );
  }

  /// A compact, equal-width action button (icon over label) for the one-row bar.
  Widget _action({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            disabledBackgroundColor: Colors.white12,
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white38,
            padding: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: onPressed,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20),
              const SizedBox(height: 2),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }

  void _suggest() {
    game.suggest();
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
