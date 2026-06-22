// lib/models/player.dart —
//
// Player profile: score, the rack (with stable per-tile ids for animation), and the
// isAI flag for pass-and-play / bot seats.
//
// See docs/DESIGN.md for how this fits the overall architecture.

import 'tile.dart';

/// Maximum number of tiles a player may hold on their rack.
const int kRackCapacity = 7;

/// Monotonic id source giving each physical rack tile a stable identity so the
/// UI can animate reordering. Ids are ephemeral (not persisted).
int _rackTileIdSeq = 0;
int _newTileId() => _rackTileIdSeq++;

/// A player profile tracking score, rack, and whether the seat is AI driven.
class Player {
  final String name;
  int score;
  final List<Tile> rack;
  final bool isAI;

  /// Stable per-tile ids, parallel to [rack], used for reorder animations.
  final List<int> rackIds = [];

  Player({
    required this.name,
    this.score = 0,
    List<Tile>? rack,
    this.isAI = false,
  }) : rack = rack ?? <Tile>[] {
    for (var i = 0; i < this.rack.length; i++) {
      rackIds.add(_newTileId());
    }
  }

  /// Draws tiles from [supplier] until the rack is full (or the supplier is
  /// exhausted). [supplier] returns up to the requested number of tiles.
  void refill(List<Tile> Function(int count) supplier) {
    final needed = kRackCapacity - rack.length;
    if (needed <= 0) return;
    final drawn = supplier(needed);
    for (final t in drawn) {
      rack.add(t);
      rackIds.add(_newTileId());
    }
  }

  /// Removes the rack tile (and its id) at [index].
  void removeRackAt(int index) {
    rack.removeAt(index);
    rackIds.removeAt(index);
  }

  /// Removes [tiles] from the rack by identity-ish matching (letter + blank
  /// status). Returns true if every requested tile was found and removed.
  bool removeFromRack(List<Tile> tiles) {
    final working = List<Tile>.from(rack);
    final toRemove = <int>[];
    for (final tile in tiles) {
      final idx = _findRackIndex(working, tile, toRemove);
      if (idx == -1) return false;
      toRemove.add(idx);
    }
    toRemove.sort((a, b) => b.compareTo(a));
    for (final idx in toRemove) {
      removeRackAt(idx);
    }
    return true;
  }

  int _findRackIndex(List<Tile> source, Tile target, List<int> used) {
    for (var i = 0; i < source.length; i++) {
      if (used.contains(i)) continue;
      final t = source[i];
      // A placed blank matches any rack blank regardless of assigned letter.
      if (target.isBlank && t.isBlank) return i;
      if (!target.isBlank && !t.isBlank && t.letter == target.letter) return i;
    }
    return -1;
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'score': score,
        'isAI': isAI,
        'rack': rack.map((t) => t.toJson()).toList(),
      };

  factory Player.fromJson(Map<dynamic, dynamic> json) => Player(
        name: json['name'] as String,
        score: json['score'] as int,
        isAI: json['isAI'] as bool? ?? false,
        rack: (json['rack'] as List)
            .map((e) => Tile.fromJson(e as Map))
            .toList(),
      );
}
