import 'tile.dart';

/// Bonus multiplier classification for a single board cell.
enum CellType {
  standard,
  doubleLetter,
  tripleLetter,
  doubleWord,
  tripleWord,
  center,
}

/// Dimension of the square board.
const int kBoardSize = 15;

/// A single cell holds its bonus [type] and an optional placed [tile].
class Cell {
  final CellType type;
  Tile? tile;

  Cell(this.type, {this.tile});

  bool get isEmpty => tile == null;

  int get letterMultiplier {
    switch (type) {
      case CellType.doubleLetter:
        return 2;
      case CellType.tripleLetter:
        return 3;
      default:
        return 1;
    }
  }

  int get wordMultiplier {
    switch (type) {
      case CellType.doubleWord:
      case CellType.center:
        return 2;
      case CellType.tripleWord:
        return 3;
      default:
        return 1;
    }
  }
}

/// The 15x15 game board. Premium-square layout matches the official Scrabble
/// board and is symmetric across both diagonals.
class GameBoard {
  final List<List<Cell>> grid;

  GameBoard() : grid = _buildGrid();

  static List<List<Cell>> _buildGrid() {
    return List.generate(
      kBoardSize,
      (r) => List.generate(kBoardSize, (c) => Cell(_premiumAt(r, c))),
    );
  }

  /// Returns true if (row, col) is on the board.
  static bool inBounds(int row, int col) =>
      row >= 0 && row < kBoardSize && col >= 0 && col < kBoardSize;

  Cell cellAt(int row, int col) => grid[row][col];

  Tile? tileAt(int row, int col) => grid[row][col].tile;

  bool isEmptyAt(int row, int col) => grid[row][col].isEmpty;

  /// True when the board has no tiles placed at all (first move).
  bool get isEmpty {
    for (final row in grid) {
      for (final cell in row) {
        if (!cell.isEmpty) return false;
      }
    }
    return true;
  }

  /// Premium classification for a coordinate, derived from the canonical
  /// Scrabble layout described as offsets from the top-left.
  static CellType _premiumAt(int r, int c) {
    if (r == 7 && c == 7) return CellType.center;

    const tripleWord = {
      [0, 0], [0, 7], [0, 14],
      [7, 0], [7, 14],
      [14, 0], [14, 7], [14, 14],
    };
    const doubleWord = {
      [1, 1], [2, 2], [3, 3], [4, 4],
      [1, 13], [2, 12], [3, 11], [4, 10],
      [13, 1], [12, 2], [11, 3], [10, 4],
      [13, 13], [12, 12], [11, 11], [10, 10],
    };
    const tripleLetter = {
      [1, 5], [1, 9],
      [5, 1], [5, 5], [5, 9], [5, 13],
      [9, 1], [9, 5], [9, 9], [9, 13],
      [13, 5], [13, 9],
    };
    const doubleLetter = {
      [0, 3], [0, 11],
      [2, 6], [2, 8],
      [3, 0], [3, 7], [3, 14],
      [6, 2], [6, 6], [6, 8], [6, 12],
      [7, 3], [7, 11],
      [8, 2], [8, 6], [8, 8], [8, 12],
      [11, 0], [11, 7], [11, 14],
      [12, 6], [12, 8],
      [14, 3], [14, 11],
    };

    bool contains(Set<List<int>> set) =>
        set.any((p) => p[0] == r && p[1] == c);

    if (contains(tripleWord)) return CellType.tripleWord;
    if (contains(doubleWord)) return CellType.doubleWord;
    if (contains(tripleLetter)) return CellType.tripleLetter;
    if (contains(doubleLetter)) return CellType.doubleLetter;
    return CellType.standard;
  }

  Map<String, dynamic> toJson() {
    final cells = <Map<String, dynamic>>[];
    for (var r = 0; r < kBoardSize; r++) {
      for (var c = 0; c < kBoardSize; c++) {
        final tile = grid[r][c].tile;
        if (tile != null) {
          cells.add({'r': r, 'c': c, 'tile': tile.toJson()});
        }
      }
    }
    return {'cells': cells};
  }

  /// Restores placed tiles from a serialized snapshot onto a fresh board.
  factory GameBoard.fromJson(Map<dynamic, dynamic> json) {
    final board = GameBoard();
    for (final raw in (json['cells'] as List)) {
      final cell = raw as Map;
      final r = cell['r'] as int;
      final c = cell['c'] as int;
      board.grid[r][c].tile = Tile.fromJson(cell['tile'] as Map);
    }
    return board;
  }
}
