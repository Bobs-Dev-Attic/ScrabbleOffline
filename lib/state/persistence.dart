// lib/state/persistence.dart —
//
// Hive-backed save/load of the board, players, and bag (the offline persistence layer).
//
// See docs/DESIGN.md for how this fits the overall architecture.

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/board.dart';
import '../models/player.dart';
import '../models/tile.dart';
import '../models/tile_bag.dart';

/// Lightweight, zero-native-binary persistence layer backed by Hive.
///
/// The entire game is serialized to a single versioned snapshot under one key.
/// Writing one object (rather than several independent keys) keeps saves
/// effectively atomic: a crash or quota failure can't leave a half-written
/// mixture of old and new state. [load] is defensive — any corrupt, stale, or
/// tampered snapshot is detected, discarded, and reported via [lastLoadError]
/// instead of crashing the app on startup or "Continue".
class GamePersistence {
  static const String boxName = 'scrabble_game_state';

  /// Current snapshot schema version. Bump when the serialized shape changes.
  static const int schemaVersion = 1;

  /// Single snapshot key (atomic write target).
  static const String keySnapshot = 'snapshot';

  // Legacy multi-key format (pre-1.9). Still read so existing saves migrate.
  static const String keyBoard = 'board_matrix';
  static const String keyPlayers = 'player_pool';
  static const String keyBag = 'bag_state';
  static const String keyMeta = 'meta';

  /// Sane upper bound on players (1 human + up to 3 computers, with headroom).
  static const int _maxPlayers = 6;

  late Box _box;

  /// Set when [load] discards a corrupt snapshot, so the UI can show a friendly
  /// "your saved game was reset" message. Cleared on a successful load.
  String? lastLoadError;

  /// Initializes Hive for the web platform and opens the game box.
  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(boxName);
  }

  bool get hasSavedGame =>
      _box.containsKey(keySnapshot) || _box.containsKey(keyBoard);

  /// Persists a full snapshot of the game. Invoked after every valid turn.
  ///
  /// The snapshot is fully serialized in memory first, then written under a
  /// single key in one `put` — so the stored state is always a complete,
  /// self-consistent snapshot, never a partial blend of two games.
  Future<void> save({
    required GameBoard board,
    required List<Player> players,
    required TileBag bag,
    required int currentPlayerIndex,
  }) async {
    final snapshot = <String, dynamic>{
      'version': schemaVersion,
      'board': board.toJson(),
      'players': players.map((p) => p.toJson()).toList(),
      'bag': bag.tiles.map((t) => t.toJson()).toList(),
      'current': currentPlayerIndex,
    };
    await _box.put(keySnapshot, snapshot);
    // Drop the legacy keys once we've written the new format.
    if (_box.containsKey(keyBoard)) {
      await _box.delete(keyBoard);
      await _box.delete(keyPlayers);
      await _box.delete(keyBag);
      await _box.delete(keyMeta);
    }
  }

  /// Loads a previously saved game. Returns null when there is no save, or when
  /// the stored data is missing/corrupt/out of bounds — in which case the bad
  /// data is cleared and [lastLoadError] is set so the app can recover cleanly
  /// instead of throwing.
  SavedGame? load() {
    lastLoadError = null;
    if (!hasSavedGame) return null;
    try {
      final Map<dynamic, dynamic> raw = _box.containsKey(keySnapshot)
          ? Map<dynamic, dynamic>.from(_box.get(keySnapshot) as Map)
          : _legacyToSnapshot();
      return parseSnapshot(raw);
    } catch (e) {
      // Corrupt/stale/tampered state: discard it and recover gracefully.
      debugPrint('GamePersistence.load: discarding bad save: $e');
      lastLoadError =
          'Your saved game could not be read and has been reset.';
      try {
        _box.clear();
      } catch (_) {}
      return null;
    }
  }

  /// Assembles a snapshot map from the legacy multi-key layout.
  Map<dynamic, dynamic> _legacyToSnapshot() => {
        'version': 0,
        'board': _box.get(keyBoard),
        'players': _box.get(keyPlayers),
        'bag': _box.get(keyBag),
        'current': Map<dynamic, dynamic>.from(
            _box.get(keyMeta, defaultValue: {'current': 0}) as Map)['current'],
      };

  /// Parses and bounds-checks a snapshot map. Throws on anything invalid
  /// (missing keys, wrong types, out-of-range board cells / player count /
  /// rack size / current index). Exposed for testing with malformed payloads.
  @visibleForTesting
  static SavedGame parseSnapshot(Map<dynamic, dynamic> raw) {
    final board = GameBoard.fromJson(
      Map<dynamic, dynamic>.from(raw['board'] as Map),
    );

    final playersRaw = raw['players'] as List;
    if (playersRaw.isEmpty || playersRaw.length > _maxPlayers) {
      throw FormatException('player count ${playersRaw.length} out of range');
    }
    final players = playersRaw
        .map((e) => Player.fromJson(Map<dynamic, dynamic>.from(e as Map)))
        .toList();
    for (final p in players) {
      if (p.rack.length > kRackCapacity) {
        throw FormatException('rack of ${p.rack.length} exceeds $kRackCapacity');
      }
      if (p.score < 0) throw const FormatException('negative score');
    }

    final tiles = (raw['bag'] as List)
        .map((e) => Tile.fromJson(Map<dynamic, dynamic>.from(e as Map)))
        .toList();

    final current = raw['current'] as int;
    if (current < 0 || current >= players.length) {
      throw FormatException('currentPlayerIndex $current out of range');
    }

    return SavedGame(
      board: board,
      players: players,
      bag: TileBag.fromTiles(tiles),
      currentPlayerIndex: current,
    );
  }

  Future<void> clear() async {
    lastLoadError = null;
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
