import 'package:flutter_test/flutter_test.dart';
import 'package:scrabble_offline/models/board.dart';
import 'package:scrabble_offline/models/player.dart';
import 'package:scrabble_offline/models/tile.dart';
import 'package:scrabble_offline/state/persistence.dart';

/// Builds a well-formed snapshot map like GamePersistence.save() would write.
Map<String, dynamic> _validSnapshot() {
  final board = GameBoard();
  board.grid[7][7].tile = const Tile(letter: 'C', value: 3);
  final players = [
    Player(name: 'You', score: 12, rack: const [
      Tile(letter: 'A', value: 1),
      Tile(letter: 'B', value: 3),
    ]),
    Player(name: 'CMP1', score: 5, isAI: true, rack: const [
      Tile(letter: 'E', value: 1),
    ]),
  ];
  return {
    'version': GamePersistence.schemaVersion,
    'board': board.toJson(),
    'players': players.map((p) => p.toJson()).toList(),
    'bag': const [
      Tile(letter: 'Z', value: 10),
      Tile.blank(),
    ].map((t) => t.toJson()).toList(),
    'current': 0,
  };
}

void main() {
  group('GamePersistence.parseSnapshot', () {
    test('parses a valid snapshot', () {
      final saved = GamePersistence.parseSnapshot(_validSnapshot());
      expect(saved.players.length, 2);
      expect(saved.players[0].name, 'You');
      expect(saved.players[0].rack.length, 2);
      expect(saved.currentPlayerIndex, 0);
      expect(saved.board.tileAt(7, 7)?.letter, 'C');
    });

    test('rejects an empty player list', () {
      final s = _validSnapshot()..['players'] = [];
      expect(() => GamePersistence.parseSnapshot(s), throwsA(anything));
    });

    test('rejects too many players', () {
      final one = _validSnapshot()['players'][0];
      final s = _validSnapshot()..['players'] = List.filled(7, one);
      expect(() => GamePersistence.parseSnapshot(s), throwsA(anything));
    });

    test('rejects a current index out of range', () {
      final s = _validSnapshot()..['current'] = 9;
      expect(() => GamePersistence.parseSnapshot(s), throwsA(anything));
    });

    test('rejects an oversized rack', () {
      final s = _validSnapshot();
      final players = List<Map<String, dynamic>>.from(
          (s['players'] as List).cast<Map<String, dynamic>>());
      players[0] = {
        ...players[0],
        'rack': List.generate(
            8, (_) => const Tile(letter: 'A', value: 1).toJson()),
      };
      s['players'] = players;
      expect(() => GamePersistence.parseSnapshot(s), throwsA(anything));
    });

    test('rejects out-of-bounds board cells', () {
      final s = _validSnapshot()
        ..['board'] = {
          'cells': [
            {'r': 99, 'c': 0, 'tile': const Tile(letter: 'A', value: 1).toJson()}
          ]
        };
      expect(() => GamePersistence.parseSnapshot(s), throwsA(anything));
    });

    test('rejects missing keys / wrong types', () {
      expect(() => GamePersistence.parseSnapshot({'version': 1}),
          throwsA(anything));
      expect(
          () => GamePersistence.parseSnapshot({
                'board': 'not a map',
                'players': [],
                'bag': [],
                'current': 0,
              }),
          throwsA(anything));
    });
  });
}
