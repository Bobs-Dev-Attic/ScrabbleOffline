// lib/state/persistence.dart —
//
// Hive-backed save/load of the board, players, and bag (the offline persistence layer).
//
// See docs/DESIGN.md for how this fits the overall architecture.

import 'package:hive_flutter/hive_flutter.dart';

import '../models/board.dart';
import '../models/player.dart';
import '../models/tile.dart';
import '../models/tile_bag.dart';

/// Lightweight, zero-native-binary persistence layer backed by Hive.
///
/// The entire game is serialized to a single box under three keys, matching the
/// schema described in CLAUDE.md.
class GamePersistence {
  static const String boxName = 'scrabble_game_state';
  static const String keyBoard = 'board_matrix';
  static const String keyPlayers = 'player_pool';
  static const String keyBag = 'bag_state';
  static const String keyMeta = 'meta';

  late Box _box;

  /// Initializes Hive for the web platform and opens the game box.
  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(boxName);
  }

  bool get hasSavedGame => _box.containsKey(keyBoard);

  /// Persists a full snapshot of the game. Invoked after every valid turn.
  Future<void> save({
    required GameBoard board,
    required List<Player> players,
    required TileBag bag,
    required int currentPlayerIndex,
  }) async {
    await _box.put(keyBoard, board.toJson());
    await _box.put(
      keyPlayers,
      players.map((p) => p.toJson()).toList(),
    );
    await _box.put(
      keyBag,
      bag.tiles.map((t) => t.toJson()).toList(),
    );
    await _box.put(keyMeta, {'current': currentPlayerIndex});
  }

  /// Loads a previously saved game, or null if none exists.
  SavedGame? load() {
    if (!hasSavedGame) return null;
    final board = GameBoard.fromJson(
      Map<dynamic, dynamic>.from(_box.get(keyBoard) as Map),
    );
    final players = (_box.get(keyPlayers) as List)
        .map((e) => Player.fromJson(Map<dynamic, dynamic>.from(e as Map)))
        .toList();
    final tiles = (_box.get(keyBag) as List)
        .map((e) => Tile.fromJson(Map<dynamic, dynamic>.from(e as Map)))
        .toList();
    final meta = Map<dynamic, dynamic>.from(
        _box.get(keyMeta, defaultValue: {'current': 0}) as Map);
    return SavedGame(
      board: board,
      players: players,
      bag: TileBag.fromTiles(tiles),
      currentPlayerIndex: meta['current'] as int,
    );
  }

  Future<void> clear() async {
    await _box.clear();
  }
}

/// Container for a deserialized game snapshot.
class SavedGame {
  final GameBoard board;
  final List<Player> players;
  final TileBag bag;
  final int currentPlayerIndex;

  SavedGame({
    required this.board,
    required this.players,
    required this.bag,
    required this.currentPlayerIndex,
  });
}
