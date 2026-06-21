import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:scrabble_offline/engine/ai_player.dart';
import 'package:scrabble_offline/engine/dictionary.dart';
import 'package:scrabble_offline/engine/move_generator.dart';
import 'package:scrabble_offline/models/board.dart';
import 'package:scrabble_offline/models/tile.dart';

Dictionary _dict(List<String> words) => Dictionary()..loadWords(words);

void main() {
  group('MoveGenerator', () {
    test('first move: all moves are valid and cross the center', () {
      final gen = MoveGenerator(_dict(['CAT', 'AT', 'TA', 'CATS']));
      final board = GameBoard();
      final rack = [
        const Tile(letter: 'C', value: 3),
        const Tile(letter: 'A', value: 1),
        const Tile(letter: 'T', value: 1),
      ];
      final moves = gen.generate(board, rack);

      expect(moves, isNotEmpty);
      for (final m in moves) {
        expect(m.placements.any((p) => p.row == 7 && p.col == 7), isTrue,
            reason: 'first move must cover center');
      }
      expect(moves.map((m) => m.mainWord), contains('CAT'));
    });

    test('extends an existing word on the board', () {
      final gen = MoveGenerator(_dict(['CAT', 'CATS', 'AS']));
      final board = GameBoard();
      board.cellAt(7, 6).tile = const Tile(letter: 'C', value: 3);
      board.cellAt(7, 7).tile = const Tile(letter: 'A', value: 1);
      board.cellAt(7, 8).tile = const Tile(letter: 'T', value: 1);

      final moves = gen.generate(board, [const Tile(letter: 'S', value: 1)]);

      final cats = moves.where((m) => m.mainWord == 'CATS');
      expect(cats, isNotEmpty);
      expect(cats.first.placements.length, 1);
      expect(cats.first.placements.first.col, 9);
    });

    test('blank tile can stand in for any letter', () {
      final gen = MoveGenerator(_dict(['CAT']));
      final board = GameBoard();
      final rack = [
        const Tile(letter: 'C', value: 3),
        const Tile(letter: 'A', value: 1),
        const Tile.blank(),
      ];
      final moves = gen.generate(board, rack);
      expect(moves.map((m) => m.mainWord), contains('CAT'));
    });
  });

  group('AiPlayer difficulty', () {
    late MoveGenerator gen;
    setUp(() {
      gen = MoveGenerator(_dict(['CAT', 'CATS', 'AT', 'TA', 'AS', 'SAT']));
    });

    GameBoard freshBoard() => GameBoard();
    List<Tile> rack() => [
          const Tile(letter: 'C', value: 3),
          const Tile(letter: 'A', value: 1),
          const Tile(letter: 'T', value: 1),
          const Tile(letter: 'S', value: 1),
        ];

    test('hard picks the highest-scoring move', () {
      final ai = AiPlayer(gen, random: Random(1));
      final all = gen.generate(freshBoard(), rack());
      final best = all.map((m) => m.score).reduce(max);

      final decision = ai.decide(
        freshBoard(),
        rack(),
        AiDifficulty.hard,
        canExchange: true,
      );
      expect(decision.type, AiActionType.play);
      expect(decision.move!.score, best);
    });

    test('easy generally avoids the very best move', () {
      final ai = AiPlayer(gen, random: Random(7));
      final all = gen.generate(freshBoard(), rack());
      final best = all.map((m) => m.score).reduce(max);
      final decision =
          ai.decide(freshBoard(), rack(), AiDifficulty.easy, canExchange: true);
      expect(decision.type, AiActionType.play);
      expect(decision.move!.score, lessThanOrEqualTo(best));
    });

    test('passes when no move and cannot exchange', () {
      final emptyAi = AiPlayer(MoveGenerator(_dict(['ZZZZZ'])));
      final decision = emptyAi.decide(
        GameBoard(),
        [const Tile(letter: 'A', value: 1)],
        AiDifficulty.hard,
        canExchange: false,
      );
      expect(decision.type, AiActionType.pass);
    });
  });
}
