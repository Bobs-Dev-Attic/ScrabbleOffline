import 'dart:math';

import '../models/board.dart';
import '../models/tile.dart';
import 'move_generator.dart';

/// Strength levels for the computer opponent. All three use the same offline
/// move generator; they differ only in which candidate move they pick.
enum AiDifficulty {
  easy,
  medium,
  hard;

  String get label => switch (this) {
        AiDifficulty.easy => 'Easy',
        AiDifficulty.medium => 'Medium',
        AiDifficulty.hard => 'Hard',
      };
}

/// What the AI decided to do on its turn.
enum AiActionType { play, exchange, pass }

class AiDecision {
  final AiActionType type;
  final GeneratedMove? move;

  const AiDecision.play(this.move) : type = AiActionType.play;
  const AiDecision.exchange()
      : type = AiActionType.exchange,
        move = null;
  const AiDecision.pass()
      : type = AiActionType.pass,
        move = null;
}

/// Selects a move from the generator according to a difficulty setting.
///
/// - **Hard:** always the highest-scoring move (random tie-break).
/// - **Medium:** a solid upper-middle move — strong but fallible.
/// - **Easy:** a deliberately weak, low-scoring move so the player can win.
class AiPlayer {
  final MoveGenerator generator;
  final Random _random;

  AiPlayer(this.generator, {Random? random}) : _random = random ?? Random();

  /// Chooses an action for the current rack. When no legal move exists the AI
  /// exchanges (if the bag allows) or passes.
  AiDecision decide(
    GameBoard board,
    List<Tile> rack,
    AiDifficulty difficulty, {
    required bool canExchange,
  }) {
    final moves = generator.generate(board, rack);
    if (moves.isEmpty) {
      return canExchange ? const AiDecision.exchange() : const AiDecision.pass();
    }

    moves.sort((a, b) => b.score.compareTo(a.score));

    switch (difficulty) {
      case AiDifficulty.hard:
        final best = moves.first.score;
        final top = moves.where((m) => m.score == best).toList();
        return AiDecision.play(top[_random.nextInt(top.length)]);

      case AiDifficulty.medium:
        // Pick from the upper-middle band of moves (skip the very best).
        final lo = (moves.length * 0.25).floor();
        final hi = (moves.length * 0.6).ceil().clamp(lo + 1, moves.length);
        final pick = lo + _random.nextInt(hi - lo);
        return AiDecision.play(moves[pick]);

      case AiDifficulty.easy:
        // Favor low-scoring moves so the opponent is beatable.
        final start = (moves.length * 0.6).floor().clamp(0, moves.length - 1);
        final pool = moves.sublist(start);
        return AiDecision.play(pool[_random.nextInt(pool.length)]);
    }
  }
}
