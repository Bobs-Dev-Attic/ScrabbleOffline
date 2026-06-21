import 'dart:math';

import 'tile.dart';

/// The standard English Scrabble tile distribution: letter -> [count, value].
const Map<String, List<int>> kStandardDistribution = {
  'A': [9, 1],
  'B': [2, 3],
  'C': [2, 3],
  'D': [4, 2],
  'E': [12, 1],
  'F': [2, 4],
  'G': [3, 2],
  'H': [2, 4],
  'I': [9, 1],
  'J': [1, 8],
  'K': [1, 5],
  'L': [4, 1],
  'M': [2, 3],
  'N': [6, 1],
  'O': [8, 1],
  'P': [2, 3],
  'Q': [1, 10],
  'R': [6, 1],
  'S': [4, 1],
  'T': [6, 1],
  'U': [4, 1],
  'V': [2, 4],
  'W': [2, 4],
  'X': [1, 8],
  'Y': [2, 4],
  'Z': [1, 10],
};

/// Number of blank tiles in a standard set.
const int kBlankCount = 2;

/// Point value lookup for a single letter, used when assigning blanks etc.
int letterValue(String letter) {
  final entry = kStandardDistribution[letter.toUpperCase()];
  return entry == null ? 0 : entry[1];
}

/// Holds the remaining draw pool of 100 tiles and shuffles them locally using
/// the Fisher-Yates algorithm.
class TileBag {
  final List<Tile> _tiles = [];
  final Random _random;

  TileBag({Random? random}) : _random = random ?? Random() {
    _fill();
    shuffle();
  }

  /// Restores a bag from a previously serialized list of tiles.
  TileBag.fromTiles(List<Tile> tiles, {Random? random})
      : _random = random ?? Random() {
    _tiles.addAll(tiles);
  }

  void _fill() {
    kStandardDistribution.forEach((letter, data) {
      final count = data[0];
      final value = data[1];
      for (var i = 0; i < count; i++) {
        _tiles.add(Tile(letter: letter, value: value));
      }
    });
    for (var i = 0; i < kBlankCount; i++) {
      _tiles.add(const Tile.blank());
    }
  }

  /// Fisher-Yates in-place shuffle.
  void shuffle() {
    for (var i = _tiles.length - 1; i > 0; i--) {
      final j = _random.nextInt(i + 1);
      final tmp = _tiles[i];
      _tiles[i] = _tiles[j];
      _tiles[j] = tmp;
    }
  }

  int get remaining => _tiles.length;

  bool get isEmpty => _tiles.isEmpty;

  /// Draws up to [count] tiles from the bag, returning fewer if the bag runs
  /// low.
  List<Tile> draw(int count) {
    final drawn = <Tile>[];
    for (var i = 0; i < count && _tiles.isNotEmpty; i++) {
      drawn.add(_tiles.removeLast());
    }
    return drawn;
  }

  /// Returns [tiles] to the bag and reshuffles. Used by the exchange action.
  /// Blanks are restored to their unassigned state.
  void returnTiles(List<Tile> tiles) {
    for (final tile in tiles) {
      _tiles.add(tile.isBlank ? const Tile.blank() : tile);
    }
    shuffle();
  }

  /// Immutable snapshot of the remaining tiles for serialization.
  List<Tile> get tiles => List.unmodifiable(_tiles);
}
