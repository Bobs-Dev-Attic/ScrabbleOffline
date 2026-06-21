import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scrabble_offline/engine/ai_player.dart';
import 'package:scrabble_offline/engine/dictionary.dart';
import 'package:scrabble_offline/engine/move_generator.dart';
import 'package:scrabble_offline/models/board.dart';
import 'package:scrabble_offline/models/tile.dart';

/// Performance smoke test against the real bundled dictionary. The computer
/// must pick a move fast enough to feel responsive on the web.
void main() {
  test('AI move generation is fast with the full dictionary', () {
    final file = File('assets/dictionary.txt');
    expect(file.existsSync(), isTrue, reason: 'dictionary asset missing');

    final dict = Dictionary()..loadWords(file.readAsLinesSync());
    final gen = MoveGenerator(dict);
    final ai = AiPlayer(gen);

    // Mid-game board: a word through the center plus a crossing word.
    final board = GameBoard();
    const word = 'RETINAS';
    for (var i = 0; i < word.length; i++) {
      board.cellAt(7, 4 + i).tile = Tile(letter: word[i], value: 1);
    }
    const down = 'AND';
    for (var i = 0; i < down.length; i++) {
      board.cellAt(8 + i, 6).tile = Tile(letter: down[i], value: 1);
    }

    final rack = [
      const Tile(letter: 'S', value: 1),
      const Tile(letter: 'T', value: 1),
      const Tile(letter: 'A', value: 1),
      const Tile(letter: 'R', value: 1),
      const Tile(letter: 'E', value: 1),
      const Tile(letter: 'N', value: 1),
      const Tile(letter: 'O', value: 1),
    ];

    final sw = Stopwatch()..start();
    final moves = gen.generate(board, rack);
    sw.stop();
    // ignore: avoid_print
    print('Generated ${moves.length} moves in ${sw.elapsedMilliseconds} ms '
        '(dictionary ${dict.wordCount} words)');

    expect(moves, isNotEmpty);
    // Generous bound: native VM is faster than web, but this catches blowups.
    expect(sw.elapsedMilliseconds, lessThan(2000));

    final decision =
        ai.decide(board, rack, AiDifficulty.hard, canExchange: true);
    expect(decision.type, AiActionType.play);
  });
}
