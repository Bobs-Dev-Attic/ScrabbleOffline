import 'package:flutter/foundation.dart';

import '../engine/ai_player.dart';
import '../engine/dictionary.dart';
import '../engine/move_generator.dart';
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
  late final AiPlayer ai;

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

  /// Whether seat 1 is a computer opponent, and how strong it plays.
  bool vsComputer = false;
  AiDifficulty aiDifficulty = AiDifficulty.medium;

  /// True while the computer is computing its move (UI shows a "thinking" cue).
  bool aiThinking = false;

  /// Incremented whenever a new game starts so a pending (delayed) AI turn from
  /// a previous game is ignored.
  int _aiToken = 0;

  GameState({required this.dictionary, required this.persistence}) {
    referee = ScrabbleReferee(dictionary);
    ai = AiPlayer(MoveGenerator(dictionary));
  }

  Player get currentPlayer => players[currentPlayerIndex];

  /// True when it is the computer's turn (input should be locked).
  bool get isComputerTurn => !gameOver && currentPlayer.isAI;

  /// Starts a fresh game. When [vsComputer] is true, seat 2 is an AI of the
  /// given [difficulty]; otherwise it's local pass-and-play.
  void newGame({
    List<String>? playerNames,
    bool vsComputer = false,
    AiDifficulty difficulty = AiDifficulty.medium,
  }) {
    this.vsComputer = vsComputer;
    aiDifficulty = difficulty;
    _aiToken++;
    final names = playerNames ??
        (vsComputer
            ? const ['You', 'Computer']
            : const ['Player 1', 'Player 2']);
    board = GameBoard();
    bag = TileBag();
    players = [
      Player(name: names[0]),
      Player(name: names[1], isAI: vsComputer),
    ];
    for (final p in players) {
      p.refill(bag.draw);
    }
    currentPlayerIndex = 0;
    pending.clear();
    statusMessage = '';
    gameOver = false;
    aiThinking = false;
    consecutivePasses = 0;
    _persist();
    notifyListeners();
    _scheduleAiTurnIfNeeded();
  }

  /// Restores a saved game snapshot into the controller.
  void restore(SavedGame saved) {
    _aiToken++;
    board = saved.board;
    bag = saved.bag;
    players = saved.players;
    currentPlayerIndex = saved.currentPlayerIndex;
    vsComputer = players.any((p) => p.isAI);
    pending.clear();
    statusMessage = 'Game restored.';
    gameOver = false;
    aiThinking = false;
    consecutivePasses = 0;
    notifyListeners();
    _scheduleAiTurnIfNeeded();
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

  /// Reorders a tile within the current player's rack (drag-to-arrange).
  /// Pending placements keep pointing at the right tiles via index remapping.
  void reorderRack(int from, int to) {
    if (from == to) return;
    final rack = currentPlayer.rack;
    if (from < 0 || from >= rack.length || to < 0 || to >= rack.length) return;

    final tile = rack.removeAt(from);
    rack.insert(to, tile);

    if (pending.isNotEmpty) {
      int remap(int k) {
        if (k == from) return to;
        var idx = k > from ? k - 1 : k;
        if (idx >= to) idx += 1;
        return idx;
      }

      final updated = <String, PendingPlacement>{};
      pending.forEach((key, p) {
        updated[key] = PendingPlacement(p.row, p.col, p.tile, remap(p.rackIndex));
      });
      pending
        ..clear()
        ..addAll(updated);
    }
    notifyListeners();
  }

  /// Fills the pending tiles with the best move the generator can find for the
  /// current (human) player, so they can review it and press Play, or recall.
  bool suggest() {
    if (gameOver || isComputerTurn) return false;
    recallAll();
    final moves = ai.generator.generate(board, currentPlayer.rack);
    if (moves.isEmpty) {
      statusMessage = 'No word found — try exchanging tiles.';
      notifyListeners();
      return false;
    }
    moves.sort((a, b) => b.score.compareTo(a.score));
    final best = moves.first;

    final usedIndices = <int>{};
    for (final p in best.placements) {
      final idx = _matchRackIndex(p.tile, usedIndices);
      if (idx == -1) {
        recallAll();
        statusMessage = 'Could not build a suggestion.';
        notifyListeners();
        return false;
      }
      usedIndices.add(idx);
      pending['${p.row},${p.col}'] = PendingPlacement(p.row, p.col, p.tile, idx);
    }
    statusMessage =
        'Suggestion: ${best.mainWord} for ${best.score}. Press Play to confirm.';
    notifyListeners();
    return true;
  }

  int _matchRackIndex(Tile placed, Set<int> used) {
    final rack = currentPlayer.rack;
    for (var i = 0; i < rack.length; i++) {
      if (used.contains(i)) continue;
      final t = rack[i];
      if (placed.isBlank && t.isBlank) return i;
      if (!placed.isBlank && !t.isBlank && t.letter == placed.letter) return i;
    }
    return -1;
  }

  // --- Turn resolution -------------------------------------------------------

  /// Validates and, if legal, commits the current turn. Returns the result so
  /// the UI can animate feedback. Invalid moves leave pending tiles in place.
  MoveResult commitTurn() {
    if (gameOver) return MoveResult.invalid('Game over.');
    if (isComputerTurn) return MoveResult.invalid('It is the computer\'s turn.');
    final placements = pending.values
        .map((p) => Placement(p.row, p.col, p.tile))
        .toList();
    final result = referee.evaluate(board, placements);
    if (!result.valid) {
      statusMessage = result.error ?? 'Invalid move.';
      notifyListeners();
      return result;
    }
    _applyValidatedMove(placements, result);
    return result;
  }

  /// Commits a validated set of placements for the current player: writes tiles
  /// to the board, updates score and rack, advances the turn, persists, and
  /// schedules the computer's reply if needed. Shared by humans and the AI.
  void _applyValidatedMove(List<Placement> placements, MoveResult result) {
    for (final p in placements) {
      board.cellAt(p.row, p.col).tile = p.tile;
    }

    final usedTiles = placements.map((p) => p.tile).toList();
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
    _scheduleAiTurnIfNeeded();
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
    _scheduleAiTurnIfNeeded();
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
    _scheduleAiTurnIfNeeded();
    return true;
  }

  // --- Computer opponent -----------------------------------------------------

  /// If it's the computer's turn, flag "thinking" and run the move after a
  /// short delay so the player can see the board update first.
  void _scheduleAiTurnIfNeeded() {
    if (gameOver || aiThinking || !currentPlayer.isAI) return;
    aiThinking = true;
    notifyListeners();
    final token = _aiToken;
    Future.delayed(const Duration(milliseconds: 650), () {
      if (token == _aiToken) _runAiTurn();
    });
  }

  void _runAiTurn() {
    if (gameOver || !currentPlayer.isAI) {
      aiThinking = false;
      notifyListeners();
      return;
    }
    final decision = ai.decide(
      board,
      currentPlayer.rack,
      aiDifficulty,
      canExchange: bag.remaining >= kRackCapacity,
    );
    aiThinking = false;

    switch (decision.type) {
      case AiActionType.play:
        final move = decision.move!;
        final result = referee.evaluate(board, move.placements);
        if (result.valid) {
          _applyValidatedMove(move.placements, result);
        } else {
          pass(); // Safety net; should not happen.
        }
      case AiActionType.exchange:
        // Exchange the whole rack to fish for a playable set.
        exchange(List<int>.generate(currentPlayer.rack.length, (i) => i));
      case AiActionType.pass:
        pass();
    }
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
