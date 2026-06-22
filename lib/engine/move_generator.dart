// lib/engine/move_generator.dart —
//
// Anchor-based legal-move generator across both axes. Powers both the AI opponent
// and the human Suggest feature; every candidate is fully validated and scored.
//
// See docs/DESIGN.md for how this fits the overall architecture.

import '../models/board.dart';
import '../models/tile.dart';
import 'dictionary.dart';
import 'referee.dart';
import 'trie.dart';

/// A fully-scored legal move produced by the [MoveGenerator].
class GeneratedMove {
  final List<Placement> placements;
  final int score;
  final List<ScoredWord> words;

  GeneratedMove(this.placements, this.score, this.words);

  int get tilesUsed => placements.length;
  String get mainWord => words.isEmpty ? '' : words.first.word;
}

/// Generates every legal move for a rack against the committed board, fully
/// offline using the in-memory [Trie] and validated/scored by the
/// [ScrabbleReferee]. This is the search core behind the computer opponent.
///
/// For each board line (rows for horizontal plays, columns for vertical plays)
/// it walks outward from maximal word starts, extending through committed tiles
/// and rack tiles while the prefix remains valid in the trie. Candidate main
/// words are then handed to the referee, which authoritatively validates any
/// perpendicular cross-words and computes the score.
class MoveGenerator {
  final ScrabbleReferee referee;
  final Trie _trie;

  MoveGenerator(Dictionary dictionary)
      : referee = ScrabbleReferee(dictionary),
        _trie = dictionary.trie;

  static const List<String> _alphabet = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', //
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'
  ];

  // Transient state for the duration of a single generate() call.
  late GameBoard _board;
  late List<Tile> _rack;
  late bool _emptyBoard;
  late Set<String> _seen;
  late List<GeneratedMove> _moves;

  List<GeneratedMove> generate(GameBoard board, List<Tile> rack) {
    _board = board;
    _rack = rack;
    _emptyBoard = board.isEmpty;
    _seen = <String>{};
    _moves = <GeneratedMove>[];

    _generateAxis(horizontal: true);
    _generateAxis(horizontal: false);
    return _moves;
  }

  void _generateAxis({required bool horizontal}) {
    for (var line = 0; line < kBoardSize; line++) {
      // On an empty board the only legal first word must cross the center, so
      // only the center line in each orientation can yield moves.
      if (_emptyBoard && line != 7) continue;

      var minContact = kBoardSize;
      var maxContact = -1;
      if (!_emptyBoard) {
        for (var pos = 0; pos < kBoardSize; pos++) {
          final rc = _cell(horizontal, line, pos);
          final committed = _board.tileAt(rc[0], rc[1]) != null;
          final anchor = !committed && _hasFilledNeighbor(rc[0], rc[1]);
          if (committed || anchor) {
            if (pos < minContact) minContact = pos;
            if (pos > maxContact) maxContact = pos;
          }
        }
        if (maxContact < 0) continue; // No play possible on this line.
      } else {
        minContact = 7;
        maxContact = 7;
      }

      final startLo = (minContact - _rack.length).clamp(0, kBoardSize - 1);
      for (var start = startLo; start < kBoardSize; start++) {
        if (!_emptyBoard && start > maxContact) break;
        // A maximal word's start must have an empty/edge cell before it.
        if (start > 0) {
          final prev = _cell(horizontal, line, start - 1);
          if (_board.tileAt(prev[0], prev[1]) != null) continue;
        }
        _extend(
          horizontal: horizontal,
          line: line,
          pos: start,
          node: _trie.root,
          placed: <Placement>[],
          used: 0,
          connected: false,
          maxContact: _emptyBoard ? kBoardSize - 1 : maxContact,
        );
      }
    }
  }

  void _extend({
    required bool horizontal,
    required int line,
    required int pos,
    required TrieNode node,
    required List<Placement> placed,
    required int used,
    required bool connected,
    required int maxContact,
  }) {
    if (pos >= kBoardSize) return;
    // Once past the last contact cell without connecting, no word can be legal.
    if (!_emptyBoard && pos > maxContact && !connected) return;

    final rc = _cell(horizontal, line, pos);
    final r = rc[0];
    final c = rc[1];
    final committed = _board.tileAt(r, c);

    if (committed != null) {
      final child = node.children[committed.letter];
      if (child == null) return;
      _record(horizontal, line, pos, child, placed, true);
      _extend(
        horizontal: horizontal,
        line: line,
        pos: pos + 1,
        node: child,
        placed: placed,
        used: used,
        connected: true,
        maxContact: maxContact,
      );
      return;
    }

    final anchorHere = _hasFilledNeighbor(r, c);
    for (var i = 0; i < _rack.length; i++) {
      if ((used & (1 << i)) != 0) continue;
      final tile = _rack[i];
      final letters = tile.isBlank ? _alphabet : [tile.letter];
      for (final letter in letters) {
        final child = node.children[letter];
        if (child == null) continue;
        final placedTile =
            tile.isBlank ? const Tile.blank().assignBlank(letter) : tile;
        placed.add(Placement(r, c, placedTile));
        _record(horizontal, line, pos, child, placed, connected || anchorHere);
        _extend(
          horizontal: horizontal,
          line: line,
          pos: pos + 1,
          node: child,
          placed: placed,
          used: used | (1 << i),
          connected: connected || anchorHere,
          maxContact: maxContact,
        );
        placed.removeLast();
      }
    }
  }

  /// Records a candidate word ending at [pos] if it is maximal, connected, and
  /// passes the referee (which validates cross-words and scores the move).
  void _record(
    bool horizontal,
    int line,
    int pos,
    TrieNode node,
    List<Placement> placed,
    bool connected,
  ) {
    if (placed.isEmpty || !node.isWord) return;

    // Maximality: the next cell along the axis must be empty or off-board.
    final next = pos + 1;
    if (next < kBoardSize) {
      final rc = _cell(horizontal, line, next);
      if (_board.tileAt(rc[0], rc[1]) != null) return;
    }

    if (_emptyBoard) {
      if (!placed.any((p) => p.row == 7 && p.col == 7)) return;
    } else if (!connected) {
      return;
    }

    final key = _key(placed);
    if (!_seen.add(key)) return;

    final result = referee.evaluate(_board, placed);
    if (result.valid) {
      _moves.add(GeneratedMove(List<Placement>.of(placed), result.score, result.words));
    }
  }

  List<int> _cell(bool horizontal, int line, int pos) =>
      horizontal ? [line, pos] : [pos, line];

  bool _hasFilledNeighbor(int r, int c) {
    if (r > 0 && _board.tileAt(r - 1, c) != null) return true;
    if (r < kBoardSize - 1 && _board.tileAt(r + 1, c) != null) return true;
    if (c > 0 && _board.tileAt(r, c - 1) != null) return true;
    if (c < kBoardSize - 1 && _board.tileAt(r, c + 1) != null) return true;
    return false;
  }

  String _key(List<Placement> placed) {
    final b = StringBuffer();
    for (final p in placed) {
      b
        ..write(p.row)
        ..write(',')
        ..write(p.col)
        ..write(':')
        ..write(p.tile.letter)
        ..write('|');
    }
    return b.toString();
  }
}
