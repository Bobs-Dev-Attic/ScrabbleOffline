import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrabble_offline/engine/ai_player.dart';
import 'package:scrabble_offline/engine/dictionary.dart';
import 'package:scrabble_offline/models/tile.dart';
import 'package:scrabble_offline/state/game_state.dart';
import 'package:scrabble_offline/state/persistence.dart';

/// In-memory persistence so the game loop can be tested without Hive.
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

void main() {
  test('computer takes its turn after the human, then hands control back', () {
    fakeAsync((async) {
      final dict = Dictionary()
        ..loadWords(File('assets/dictionary.txt').readAsLinesSync());
      final game =
          GameState(dictionary: dict, persistence: FakePersistence());

      game.newGame(
        humanPlayers: 1,
        computerPlayers: 1,
        difficulty: AiDifficulty.hard,
      );
      expect(game.currentPlayerIndex, 0, reason: 'human goes first');
      expect(game.isComputerTurn, isFalse);

      // Give the computer a word-rich rack so its move is deterministic.
      game.players[1].rack
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

      // Human passes -> control moves to the computer, which should be flagged
      // as thinking and have a turn scheduled.
      game.pass();
      expect(game.currentPlayerIndex, 1);
      expect(game.aiThinking, isTrue);

      // Let the scheduled AI turn fire.
      async.elapse(const Duration(seconds: 1));

      expect(game.aiThinking, isFalse);
      expect(game.currentPlayerIndex, 0,
          reason: 'control returns to the human after the AI resolves');
      // On an empty board with 7 tiles the AI almost always plays a word.
      expect(game.players[1].score, greaterThan(0));
      expect(game.board.isEmpty, isFalse);
    });
  });
}
