// lib/state/game_state.dart —
//
// Central game controller (ChangeNotifier). Owns turn flow, tile placement, scoring,
// the AI turn, Suggest/ghosts, the play-history log, and local persistence.
//
// See docs/DESIGN.md for how this fits the overall architecture.

import 'dart:async';

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

/// One entry in the game's move history (shown in the horizontal log).
class MoveLogEntry {
  final String player;
  final String label; // a word, or "pass" / "swap"
  final int points;
  final bool isBingo;

  const MoveLogEntry(this.player, this.label, this.points, {this.isBingo = false});
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

  /// Chronological log of moves, shown in the game screen's history strip.
  /// Bounded to the most recent [kMaxHistory] entries so a very long game can't
  /// grow it without limit.
  final List<MoveLogEntry> history = [];

  /// Maximum number of move-log entries retained.
  static const int kMaxHistory = 200;

  /// Appends a move-log entry, trimming the oldest beyond [kMaxHistory].
  void _addHistory(MoveLogEntry entry) {
    history.add(entry);
    if (history.length > kMaxHistory) {
      history.removeRange(0, history.length - kMaxHistory);
    }
  }

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

  /// Cells placed by the most recent committed move, with their order along the
  /// word, so the board can animate them dropping in. [moveSerial] changes each
  /// move so the animation re-fires.
  Set<String> lastPlaced = {};
  Map<String, int> lastPlacedOrder = {};
  int moveSerial = 0;

  /// Bumped each time the player asks for a suggestion; [suggestedIds] holds the
  /// rack tile ids that spell the suggested word, so the rack can highlight and
  /// enlarge them as they slide into place.
  int suggestSerial = 0;
  Set<int> suggestedIds = {};

  /// Ghost tiles showing where the current suggestion would be placed on the
  /// board (keyed by "row,col"). Rendered translucently as a placement hint.
  Map<String, Tile> ghosts = {};
  Tile? ghostAt(int row, int col) => ghosts['$row,$col'];

  /// True once the suggestion ghosts begin fading: the board animates their
  /// opacity to 0 over [kGhostFadeMs] before they are cleared.
  bool ghostsFading = false;
  Timer? _ghostFadeTimer;
  Timer? _ghostFadeStartTimer;

  /// Set once the controller is disposed, so pending timers / scheduled AI
  /// turns don't call notifyListeners() on a dead notifier.
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _ghostFadeTimer?.cancel();
    _ghostFadeStartTimer?.cancel();
    super.dispose();
  }

  /// How long the slow ghost fade-out takes (also used by the board's
  /// AnimatedOpacity). The ghosts hold at full opacity briefly, then fade,
  /// so they disappear roughly 8-9s after a suggestion is shown.
  static const int kGhostFadeMs = 8500;

  void _cancelGhostFade() {
    _ghostFadeTimer?.cancel();
    _ghostFadeTimer = null;
    _ghostFadeStartTimer?.cancel();
    _ghostFadeStartTimer = null;
    ghostsFading = false;
  }

  /// Begins fading the suggestion ghosts now: animates them out over
  /// [kGhostFadeMs], then clears them. Safe to call repeatedly.
  void _beginGhostFade() {
    if (ghosts.isEmpty || ghostsFading) return;
    ghostsFading = true;
    _ghostFadeTimer?.cancel();
    _ghostFadeTimer = Timer(const Duration(milliseconds: kGhostFadeMs), () {
      if (_disposed) return;
      ghosts = {};
      ghostsFading = false;
      notifyListeners();
    });
    notifyListeners();
  }

  /// Arms the automatic ghost fade: the ghosts render at full opacity for a
  /// brief hold (one frame is required so the opacity animation has a starting
  /// value), then fade out on their own — even if the player never places a
  /// tile. The caller is expected to notifyListeners() after setting ghosts.
  void _scheduleGhostFade() {
    _ghostFadeStartTimer?.cancel();
    _ghostFadeStartTimer = Timer(const Duration(milliseconds: 500), () {
      if (_disposed) return;
      _beginGhostFade();
    });
  }

  /// Cycle of suggested moves; pressing Suggest repeatedly advances through
  /// them (different words and positions). Regenerated when the rack/turn/board
  /// changes.
  List<GeneratedMove> _suggestionCycle = [];
  int _suggestionIndex = 0;
  String _suggestionSignature = '';

  GameState({required this.dictionary, required this.persistence}) {
    referee = ScrabbleReferee(dictionary);
    ai = AiPlayer(MoveGenerator(dictionary));
  }

  Player get currentPlayer => players[currentPlayerIndex];

  /// True when it is the computer's turn (input should be locked).
  bool get isComputerTurn => !gameOver && currentPlayer.isAI;

  /// Starts a fresh game with [humanPlayers] humans and [computerPlayers] AI
  /// opponents (any mix, up to the board's practical limits). When there are
  /// computers, all of them play at [difficulty].
  void newGame({
    int humanPlayers = 2,
    int computerPlayers = 0,
    AiDifficulty difficulty = AiDifficulty.medium,
  }) {
    vsComputer = computerPlayers > 0;
    aiDifficulty = difficulty;
    _aiToken++;
    board = GameBoard();
    bag = TileBag();
    players = [];

    // Humans first (a lone human vs computers is simply "You").
    if (vsComputer && humanPlayers == 1) {
      players.add(Player(name: 'You'));
    } else {
      for (var i = 0; i < humanPlayers; i++) {
        players.add(Player(name: 'Player ${i + 1}'));
      }
    }
    // Then the computer opponents (short labels: CMP1, CMP2, CMP3).
    for (var i = 0; i < computerPlayers; i++) {
      players.add(Player(name: 'CMP${i + 1}', isAI: true));
    }

    for (final p in players) {
      p.refill(bag.draw);
    }
    currentPlayerIndex = 0;
    pending.clear();
    statusMessage = '';
    gameOver = false;
    aiThinking = false;
    consecutivePasses = 0;
    lastPlaced = {};
    lastPlacedOrder = {};
    suggestedIds = {};
    history.clear();
    _cancelGhostFade();
    ghosts = {};
    _suggestionCycle = [];
    _suggestionSignature = '';
    _suggestionIndex = 0;
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
    lastPlaced = {};
    lastPlacedOrder = {};
    suggestedIds = {};
    history.clear();
    _cancelGhostFade();
    ghosts = {};
    _suggestionCycle = [];
    _suggestionSignature = '';
    _suggestionIndex = 0;
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
    // Once the player starts placing, fade the suggestion ghosts out now.
    _beginGhostFade();
    notifyListeners();
    return true;
  }

  /// Recalls a single pending tile back to the rack (rollback for one cell).
  void recallTile(int row, int col) {
    pending.remove('$row,$col');
    notifyListeners();
  }

  /// Moves an in-progress (pending) tile from one cell to another empty cell,
  /// letting the player adjust placement before committing.
  void movePending(int fromRow, int fromCol, int toRow, int toCol) {
    final from = '$fromRow,$fromCol';
    final to = '$toRow,$toCol';
    final p = pending[from];
    if (p == null) return;
    if (from == to) return;
    if (!board.isEmptyAt(toRow, toCol) || pending.containsKey(to)) return;
    pending.remove(from);
    pending[to] = PendingPlacement(toRow, toCol, p.tile, p.rackIndex);
    notifyListeners();
  }

  /// Recalls all pending tiles — the full rollback routine.
  void recallAll() {
    pending.clear();
    _cancelGhostFade();
    ghosts = {};
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
    final id = currentPlayer.rackIds.removeAt(from);
    currentPlayer.rackIds.insert(to, id);

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

  /// Rearranges the current player's rack so the best move's letters come first,
  /// in word order — a hint that lives entirely on the rack (nothing is placed
  /// on the board). The UI animates the tiles sliding/enlarging into place.
  bool suggest() {
    if (gameOver || isComputerTurn) return false;
    recallAll();

    final sig = _suggestionSignatureValue();
    if (sig != _suggestionSignature || _suggestionCycle.isEmpty) {
      final moves = ai.generator.generate(board, currentPlayer.rack);
      if (moves.isEmpty) {
        _suggestionCycle = [];
        _suggestionSignature = sig;
        statusMessage = 'No word found — try exchanging tiles.';
        notifyListeners();
        return false;
      }
      // Order all candidate placements by score (highest first) so repeated
      // presses cycle through the best spots — including the same word in
      // different positions — with ghost tiles showing each one.
      _suggestionCycle = [...moves]
        ..sort((a, b) => b.score.compareTo(a.score));
      if (_suggestionCycle.length > 25) {
        _suggestionCycle = _suggestionCycle.sublist(0, 25);
      }
      _suggestionSignature = sig;
      _suggestionIndex = 0;
    } else {
      _suggestionIndex = (_suggestionIndex + 1) % _suggestionCycle.length;
    }

    _applySuggestion(_suggestionCycle[_suggestionIndex]);
    return true;
  }

  /// Signature of the inputs that determine the suggestion set: turn, board
  /// progress, and the rack's letters (order-independent).
  String _suggestionSignatureValue() {
    final letters = (currentPlayer.rack
            .map((t) => t.isBlank ? '_' : t.letter)
            .toList()
          ..sort())
        .join();
    return '$currentPlayerIndex|$moveSerial|$letters';
  }

  /// Rearranges the rack so [best]'s letters lead, in word order, and flags
  /// them for the rack animation.
  void _applySuggestion(GeneratedMove best) {
    final usedSet = <int>{};
    final usedOrder = <int>[];
    for (final p in best.placements) {
      final idx = _matchRackIndex(p.tile, usedSet);
      if (idx == -1) {
        statusMessage = 'Could not build a suggestion.';
        notifyListeners();
        return;
      }
      usedSet.add(idx);
      usedOrder.add(idx);
    }

    final rest = [
      for (var i = 0; i < currentPlayer.rack.length; i++)
        if (!usedSet.contains(i)) i,
    ];
    final order = [...usedOrder, ...rest];

    final rack = currentPlayer.rack;
    final ids = currentPlayer.rackIds;
    final newRack = [for (final i in order) rack[i]];
    final newIds = [for (final i in order) ids[i]];
    rack
      ..clear()
      ..addAll(newRack);
    ids
      ..clear()
      ..addAll(newIds);

    // Ghost tiles show exactly where this suggestion would be placed. They
    // hold at full opacity briefly, then slowly fade out on their own.
    _cancelGhostFade();
    ghosts = {
      for (final p in best.placements) '${p.row},${p.col}': p.tile,
    };
    _scheduleGhostFade();

    suggestedIds = newIds.take(usedOrder.length).toSet();
    suggestSerial++;
    final n = _suggestionCycle.length;
    statusMessage =
        'Try ${_suggestionIndex + 1}/$n: ${best.mainWord} for ${best.score}'
        ' — tap Suggest for other spots';
    notifyListeners();
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

  /// Evaluates the in-progress placement without committing, so the UI can show
  /// a live potential score. Returns an invalid result when nothing is placed.
  MoveResult previewMove() {
    final placements = pending.values
        .map((p) => Placement(p.row, p.col, p.tile))
        .toList();
    if (placements.isEmpty) return MoveResult.invalid('');
    return referee.evaluate(board, placements);
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

    // Record freshly placed cells (ordered) for the board drop-in animation.
    moveSerial++;
    lastPlaced = {for (final p in placements) '${p.row},${p.col}'};
    lastPlacedOrder = {
      for (var i = 0; i < placements.length; i++)
        '${placements[i].row},${placements[i].col}': i,
    };

    final usedTiles = placements.map((p) => p.tile).toList();
    currentPlayer.removeFromRack(usedTiles);
    currentPlayer.score += result.score;
    currentPlayer.refill(bag.draw);

    final summary = result.words.map((w) => '${w.word} (${w.score})').join(', ');
    statusMessage = '${currentPlayer.name} scored ${result.score}'
        '${result.isBingo ? ' — BINGO! +$kBingoBonus' : ''} • $summary';
    _addHistory(MoveLogEntry(
      currentPlayer.name,
      result.words.isNotEmpty ? result.words.first.word : 'move',
      result.score,
      isBingo: result.isBingo,
    ));

    pending.clear();
    _cancelGhostFade();
    ghosts = {};
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
    _addHistory(MoveLogEntry(currentPlayer.name, 'pass', 0));
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
        returned.add(currentPlayer.rack[idx]);
        currentPlayer.removeRackAt(idx);
      }
    }
    currentPlayer.refill(bag.draw);
    bag.returnTiles(returned);
    consecutivePasses = 0;
    statusMessage = '${currentPlayer.name} exchanged ${returned.length} tiles.';
    _addHistory(MoveLogEntry(currentPlayer.name, 'swap', 0));
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
      if (_disposed) return;
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
