// lib/engine/referee.dart —
//
// Referee & scoring engine. Validates that a move is linear/contiguous/connected,
// extracts cross-words, applies letter/word multipliers, and awards the bingo bonus.
//
// See docs/DESIGN.md for how this fits the overall architecture.

import '../models/board.dart';
import '../models/tile.dart';
import 'dictionary.dart';

/// A single tile placed onto the board during the current turn.
class Placement {
  final int row;
  final int col;
  final Tile tile;

  const Placement(this.row, this.col, this.tile);
}

/// A scored word formed by a move, retained for UI feedback.
class ScoredWord {
  final String word;
  final int score;
  const ScoredWord(this.word, this.score);
}

/// Outcome of validating and scoring a candidate move.
class MoveResult {
  final bool valid;
  final String? error;
  final int score;
  final List<ScoredWord> words;
  final bool isBingo;

  const MoveResult._({
    required this.valid,
    this.error,
    this.score = 0,
    this.words = const [],
    this.isBingo = false,
  });

  factory MoveResult.invalid(String error) =>
      MoveResult._(valid: false, error: error);

  factory MoveResult.success({
    required int score,
    required List<ScoredWord> words,
    required bool isBingo,
  }) =>
      MoveResult._(
        valid: true,
        score: score,
        words: words,
        isBingo: isBingo,
      );
}

/// The +50 bonus awarded for using all seven rack tiles in one move.
const int kBingoBonus = 50;

/// Validates linear placement, extracts main and cross words, and computes the
/// score for a candidate move against the committed [board].
class ScrabbleReferee {
  final Dictionary dictionary;

  ScrabbleReferee(this.dictionary);

  /// Validates [placements] against [board] and returns the scored result.
  /// The board is NOT mutated; the caller commits a valid move separately.
  MoveResult evaluate(GameBoard board, List<Placement> placements) {
    if (placements.isEmpty) {
      return MoveResult.invalid('No tiles placed.');
    }

    // 1. Bounds + non-overlap with committed tiles + no unassigned blanks.
    final occupied = <String>{};
    for (final p in placements) {
      if (!GameBoard.inBounds(p.row, p.col)) {
        return MoveResult.invalid('Tile placed off the board.');
      }
      if (!board.isEmptyAt(p.row, p.col)) {
        return MoveResult.invalid('Cell already occupied.');
      }
      if (p.tile.isUnassignedBlank) {
        return MoveResult.invalid('Assign a letter to the blank tile.');
      }
      final key = '${p.row},${p.col}';
      if (occupied.contains(key)) {
        return MoveResult.invalid('Two tiles on the same cell.');
      }
      occupied.add(key);
    }

    // 2. Single axis.
    final rows = placements.map((p) => p.row).toSet();
    final cols = placements.map((p) => p.col).toSet();
    final bool horizontal;
    if (rows.length == 1) {
      horizontal = true;
    } else if (cols.length == 1) {
      horizontal = false;
    } else {
      return MoveResult.invalid('Tiles must share a single row or column.');
    }

    // Build a virtual lookup of placed tiles for traversal.
    final placed = <String, Tile>{
      for (final p in placements) '${p.row},${p.col}': p.tile,
    };
    Tile? tileAt(int r, int c) {
      if (!GameBoard.inBounds(r, c)) return null;
      return placed['$r,$c'] ?? board.tileAt(r, c);
    }

    // 3. Contiguity along the main axis (no gaps among placed+existing tiles).
    if (!_isContiguous(placements, horizontal, tileAt)) {
      return MoveResult.invalid('Tiles must form a continuous line.');
    }

    // 4. Connectivity: first move covers center; later moves touch existing.
    if (board.isEmpty) {
      final touchesCenter = placements.any((p) => p.row == 7 && p.col == 7);
      if (!touchesCenter) {
        return MoveResult.invalid('First word must cross the center square.');
      }
    } else {
      if (!_connectsToBoard(board, placements)) {
        return MoveResult.invalid('Word must connect to existing tiles.');
      }
    }

    // 5. Extract words and score.
    final words = <ScoredWord>[];
    int total = 0;

    final mainWord = _scoreMainWord(board, placements, horizontal, tileAt);
    if (mainWord != null) {
      words.add(mainWord);
      total += mainWord.score;
    }

    for (final p in placements) {
      final cross = _scoreCrossWord(board, p, horizontal, tileAt);
      if (cross != null) {
        words.add(cross);
        total += cross.score;
      }
    }

    // 6. Dictionary validation of every formed word.
    for (final w in words) {
      if (!dictionary.isValidWord(w.word)) {
        return MoveResult.invalid('"${w.word}" is not a valid word.');
      }
    }

    if (words.isEmpty) {
      return MoveResult.invalid('No word formed.');
    }

    final isBingo = placements.length == 7;
    if (isBingo) total += kBingoBonus;

    return MoveResult.success(
      score: total,
      words: words,
      isBingo: isBingo,
    );
  }

  bool _isContiguous(
    List<Placement> placements,
    bool horizontal,
    Tile? Function(int, int) tileAt,
  ) {
    if (placements.length == 1) return true;
    if (horizontal) {
      final row = placements.first.row;
      final colsList = placements.map((p) => p.col).toList()..sort();
      for (var c = colsList.first; c <= colsList.last; c++) {
        if (tileAt(row, c) == null) return false;
      }
    } else {
      final col = placements.first.col;
      final rowsList = placements.map((p) => p.row).toList()..sort();
      for (var r = rowsList.first; r <= rowsList.last; r++) {
        if (tileAt(r, col) == null) return false;
      }
    }
    return true;
  }

  bool _connectsToBoard(GameBoard board, List<Placement> placements) {
    const deltas = [
      [-1, 0],
      [1, 0],
      [0, -1],
      [0, 1],
    ];
    for (final p in placements) {
      for (final d in deltas) {
        final r = p.row + d[0];
        final c = p.col + d[1];
        if (GameBoard.inBounds(r, c) && !board.isEmptyAt(r, c)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Scores the primary word along the move axis. Returns null when the move is
  /// a single tile whose only word is perpendicular (handled as a cross word).
  ScoredWord? _scoreMainWord(
    GameBoard board,
    List<Placement> placements,
    bool horizontal,
    Tile? Function(int, int) tileAt,
  ) {
    final anchor = placements.first;
    int r = anchor.row;
    int c = anchor.col;

    // Walk to the start of the word.
    if (horizontal) {
      while (tileAt(r, c - 1) != null) {
        c--;
      }
    } else {
      while (tileAt(r - 1, c) != null) {
        r--;
      }
    }

    final buffer = StringBuffer();
    int wordScore = 0;
    int wordMultiplier = 1;
    int length = 0;
    final newCells = {for (final p in placements) '${p.row},${p.col}'};

    while (tileAt(r, c) != null) {
      final tile = tileAt(r, c)!;
      buffer.write(tile.letter);
      length++;
      final isNew = newCells.contains('$r,$c');
      final cell = board.cellAt(r, c);
      var letterScore = tile.value;
      if (isNew) {
        letterScore *= cell.letterMultiplier;
        wordMultiplier *= cell.wordMultiplier;
      }
      wordScore += letterScore;
      if (horizontal) {
        c++;
      } else {
        r++;
      }
    }

    if (length < 2) return null;
    return ScoredWord(buffer.toString(), wordScore * wordMultiplier);
  }

  /// Scores the perpendicular cross word generated by a single placed tile, if
  /// such a word exists (length >= 2).
  ScoredWord? _scoreCrossWord(
    GameBoard board,
    Placement placement,
    bool mainHorizontal,
    Tile? Function(int, int) tileAt,
  ) {
    // Cross word runs perpendicular to the main axis.
    final crossHorizontal = !mainHorizontal;
    int r = placement.row;
    int c = placement.col;

    if (crossHorizontal) {
      while (tileAt(r, c - 1) != null) {
        c--;
      }
    } else {
      while (tileAt(r - 1, c) != null) {
        r--;
      }
    }

    final buffer = StringBuffer();
    int wordScore = 0;
    int wordMultiplier = 1;
    int length = 0;

    while (tileAt(r, c) != null) {
      final tile = tileAt(r, c)!;
      buffer.write(tile.letter);
      length++;
      final isNew = r == placement.row && c == placement.col;
      final cell = board.cellAt(r, c);
      var letterScore = tile.value;
      if (isNew) {
        letterScore *= cell.letterMultiplier;
        wordMultiplier *= cell.wordMultiplier;
      }
      wordScore += letterScore;
      if (crossHorizontal) {
        c++;
      } else {
        r++;
      }
    }

    if (length < 2) return null;
    return ScoredWord(buffer.toString(), wordScore * wordMultiplier);
  }
}
