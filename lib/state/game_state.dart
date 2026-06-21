import 'package:flutter/foundation.dart';

import '../engine/dictionary.dart';
import '../engine/referee.dart';
import '../models/board.dart';
import '../models/player.dart';
import '../models/tile.dart';
import '../models/tile_bag.dart';
import 'persistence.dart';

/// A tile the current player has tentatively placed this turn (not yet
/// committed / scored). Tracks its origin index in the rack for rollback.
class PendingPlacement {
  final int row;
  final int col;
  final Tile tile;
  final int rackIndex;

  const PendingPlacement(this.row, this.col, this.tile, this.rackIndex);
}

/// Central, observable game controller. Owns all mutable state and notifies
/// the UI via [ChangeNotifier]. Persists after every committed turn.
class GameState extends ChangeNotifier {
  final Dictionary dictionary;
  final GamePersistence persistence;
  late final ScrabbleReferee referee;

  GameBoard board = GameBoard();
  TileBag bag = TileBag();
  List<Player> players = [];
  int currentPlayerIndex = 0;

  /// Pending placements keyed by "row,col" for the in-progress turn.
  final Map<String, PendingPlacement> pending = {};

  /// Transient status message surfaced to the player (errors, last score, ...).
  String statusMessage = '';

  /// True once a winner has been determined.
  bool gameOver = false;
  int consecutivePasses = 0;

  GameState({required this.dictionary, required this.persistence}) {
    referee = ScrabbleReferee(dictionary);
  }

  Player get currentPlayer => players[currentPlayerIndex];

  /// Starts a fresh two-player pass-and-play game.
  void newGame({List<String>? playerNames}) {
    final names = playerNames ?? const ['Player 1', 'Player 2'];
    board = GameBoard();
    bag = TileBag();
    players = [
      for (final n in names) Player(name: n),
    ];
    for (final p in players) {
      p.refill(bag.draw);
    }
    currentPlayerIndex = 0;
    pending.clear();
    statusMessage = '';
    gameOver = false;
    consecutivePasses = 0;
    _persist();
    notifyListeners();
  }

  /// Restores a saved game snapshot into the controller.
  void restore(SavedGame saved) {
    board = saved.board;
    bag = saved.bag;
    players = saved.players;
    currentPlayerIndex = saved.currentPlayerIndex;
    pending.clear();
    statusMessage = 'Game restored.';
    gameOver = false;
    consecutivePasses = 0;
    notifyListeners();
  }

  // --- Turn construction -----------------------------------------------------

  Tile? pendingTileAt(int row, int col) => pending['$row,$col']?.tile;

  /// True if a cell currently shows a committed or pending tile.
  bool isOccupied(int row, int col) =>
      !board.isEmptyAt(row, col) || pending.containsKey('$row,$col');

  /// Rack tiles not yet placed this turn, preserving original indices.
  List<MapEntry<int, Tile>> get availableRackTiles {
    final usedIndices = pending.values.map((p) => p.rackIndex).toSet();
    final result = <MapEntry<int, Tile>>[];
    for (var i = 0; i < currentPlayer.rack.length; i++) {
      if (!usedIndices.contains(i)) {
        result.add(MapEntry(i, currentPlayer.rack[i]));
      }
    }
    return result;
  }

  /// Tentatively places the rack tile at [rackIndex] onto an empty cell.
  /// Blanks must already be assigned a letter via [tile].
  bool placeTile(int rackIndex, int row, int col, {Tile? tile}) {
    if (gameOver) return false;
    if (isOccupied(row, col)) return false;
    if (rackIndex < 0 || rackIndex >= currentPlayer.rack.length) return false;
    final placed = tile ?? currentPlayer.rack[rackIndex];
    pending['$row,$col'] = PendingPlacement(row, col, placed, rackIndex);
    statusMessage = '';
    notifyListeners();
    return true;
  }

  /// Recalls a single pending tile back to the rack (rollback for one cell).
  void recallTile(int row, int col) {
    pending.remove('$row,$col');
    notifyListeners();
  }

  /// Recalls all pending tiles — the full rollback routine.
  void recallAll() {
    pending.clear();
    statusMessage = '';
    notifyListeners();
  }

  // --- Turn resolution -------------------------------------------------------

  /// Validates and, if legal, commits the current turn. Returns the result so
  /// the UI can animate feedback. Invalid moves leave pending tiles in place.
  MoveResult commitTurn() {
    if (gameOver) return MoveResult.invalid('Game over.');
    final placements = pending.values
        .map((p) => Placement(p.row, p.col, p.tile))
        .toList();
    final result = referee.evaluate(board, placements);
    if (!result.valid) {
      statusMessage = result.error ?? 'Invalid move.';
      notifyListeners();
      return result;
    }

    // Commit tiles to the board.
    for (final p in pending.values) {
      board.cellAt(p.row, p.col).tile = p.tile;
    }

    // Remove used tiles from the rack and refill.
    final usedTiles = pending.values.map((p) => p.tile).toList();
    currentPlayer.removeFromRack(usedTiles);
    currentPlayer.score += result.score;
    currentPlayer.refill(bag.draw);

    final summary = result.words.map((w) => '${w.word} (${w.score})').join(', ');
    statusMessage = '${currentPlayer.name} scored ${result.score}'
        '${result.isBingo ? ' — BINGO! +$kBingoBonus' : ''} • $summary';

    pending.clear();
    consecutivePasses = 0;

    _checkGameOver();
    if (!gameOver) _advanceTurn();

    _persist();
    notifyListeners();
    return result;
  }

  /// Passes the turn without placing tiles.
  void pass() {
    if (gameOver) return;
    recallAll();
    consecutivePasses++;
    statusMessage = '${currentPlayer.name} passed.';
    if (consecutivePasses >= players.length * 2) {
      _endGame();
    } else {
      _advanceTurn();
    }
    _persist();
    notifyListeners();
  }

  /// Exchanges the given rack tiles for new ones (only when the bag has at
  /// least 7 tiles, per standard rules). Counts as a turn.
  bool exchange(List<int> rackIndices) {
    if (gameOver) return false;
    if (bag.remaining < kRackCapacity) {
      statusMessage = 'Not enough tiles in the bag to exchange.';
      notifyListeners();
      return false;
    }
    recallAll();
    final returned = <Tile>[];
    final sorted = [...rackIndices]..sort((a, b) => b.compareTo(a));
    for (final idx in sorted) {
      if (idx >= 0 && idx < currentPlayer.rack.length) {
        returned.add(currentPlayer.rack.removeAt(idx));
      }
    }
    currentPlayer.refill(bag.draw);
    bag.returnTiles(returned);
    consecutivePasses = 0;
    statusMessage = '${currentPlayer.name} exchanged ${returned.length} tiles.';
    _advanceTurn();
    _persist();
    notifyListeners();
    return true;
  }

  void _advanceTurn() {
    currentPlayerIndex = (currentPlayerIndex + 1) % players.length;
  }

  void _checkGameOver() {
    // Game ends when the bag is empty and a player has emptied their rack.
    if (bag.isEmpty && currentPlayer.rack.isEmpty) {
      _endGame();
    }
  }

  void _endGame() {
    gameOver = true;
    // Standard end-game adjustment: subtract leftover rack values; the player
    // who emptied their rack gains the sum of everyone else's leftovers.
    int emptied = -1;
    for (var i = 0; i < players.length; i++) {
      final leftover =
          players[i].rack.fold<int>(0, (sum, t) => sum + t.value);
      players[i].score -= leftover;
      if (players[i].rack.isEmpty) emptied = i;
    }
    if (emptied != -1) {
      int gained = 0;
      for (var i = 0; i < players.length; i++) {
        if (i == emptied) continue;
        gained += players[i].rack.fold<int>(0, (sum, t) => sum + t.value);
      }
      players[emptied].score += gained;
    }
    final winner = players.reduce((a, b) => a.score >= b.score ? a : b);
    statusMessage = 'Game over — ${winner.name} wins with ${winner.score}!';
  }

  Future<void> _persist() async {
    await persistence.save(
      board: board,
      players: players,
      bag: bag,
      currentPlayerIndex: currentPlayerIndex,
    );
  }
}
