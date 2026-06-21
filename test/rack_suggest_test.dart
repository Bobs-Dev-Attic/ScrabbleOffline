import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scrabble_offline/engine/dictionary.dart';
import 'package:scrabble_offline/models/tile.dart';
import 'package:scrabble_offline/state/game_state.dart';
import 'package:scrabble_offline/state/persistence.dart';

class FakePersistence extends GamePersistence {
  @override
  Future<void> init() async {}
  @override
  bool get hasSavedGame => false;
  @override
  Future<void> save({
    required board,
    required players,
    required bag,
    required currentPlayerIndex,
  }) async {}
  @override
  SavedGame? load() => null;
  @override
  Future<void> clear() async {}
}

GameState _game(Dictionary dict) =>
    GameState(dictionary: dict, persistence: FakePersistence());

void main() {
  group('reorderRack', () {
    test('moves a tile and preserves the set of letters', () {
      final game = _game(Dictionary()..loadWords(['CAT']));
      game.newGame();
      final rack = game.currentPlayer.rack;
      final before = rack.map((t) => t.letter).toList();
      final moved = before[0];

      game.reorderRack(0, 3);

      expect(game.currentPlayer.rack.length, before.length);
      expect(game.currentPlayer.rack[3].letter, moved);
      expect(
        game.currentPlayer.rack.map((t) => t.letter).toList()..sort(),
        before.toList()..sort(),
      );
    });

    test('remaps pending tile indices so they still point at placed tiles', () {
      final game = _game(Dictionary()..loadWords(['CAT']));
      game.newGame();
      // Force a known rack for determinism.
      game.currentPlayer.rack
        ..clear()
        ..addAll(const [
          Tile(letter: 'C', value: 3),
          Tile(letter: 'A', value: 1),
          Tile(letter: 'T', value: 1),
          Tile(letter: 'D', value: 2),
          Tile(letter: 'O', value: 1),
          Tile(letter: 'G', value: 2),
          Tile(letter: 'S', value: 1),
        ]);
      // Place the 'C' (index 0) on the board as a pending tile.
      game.placeTile(0, 7, 7);
      expect(game.pending.values.first.rackIndex, 0);

      // Reorder a different tile; the pending placement must follow its tile.
      game.reorderRack(4, 1);
      final pendingIdx = game.pending.values.first.rackIndex;
      expect(game.currentPlayer.rack[pendingIdx].letter, 'C');
    });
  });

  group('suggest', () {
    test('fills pending with a valid word for the human', () {
      final dict = Dictionary()
        ..loadWords(File('assets/dictionary.txt').readAsLinesSync());
      final game = _game(dict);
      game.newGame();
      game.currentPlayer.rack
        ..clear()
        ..addAll(const [
          Tile(letter: 'C', value: 3),
          Tile(letter: 'A', value: 1),
          Tile(letter: 'T', value: 1),
          Tile(letter: 'E', value: 1),
          Tile(letter: 'R', value: 1),
          Tile(letter: 'S', value: 1),
          Tile(letter: 'N', value: 1),
        ]);

      final ok = game.suggest();
      expect(ok, isTrue);
      expect(game.pending, isNotEmpty);
      // The suggested move must be a legal move when played.
      final result = game.commitTurn();
      expect(result.valid, isTrue);
      expect(result.score, greaterThan(0));
    });
  });
}
