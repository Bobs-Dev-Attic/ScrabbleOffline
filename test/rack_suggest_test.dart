import 'dart:io';

import 'package:fake_async/fake_async.dart';
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
    Map<String, int> tileOwners = const {},
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

  group('invalid move feedback', () {
    test('a rejected move bumps invalidSerial (drives the board shake)', () {
      final game = _game(Dictionary()..loadWords(['CAT']));
      game.newGame();
      game.currentPlayer.rack
        ..clear()
        ..addAll(const [
          Tile(letter: 'X', value: 8),
          Tile(letter: 'Z', value: 10),
        ]);
      game.placeTile(0, 7, 7);
      game.placeTile(1, 7, 8); // spells "XZ" across the center — not a word
      expect(game.invalidSerial, 0);

      final result = game.commitTurn();
      expect(result.valid, isFalse);
      expect(game.invalidSerial, 1, reason: 'shake trigger should advance');
      // Tiles stay pending so the player can fix them.
      expect(game.pending, isNotEmpty);
    });
  });

  group('mixRack', () {
    test('preserves the tiles and ids, and is a no-op while placing', () {
      final game = _game(Dictionary()..loadWords(['CAT']));
      game.newGame();
      final before = game.currentPlayer.rack.map((t) => t.letter).toList()
        ..sort();
      game.mixRack();
      final after = game.currentPlayer.rack.map((t) => t.letter).toList()
        ..sort();
      expect(after, before, reason: 'same multiset of letters after a mix');
      expect(game.currentPlayer.rack.length, 7);
      expect(game.currentPlayer.rackIds.length, 7);

      // Once a tile is pending, Mix is disabled (Recall is shown instead).
      game.placeTile(0, 7, 7);
      final racked = game.currentPlayer.rack.map((t) => t.letter).toList();
      game.mixRack();
      expect(game.currentPlayer.rack.map((t) => t.letter).toList(), racked,
          reason: 'mixRack is a no-op while a placement is in progress');
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

  group('suggest cycling and preview', () {
    test('repeated suggest cycles through different words', () {
      final dict = Dictionary()
        ..loadWords(File('assets/dictionary.txt').readAsLinesSync());
      final game = _game(dict);
      game.newGame();
      game.currentPlayer.rack
        ..clear()
        ..addAll(const [
          Tile(letter: 'C', value: 3),
          Tile(letter: 'A', value: 1),
          Tile(letter: 'R', value: 1),
          Tile(letter: 'E', value: 1),
          Tile(letter: 'S', value: 1),
          Tile(letter: 'T', value: 1),
          Tile(letter: 'O', value: 1),
        ]);
      game.currentPlayer.rackIds
        ..clear()
        ..addAll(List.generate(7, (i) => 2000 + i));

      // Press Suggest several times; it should place ghost tiles and cycle
      // through different spots/words.
      final seenPlacements = <String>{};
      for (var i = 0; i < 6; i++) {
        game.suggest();
        expect(game.ghosts, isNotEmpty, reason: 'ghost tiles should be shown');
        // No real tiles are placed on the board.
        expect(game.pending, isEmpty);
        final sig = (game.ghosts.entries
                .map((e) => '${e.key}:${e.value.letter}')
                .toList()
              ..sort())
            .join('|');
        seenPlacements.add(sig);
      }
      expect(seenPlacements.length, greaterThanOrEqualTo(3),
          reason: 'repeated Suggest should cycle through different placements');
    });

    test('previewMove reports a live score for a valid in-progress move', () {
      final dict = Dictionary()..loadWords(['CAT']);
      final game = _game(dict);
      game.newGame();
      game.currentPlayer.rack
        ..clear()
        ..addAll(const [
          Tile(letter: 'C', value: 3),
          Tile(letter: 'A', value: 1),
          Tile(letter: 'T', value: 1),
          Tile(letter: 'X', value: 8),
          Tile(letter: 'Y', value: 4),
          Tile(letter: 'Z', value: 10),
          Tile(letter: 'Q', value: 10),
        ]);

      expect(game.previewMove().valid, isFalse, reason: 'nothing placed yet');

      game.placeTile(0, 7, 6);
      game.placeTile(1, 7, 7);
      game.placeTile(2, 7, 8);
      final preview = game.previewMove();
      expect(preview.valid, isTrue);
      expect(preview.score, 10); // (3+1+1) x2 center
    });
  });

  group('ghost fade', () {
    test('placing a tile starts the ghost fade but keeps ghosts initially', () {
      final dict = Dictionary()
        ..loadWords(File('assets/dictionary.txt').readAsLinesSync());
      final game = _game(dict);
      game.newGame();
      game.currentPlayer.rack
        ..clear()
        ..addAll(const [
          Tile(letter: 'C', value: 3),
          Tile(letter: 'A', value: 1),
          Tile(letter: 'R', value: 1),
          Tile(letter: 'E', value: 1),
          Tile(letter: 'S', value: 1),
          Tile(letter: 'T', value: 1),
          Tile(letter: 'O', value: 1),
        ]);
      game.currentPlayer.rackIds
        ..clear()
        ..addAll(List.generate(7, (i) => 3000 + i));

      game.suggest();
      expect(game.ghosts, isNotEmpty);
      expect(game.ghostsFading, isFalse);

      game.placeTile(0, 0, 0);
      // Fade started, ghosts still present (they animate out, then clear).
      expect(game.ghostsFading, isTrue);
      expect(game.ghosts, isNotEmpty);

      // Recalling cancels the fade and clears ghosts immediately.
      game.recallAll();
      expect(game.ghostsFading, isFalse);
      expect(game.ghosts, isEmpty);
    });

    test('ghosts fade out on their own even if the player never places', () {
      fakeAsync((async) {
        final dict = Dictionary()
          ..loadWords(File('assets/dictionary.txt').readAsLinesSync());
        final game = _game(dict);
        game.newGame();
        game.currentPlayer.rack
          ..clear()
          ..addAll(const [
            Tile(letter: 'C', value: 3),
            Tile(letter: 'A', value: 1),
            Tile(letter: 'R', value: 1),
            Tile(letter: 'E', value: 1),
            Tile(letter: 'S', value: 1),
            Tile(letter: 'T', value: 1),
            Tile(letter: 'O', value: 1),
          ]);
        game.currentPlayer.rackIds
          ..clear()
          ..addAll(List.generate(7, (i) => 4000 + i));

        game.suggest();
        expect(game.ghosts, isNotEmpty);
        // Holds at full opacity briefly (not yet fading).
        expect(game.ghostsFading, isFalse);

        // After the short hold the fade begins automatically.
        async.elapse(const Duration(milliseconds: 600));
        expect(game.ghostsFading, isTrue);
        expect(game.ghosts, isNotEmpty);

        // Once the fade completes the ghosts are cleared — all within ~8-9s.
        async.elapse(const Duration(milliseconds: GameState.kGhostFadeMs + 100));
        expect(game.ghosts, isEmpty);
        expect(game.ghostsFading, isFalse);
      });
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
      expect(game.players[1].name, 'CMP1');
      expect(game.players[2].name, 'CMP2');
      expect(game.vsComputer, isTrue);
    });
  });
}
