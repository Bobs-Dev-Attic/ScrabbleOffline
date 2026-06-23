// lib/ui/game_screen.dart —
//
// The in-game screen: scoreboard, board, rack, action controls, and the scrolling
// play-history strip.
//
// See docs/DESIGN.md for how this fits the overall architecture.

import 'dart:math';

import 'package:flutter/material.dart';

import '../models/tile.dart';
import '../models/tile_bag.dart';
import '../state/game_state.dart';
import '../state/settings.dart';
import 'animated_background.dart';
import 'board_widget.dart';
import 'confetti_overlay.dart';
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
  final ScrollController _historyController = ScrollController();

  @override
  void dispose() {
    _historyController.dispose();
    super.dispose();
  }

  GameState get game => widget.game;

  GameTheme get _theme => GameThemeScope.of(context);

  @override
  Widget build(BuildContext context) {
    final theme = GameThemeScope.of(context);
    return Scaffold(
      backgroundColor: theme.scaffold,
      appBar: AppBar(
        title: const Text('Scrabbled Offline'),
        backgroundColor: theme.appBar,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Menu',
            icon: const Icon(Icons.more_vert, color: Colors.white, size: 26),
            color: const Color(0xFF2A2A2A),
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
                  leading: Icon(Icons.refresh, color: Colors.white),
                  title: Text('New Game',
                      style: TextStyle(color: Colors.white)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.tune, color: Colors.white),
                  title:
                      Text('Settings', style: TextStyle(color: Colors.white)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: game,
        builder: (context, _) {
          // Keep the engine's celebration toggle in sync with the setting.
          game.bestMoveFeedbackEnabled = widget.settings.bestMoveFeedback;
          return Stack(
            children: [
              AnimatedBackground(
                theme: theme,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth > 900;
                    return wide ? _wideLayout() : _narrowLayout();
                  },
                ),
              ),
              // Confetti celebration overlay (fires on a perfect play).
              Positioned.fill(
                child: IgnorePointer(
                  child: ConfettiOverlay(trigger: game.celebrateSerial),
                ),
              ),
            ],
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
                const SizedBox(height: 8),
                _history(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _narrowLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Column(
        children: [
          _scoreboard(),
          const SizedBox(height: 6),
          _statusBar(),
          const SizedBox(height: 6),
          AspectRatio(aspectRatio: 1, child: _boardWidget()),
          const SizedBox(height: 8),
          _rack(),
          const SizedBox(height: 8),
          _controls(),
          const SizedBox(height: 8),
          _history(),
        ],
      ),
    );
  }

  /// Horizontal, scrollable strip of recent moves.
  Widget _history() {
    final h = game.history;
    // Keep the newest entry visible.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_historyController.hasClients) {
        _historyController.jumpTo(_historyController.position.maxScrollExtent);
      }
    });
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: _theme.panel.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: h.isEmpty
          ? const Center(
              child: Text('Moves appear here',
                  style: TextStyle(color: Colors.white38, fontSize: 12)))
          : ListView.separated(
              controller: _historyController,
              scrollDirection: Axis.horizontal,
              itemCount: h.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, i) => _historyChip(h[i]),
            ),
    );
  }

  Widget _historyChip(MoveLogEntry e) {
    final scoring = e.points > 0;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: e.isBingo ? _theme.accent : Colors.white24,
            width: e.isBingo ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${e.player}: ',
                style: const TextStyle(color: Colors.white60, fontSize: 12)),
            Text(e.label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
            if (scoring)
              Text('  +${e.points}',
                  style: TextStyle(
                      color: _theme.accent.withValues(alpha: 0.95),
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: _theme.panel.withValues(alpha: 0.72),
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
    // After a sub-optimal play, highlight the best word that was possible.
    if (game.reviewingPotential) {
      final word = game.reviewWord;
      final msg = word.isEmpty
          ? '✨ Best play here was ${game.reviewPotential} points'
          : '✨ You missed "$word" for ${game.reviewPotential} points';
      return _statusBox(msg, const Color(0xE6B5965A), bold: true);
    }
    // While the player is placing tiles, show the live potential score.
    if (game.pending.isNotEmpty && !game.isComputerTurn) {
      final preview = game.previewMove();
      if (preview.valid) {
        final words = preview.words.map((w) => '${w.word} ${w.score}').join(' · ');
        return _statusBox(
          '+${preview.score}${preview.isBingo ? '  BINGO!' : ''}   $words',
          _theme.accent.withValues(alpha: 0.30),
          bold: true,
        );
      }
      return _statusBox(
        preview.error?.isNotEmpty == true ? preview.error! : 'Keep placing…',
        _theme.panel.withValues(alpha: 0.55),
      );
    }

    if (game.statusMessage.isEmpty) {
      return const SizedBox(height: 4);
    }
    return _statusBox(
      game.statusMessage,
      game.gameOver
          ? const Color(0xE64A148C)
          : _theme.panel.withValues(alpha: 0.72),
    );
  }

  Widget _statusBox(String text, Color color, {bool bold = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
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

    if (game.reviewingPotential) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lightbulb_outline, color: Colors.amberAccent, size: 18),
          SizedBox(width: 10),
          Text('Showing the best possible play…',
              style: TextStyle(color: Colors.white, fontSize: 15)),
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
          icon: Icons.skip_next,
          label: 'Pass',
          color: const Color(0xFF546E7A),
          onPressed: _confirmPass,
        ),
        _action(
          icon: Icons.swap_horiz,
          label: 'Swap',
          color: const Color(0xFF546E7A),
          onPressed: () => setState(() => _exchangeMode = true),
        ),
        // Before any tile is placed this is "Mix" (shuffle the rack); once a
        // tile is on the board it becomes "Recall" (return pending tiles).
        hasPending
            ? _action(
                icon: Icons.undo,
                label: 'Recall',
                color: const Color(0xFF546E7A),
                onPressed: game.recallAll,
              )
            : _action(
                icon: Icons.shuffle,
                label: 'Mix',
                color: const Color(0xFF546E7A),
                onPressed: game.mixRack,
              ),
        _action(
          icon: Icons.auto_awesome,
          label: 'Suggest',
          color: Colors.amber.shade600,
          foreground: Colors.black87,
          onPressed: _suggest,
          iconWidget: const _SparkleIcon(size: 20),
        ),
        _action(
          icon: Icons.check,
          label: 'Play',
          color: Colors.green.shade700,
          onPressed: hasPending ? _play : null,
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
    Color foreground = Colors.white,
    Widget? iconWidget,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color.withValues(alpha: 0.85),
            disabledBackgroundColor: Colors.white10,
            foregroundColor: foreground,
            disabledForegroundColor: Colors.white38,
            padding: const EdgeInsets.symmetric(vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: onPressed,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              iconWidget ?? Icon(icon, size: 20),
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
    game.bestMoveFeedbackEnabled = widget.settings.bestMoveFeedback;
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

/// An animated "sparkle" icon for the Suggest button: the star shimmers through
/// a rotating multi-color gradient and gently pulses to draw the eye.
class _SparkleIcon extends StatefulWidget {
  final double size;
  const _SparkleIcon({this.size = 20});

  @override
  State<_SparkleIcon> createState() => _SparkleIconState();
}

class _SparkleIconState extends State<_SparkleIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  static const _colors = [
    Color(0xFFFFF59D), // light gold
    Color(0xFFFFD54F), // amber
    Color(0xFFFF8A65), // coral
    Color(0xFFBA68C8), // violet
    Color(0xFF4FC3F7), // sky
    Color(0xFFFFF59D), // back to gold (seamless loop)
  ];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final angle = _c.value * 2 * pi;
        final scale = 1.0 + 0.12 * sin(angle);
        return Transform.scale(
          scale: scale,
          child: ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (rect) => SweepGradient(
              transform: GradientRotation(angle),
              colors: _colors,
            ).createShader(rect),
            child: Icon(Icons.auto_awesome, size: widget.size, color: Colors.white),
          ),
        );
      },
    );
  }
}
