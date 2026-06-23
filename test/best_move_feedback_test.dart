import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrabble_offline/engine/dictionary.dart';
import 'package:scrabble_offline/models/tile.dart';
import 'package:scrabble_offline/state/game_state.dart';
import 'package:scrabble_offline/state/persistence.dart';

class _FakePersistence extends GamePersistence {
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
    GameState(dictionary: dict, persistence: _FakePersistence());

void _setRack(GameState game, List<Tile> tiles) {
  game.currentPlayer.rack
    ..clear()
    ..addAll(tiles);
  game.currentPlayer.rackIds
    ..clear()
    ..addAll(List.generate(tiles.length, (i) => 100 + i));
}

void main() {
  group('best-move feedback', () {
    test('a perfect play triggers a celebration and advances', () {
      final game = _game(Dictionary()..loadWords(['AB']));
      game.newGame(); // 2 humans, no AI
      game.bestMoveFeedbackEnabled = true;
      _setRack(game, const [Tile(letter: 'A', value: 1), Tile(letter: 'B', value: 3)]);

      game.placeTile(0, 7, 7);
      game.placeTile(1, 7, 8); // "AB" across the center
      final r = game.commitTurn();

      expect(r.valid, isTrue);
      expect(game.celebrateSerial, 1, reason: 'best play celebrates');
      expect(game.reviewingPotential, isFalse);
      expect(game.currentPlayerIndex, 1, reason: 'turn advances');
    });

    test('using Suggest suppresses the celebration', () {
      final game = _game(Dictionary()..loadWords(['AB']));
      game.newGame();
      game.bestMoveFeedbackEnabled = true;
      _setRack(game, const [Tile(letter: 'A', value: 1), Tile(letter: 'B', value: 3)]);

      game.suggest(); // marks the turn as "helped"
      game.placeTile(0, 7, 7);
      game.placeTile(1, 7, 8);
      final r = game.commitTurn();

      expect(r.valid, isTrue);
      expect(game.celebrateSerial, 0, reason: 'no celebration after Suggest');
    });

    test('a sub-optimal play shows the best move, then hands off', () {
      fakeAsync((async) {
        final game = _game(Dictionary()..loadWords(['AB', 'ABC']));
        game.newGame();
        game.bestMoveFeedbackEnabled = true;
        _setRack(game, const [
          Tile(letter: 'A', value: 1),
          Tile(letter: 'B', value: 3),
          Tile(letter: 'C', value: 3),
        ]);

        game.placeTile(0, 7, 7);
        game.placeTile(1, 7, 8); // plays "AB" (8) when "ABC" (14) was possible
        final r = game.commitTurn();

        expect(r.valid, isTrue);
        expect(game.reviewingPotential, isTrue);
        expect(game.ghosts, isNotEmpty, reason: 'best placement shown as ghosts');
        expect(game.reviewPotential, 14);
        expect(game.reviewWord, 'ABC', reason: 'shows the missed word');
        expect(game.currentPlayerIndex, 0, reason: 'turn deferred during review');

        async.elapse(const Duration(seconds: 8));
        expect(game.reviewingPotential, isFalse);
        expect(game.ghosts, isEmpty);
        expect(game.reviewWord, '');
        expect(game.currentPlayerIndex, 1, reason: 'turn advances after review');
      });
    });

    test('feature off: no celebration or review', () {
      final game = _game(Dictionary()..loadWords(['AB', 'ABC']));
      game.newGame();
      game.bestMoveFeedbackEnabled = false;
      _setRack(game, const [
        Tile(letter: 'A', value: 1),
        Tile(letter: 'B', value: 3),
        Tile(letter: 'C', value: 3),
      ]);

      game.placeTile(0, 7, 7);
      game.placeTile(1, 7, 8);
      final r = game.commitTurn();

      expect(r.valid, isTrue);
      expect(game.celebrateSerial, 0);
      expect(game.reviewingPotential, isFalse);
      expect(game.currentPlayerIndex, 1);
    });
  });

  group('win celebration', () {
    test('tiles record their owner; a human win celebrates & highlights', () {
      final game = _game(Dictionary()..loadWords(['AB']));
      game.newGame(); // 2 humans
      game.bestMoveFeedbackEnabled = false; // isolate the win celebration
      // Empty the bag so finishing the rack ends the game.
      while (!game.bag.isEmpty) {
        game.bag.draw(100);
      }
      _setRack(game, const [Tile(letter: 'A', value: 1), Tile(letter: 'B', value: 3)]);

      game.placeTile(0, 7, 7);
      game.placeTile(1, 7, 8);
      final r = game.commitTurn();

      expect(r.valid, isTrue);
      expect(game.gameOver, isTrue);
      expect(game.winnerIndex, 0);
      expect(game.celebrateWin, isTrue);
      expect(game.celebrateSerial, greaterThan(0), reason: 'confetti fires');
      expect(game.tileOwners['7,7'], 0);
      expect(game.tileOwners['7,8'], 0);
    });
  });
}
