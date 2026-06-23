import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scrabble_offline/engine/dictionary.dart';
import 'package:scrabble_offline/engine/move_generator.dart';
import 'package:scrabble_offline/engine/remote_game.dart';
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

List<String> _letters(List rack) =>
    rack.map<String>((t) => t.isBlank ? '_${t.letter}' : '${t.letter}').toList()
      ..sort();

/// Places a generated move's tiles onto [g]'s board as pending.
void _placeMove(GameState g, GeneratedMove m) {
  final used = <int>{};
  for (final p in m.placements) {
    var idx = -1;
    for (var i = 0; i < g.currentPlayer.rack.length; i++) {
      if (used.contains(i)) continue;
      final t = g.currentPlayer.rack[i];
      if (p.tile.isBlank && t.isBlank) {
        idx = i;
        break;
      }
      if (!p.tile.isBlank && !t.isBlank && t.letter == p.tile.letter) {
        idx = i;
        break;
      }
    }
    used.add(idx);
    g.placeTile(idx, p.row, p.col, tile: p.tile);
  }
}

void main() {
  group('RemoteGameCode', () {
    test('encodes and decodes round-trip', () {
      final code = RemoteGameCode(seed: 12345, names: ['Ann', 'Bo'], moves: [
        const RemoteMove.play([
          [7, 7, 'C', 0],
          [7, 8, 'A', 0],
          [7, 9, 'T', 0],
        ]),
        const RemoteMove.pass(),
      ]);
      final back = RemoteGameCode.decode(code.encode())!;
      expect(back.seed, 12345);
      expect(back.names, ['Ann', 'Bo']);
      expect(back.moves.length, 2);
      expect(back.moves[0].type, 'play');
      expect(back.moves[0].placements[0][2], 'C');
      expect(back.moves[1].type, 'pass');
    });

    test('rejects garbage codes', () {
      expect(RemoteGameCode.decode('not a real code'), isNull);
      expect(RemoteGameCode.decode(''), isNull);
    });
  });

  group('two-device sync', () {
    late Dictionary dict;
    setUpAll(() {
      dict = Dictionary()
        ..loadWords(File('assets/dictionary.txt').readAsLinesSync());
    });

    test('both devices deal identical racks from a shared code', () {
      final a = _game(dict)..createRemoteGame(youName: 'A', friendName: 'B');
      final b = _game(dict);
      final err = b.joinRemoteGame(a.remoteShareCode()!);

      expect(err, isNull);
      expect(b.localSeat, 1);
      expect(a.localSeat, 0);
      expect(_letters(a.players[0].rack), _letters(b.players[0].rack));
      expect(_letters(a.players[1].rack), _letters(b.players[1].rack));
      expect(a.currentPlayerIndex, 0);
      expect(b.currentPlayerIndex, 0, reason: "creator's turn first");
    });

    test('a move made on one device replays identically on the other', () {
      final a = _game(dict)..createRemoteGame(youName: 'A', friendName: 'B');
      a.bestMoveFeedbackEnabled = false; // avoid the deferred review
      final b = _game(dict)..joinRemoteGame(a.remoteShareCode()!);

      // A plays a legal first move drawn from its dealt rack.
      final gen = a.ai.generator.generate(a.board, a.players[0].rack);
      expect(gen, isNotEmpty);
      _placeMove(a, gen.first);
      final result = a.commitTurn();
      expect(result.valid, isTrue);
      expect(a.currentPlayerIndex, 1, reason: 'turn passes to B');

      // B applies A's shared code.
      final err = b.applyRemoteCode(a.remoteShareCode()!);
      expect(err, isNull);

      // The two devices now agree on everything.
      expect(b.currentPlayerIndex, 1);
      expect(b.players[0].score, a.players[0].score);
      for (var r = 0; r < 15; r++) {
        for (var c = 0; c < 15; c++) {
          expect(b.board.tileAt(r, c)?.letter, a.board.tileAt(r, c)?.letter,
              reason: 'cell $r,$c should match');
        }
      }
      expect(_letters(a.players[0].rack), _letters(b.players[0].rack));
      expect(_letters(a.players[1].rack), _letters(b.players[1].rack));
    });

    test('applying a stale code is rejected', () {
      final a = _game(dict)..createRemoteGame(youName: 'A', friendName: 'B');
      final b = _game(dict)..joinRemoteGame(a.remoteShareCode()!);
      // No new moves since join.
      expect(b.applyRemoteCode(a.remoteShareCode()!),
          'No new moves in that code yet.');
    });
  });
}
