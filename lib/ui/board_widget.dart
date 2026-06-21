import 'package:flutter/material.dart';

import '../models/board.dart';
import '../models/tile.dart';
import '../state/game_state.dart';
import 'game_theme.dart';
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
    final theme = GameThemeScope.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final dimension = constraints.biggest.shortestSide;
        final cellSize = dimension / kBoardSize;
        return Container(
          width: dimension,
          height: dimension,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: theme.boardFrame,
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
    final theme = GameThemeScope.of(context);
    final committed = game.board.tileAt(row, col);
    final pending = game.pendingTileAt(row, col);
    final cellType = game.board.cellAt(row, col).type;

    Widget content;
    if (committed != null) {
      final tileWidget = TileWidget(tile: committed, size: size);
      // Theme-gated pop-in when a tile lands on the board.
      content = theme.animated
          ? TweenAnimationBuilder<double>(
              key: ValueKey('$row,$col,${committed.letter}'),
              tween: Tween(begin: theme.flashy ? 0.4 : 0.7, end: 1.0),
              duration: Duration(milliseconds: theme.flashy ? 260 : 160),
              curve: theme.flashy ? Curves.elasticOut : Curves.easeOutBack,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: tileWidget,
            )
          : tileWidget;
    } else if (pending != null) {
      content = GestureDetector(
        onTap: () => onRecall(row, col),
        child: TileWidget(tile: pending, size: size, highlighted: true),
      );
    } else {
      content = _premiumLabel(theme, cellType, size);
    }

    return DragTarget<RackDragData>(
      onWillAcceptWithDetails: (_) =>
          committed == null &&
          pending == null &&
          !game.gameOver &&
          !game.isComputerTurn,
      onAcceptWithDetails: (details) =>
          onDropTile(details.data.rackIndex, row, col, details.data.tile),
      builder: (context, candidate, rejected) {
        final hovering = candidate.isNotEmpty;
        return Container(
          margin: const EdgeInsets.all(0.5),
          decoration: BoxDecoration(
            color: hovering ? theme.hover : _cellColor(theme, cellType),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Center(child: content),
        );
      },
    );
  }

  Widget _premiumLabel(GameTheme theme, CellType type, double size) {
    // The center uses a Material icon (bundled locally) rather than a unicode
    // star, which would otherwise trigger a symbol-font fetch from a CDN.
    if (type == CellType.center) {
      return FittedBox(
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Icon(Icons.star, color: theme.premiumText, size: size * 0.6),
        ),
      );
    }
    final label = switch (type) {
      CellType.tripleWord => 'TW',
      CellType.doubleWord => 'DW',
      CellType.tripleLetter => 'TL',
      CellType.doubleLetter => 'DL',
      CellType.center => '',
      CellType.standard => '',
    };
    if (label.isEmpty) return const SizedBox.shrink();
    return FittedBox(
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Text(
          label,
          style: TextStyle(
            color: theme.premiumText,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Color _cellColor(GameTheme theme, CellType type) {
    switch (type) {
      case CellType.tripleWord:
        return theme.cellTW;
      case CellType.doubleWord:
        return theme.cellDW;
      case CellType.tripleLetter:
        return theme.cellTL;
      case CellType.doubleLetter:
        return theme.cellDL;
      case CellType.center:
        return theme.cellCenter;
      case CellType.standard:
        return theme.cellStandard;
    }
  }
}

/// Payload carried by a dragged rack tile.
class RackDragData {
  final int rackIndex;
  final Tile tile;
  const RackDragData(this.rackIndex, this.tile);
}
