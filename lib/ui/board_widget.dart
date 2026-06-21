import 'package:flutter/material.dart';

import '../models/board.dart';
import '../models/tile.dart';
import '../state/game_state.dart';
import 'tile_widget.dart';

/// Renders the 15x15 board, committed and pending tiles, and drag targets.
class BoardWidget extends StatelessWidget {
  final GameState game;

  /// Called when a rack tile is dropped on an empty cell. Args: rackIndex,
  /// row, col, and the (possibly blank-assigned) tile.
  final void Function(int rackIndex, int row, int col, Tile tile) onDropTile;

  /// Called when a pending tile is tapped to recall it to the rack.
  final void Function(int row, int col) onRecall;

  const BoardWidget({
    super.key,
    required this.game,
    required this.onDropTile,
    required this.onRecall,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dimension = constraints.biggest.shortestSide;
        final cellSize = dimension / kBoardSize;
        return Container(
          width: dimension,
          height: dimension,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: const Color(0xFF1B5E20),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            children: [
              for (var r = 0; r < kBoardSize; r++)
                Expanded(
                  child: Row(
                    children: [
                      for (var c = 0; c < kBoardSize; c++)
                        Expanded(
                          child: _buildCell(context, r, c, cellSize),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCell(BuildContext context, int row, int col, double size) {
    final committed = game.board.tileAt(row, col);
    final pending = game.pendingTileAt(row, col);
    final cellType = game.board.cellAt(row, col).type;

    Widget content;
    if (committed != null) {
      content = TileWidget(tile: committed, size: size);
    } else if (pending != null) {
      content = GestureDetector(
        onTap: () => onRecall(row, col),
        child: TileWidget(tile: pending, size: size, highlighted: true),
      );
    } else {
      content = _premiumLabel(cellType, size);
    }

    return DragTarget<RackDragData>(
      onWillAcceptWithDetails: (_) =>
          committed == null && pending == null && !game.gameOver,
      onAcceptWithDetails: (details) =>
          onDropTile(details.data.rackIndex, row, col, details.data.tile),
      builder: (context, candidate, rejected) {
        final hovering = candidate.isNotEmpty;
        return Container(
          margin: const EdgeInsets.all(0.5),
          decoration: BoxDecoration(
            color: hovering
                ? Colors.yellow.withValues(alpha: 0.5)
                : _cellColor(cellType),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Center(child: content),
        );
      },
    );
  }

  Widget _premiumLabel(CellType type, double size) {
    final label = switch (type) {
      CellType.tripleWord => 'TW',
      CellType.doubleWord => 'DW',
      CellType.tripleLetter => 'TL',
      CellType.doubleLetter => 'DL',
      CellType.center => '★',
      CellType.standard => '',
    };
    if (label.isEmpty) return const SizedBox.shrink();
    return FittedBox(
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Color _cellColor(CellType type) {
    switch (type) {
      case CellType.tripleWord:
        return const Color(0xFFD32F2F);
      case CellType.doubleWord:
        return const Color(0xFFEF9A9A);
      case CellType.tripleLetter:
        return const Color(0xFF1976D2);
      case CellType.doubleLetter:
        return const Color(0xFF90CAF9);
      case CellType.center:
        return const Color(0xFFEF9A9A);
      case CellType.standard:
        return const Color(0xFF2E7D32);
    }
  }
}

/// Payload carried by a dragged rack tile.
class RackDragData {
  final int rackIndex;
  final Tile tile;
  const RackDragData(this.rackIndex, this.tile);
}
