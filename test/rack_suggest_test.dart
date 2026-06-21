import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scrabble_offline/engine/ai_player.dart';
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
      expect(game.currentPlayer.rackIds.length, before.length);
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
    test('rearranges the rack to spell a word, without touching the board', () {
      final dict = Dictionary()
        ..loadWords(File('assets/dictionary.txt').readAsLinesSync());
      final game = _game(dict);
      game.newGame();
      // Give the human a known, word-rich rack.
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
      game.currentPlayer.rackIds
        ..clear()
        ..addAll(List.generate(7, (i) => 1000 + i));

      final ok = game.suggest();
      expect(ok, isTrue);
      // Nothing is placed on the board.
      expect(game.pending, isEmpty);
      expect(game.board.isEmpty, isTrue);
      // The suggested tiles are flagged for the rack animation.
      expect(game.suggestedIds, isNotEmpty);
      // The front of the rack now spells a valid dictionary word.
      final word = game.currentPlayer.rack
          .take(game.suggestedIds.length)
          .map((t) => t.letter)
          .join();
      expect(dict.isValidWord(word), isTrue, reason: '"$word" should be valid');
      // The rack still holds all seven tiles.
      expect(game.currentPlayer.rack.length, 7);
      expect(game.currentPlayer.rackIds.length, 7);
    });
  });

  group('movePending', () {
    test('relocates a pending tile to another empty cell', () {
      final game = _game(Dictionary()..loadWords(['CAT']));
      game.newGame();
      game.placeTile(0, 7, 7);
      expect(game.pendingTileAt(7, 7), isNotNull);

      game.movePending(7, 7, 7, 8);
      expect(game.pendingTileAt(7, 7), isNull);
      expect(game.pendingTileAt(7, 8), isNotNull);
    });

    test('will not move onto an occupied cell', () {
      final game = _game(Dictionary()..loadWords(['CAT']));
      game.newGame();
      game.placeTile(0, 7, 7);
      game.placeTile(1, 7, 8);
      game.movePending(7, 7, 7, 8); // target taken
      expect(game.pendingTileAt(7, 7), isNotNull);
    });
  });

  group('multiple computer opponents', () {
    test('builds one human and N computers', () {
      final game = _game(Dictionary()..loadWords(['CAT']));
      game.newGame(
        humanPlayers: 1,
        computerPlayers: 2,
        difficulty: AiDifficulty.easy,
      );
      expect(game.players.length, 3);
      expect(game.players[0].isAI, isFalse);
      expect(game.players[0].name, 'You');
      expect(game.players[1].isAI, isTrue);
      expect(game.players[2].isAI, isTrue);
      expect(game.players[1].name, 'Computer 1');
      expect(game.players[2].name, 'Computer 2');
      expect(game.vsComputer, isTrue);
    });
  });
}
