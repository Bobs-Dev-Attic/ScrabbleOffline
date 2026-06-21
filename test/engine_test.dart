import 'package:flutter_test/flutter_test.dart';
import 'package:scrabble_offline/engine/dictionary.dart';
import 'package:scrabble_offline/engine/referee.dart';
import 'package:scrabble_offline/engine/trie.dart';
import 'package:scrabble_offline/models/board.dart';
import 'package:scrabble_offline/models/tile.dart';
import 'package:scrabble_offline/models/tile_bag.dart';

void main() {
  group('Trie', () {
    test('inserts and finds words case-insensitively', () {
      final trie = Trie();
      trie.insert('cat');
      expect(trie.contains('CAT'), isTrue);
      expect(trie.contains('cat'), isTrue);
      expect(trie.contains('ca'), isFalse);
      expect(trie.hasPrefix('ca'), isTrue);
      expect(trie.hasPrefix('dog'), isFalse);
      expect(trie.wordCount, 1);
    });
  });

  group('TileBag', () {
    test('starts with 100 tiles', () {
      final bag = TileBag();
      expect(bag.remaining, 100);
    });

    test('draw reduces the bag', () {
      final bag = TileBag();
      final drawn = bag.draw(7);
      expect(drawn.length, 7);
      expect(bag.remaining, 93);
    });
  });

  group('ScrabbleReferee', () {
    late Dictionary dict;
    late ScrabbleReferee referee;

    setUp(() {
      dict = Dictionary();
      dict.loadWords(['CAT', 'CATS', 'AT', 'HAT', 'HATS', 'AS', 'TA']);
      referee = ScrabbleReferee(dict);
    });

    test('first move must cross center', () {
      final board = GameBoard();
      final result = referee.evaluate(board, [
        const Placement(0, 0, Tile(letter: 'C', value: 3)),
        const Placement(0, 1, Tile(letter: 'A', value: 1)),
        const Placement(0, 2, Tile(letter: 'T', value: 1)),
      ]);
      expect(result.valid, isFalse);
    });

    test('valid first move scores with center double-word', () {
      final board = GameBoard();
      // CAT placed horizontally across the center (7,6)-(7,8); center is (7,7).
      final result = referee.evaluate(board, [
        const Placement(7, 6, Tile(letter: 'C', value: 3)),
        const Placement(7, 7, Tile(letter: 'A', value: 1)),
        const Placement(7, 8, Tile(letter: 'T', value: 1)),
      ]);
      expect(result.valid, isTrue);
      // (3 + 1 + 1) * 2 (center double word) = 10.
      expect(result.score, 10);
      expect(result.words.first.word, 'CAT');
    });

    test('rejects invalid word', () {
      final board = GameBoard();
      final result = referee.evaluate(board, [
        const Placement(7, 7, Tile(letter: 'X', value: 8)),
        const Placement(7, 8, Tile(letter: 'Z', value: 10)),
      ]);
      expect(result.valid, isFalse);
    });

    test('cross word is validated and scored', () {
      final board = GameBoard();
      // Commit CAT horizontally through center.
      board.cellAt(7, 6).tile = const Tile(letter: 'C', value: 3);
      board.cellAt(7, 7).tile = const Tile(letter: 'A', value: 1);
      board.cellAt(7, 8).tile = const Tile(letter: 'T', value: 1);

      // Place H above and S below the C to form HAT? No: build "AT" downward
      // from the existing A using new tiles is impossible (A occupied).
      // Instead extend: place S after T -> CATS (existing C,A,T + new S).
      final result = referee.evaluate(board, [
        const Placement(7, 9, Tile(letter: 'S', value: 1)),
      ]);
      expect(result.valid, isTrue);
      expect(result.words.first.word, 'CATS');
    });

    test('bingo bonus applied for 7 tiles', () {
      final dict2 = Dictionary();
      dict2.loadWords(['AEROBES']);
      final ref2 = ScrabbleReferee(dict2);
      final board = GameBoard();
      const letters = 'AEROBES';
      final placements = <Placement>[
        for (var i = 0; i < 7; i++)
          Placement(7, 4 + i, Tile(letter: letters[i], value: 1)),
      ];
      final result = ref2.evaluate(board, placements);
      expect(result.valid, isTrue);
      expect(result.isBingo, isTrue);
      expect(result.score, greaterThanOrEqualTo(kBingoBonus));
    });
  });
}
