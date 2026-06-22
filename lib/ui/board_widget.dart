// lib/ui/board_widget.dart —
//
// Renders the 15x15 grid plus committed, pending, and ghost tiles, and hosts the
// drag targets for placing/moving tiles.
//
// See docs/DESIGN.md for how this fits the overall architecture.

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
        final richFrame = theme.richDecoration;
        return Container(
          width: dimension,
          height: dimension,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: richFrame ? null : theme.boardFrame,
            gradient: richFrame
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(theme.boardFrame, Colors.white, 0.14)!,
                      theme.boardFrame,
                      Color.lerp(theme.boardFrame, Colors.black, 0.22)!,
                    ],
                  )
                : null,
            borderRadius: BorderRadius.circular(8),
            boxShadow: richFrame
                ? const [
                    BoxShadow(
                      color: Color(0x59000000),
                      blurRadius: 18,
                      offset: Offset(0, 7),
                    ),
                  ]
                : null,
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
      final cellKey = '$row,$col';
      final fresh = game.lastPlaced.contains(cellKey);
      // Tiles from the most recent move drop in, staggered along the word.
      content = (theme.animated && fresh)
          ? _DropInTile(
              key: ValueKey('drop-${game.moveSerial}-$cellKey'),
              order: game.lastPlacedOrder[cellKey] ?? 0,
              flashy: theme.flashy,
              size: size,
              child: tileWidget,
            )
          : tileWidget;
    } else if (pending != null) {
      // Pending tiles can be dragged to another cell to adjust placement, or
      // tapped to recall them to the rack.
      content = Draggable<BoardDragData>(
        data: BoardDragData(row, col),
        feedback: Material(
          color: Colors.transparent,
          child: GameThemeScope(
            theme: theme,
            child: TileWidget(tile: pending, size: size * 1.12, highlighted: true),
          ),
        ),
        childWhenDragging: _premiumLabel(theme, cellType, size),
        child: GestureDetector(
          onTap: () => onRecall(row, col),
          child: TileWidget(tile: pending, size: size, highlighted: true),
        ),
      );
    } else {
      // Ghost tile: a translucent hint showing where the current Suggest
      // result would be placed. Once the player starts placing, it fades out.
      final ghost = game.ghostAt(row, col);
      content = ghost != null
          ? AnimatedOpacity(
              opacity: game.ghostsFading ? 0.0 : 0.45,
              duration: Duration(
                  milliseconds:
                      game.ghostsFading ? GameState.kGhostFadeMs : 0),
              curve: Curves.easeInOut,
              child: TileWidget(tile: ghost, size: size, highlighted: true),
            )
          : _premiumLabel(theme, cellType, size);
    }

    return DragTarget<Object>(
      onWillAcceptWithDetails: (details) {
        if (committed != null || pending != null) return false;
        if (game.gameOver || game.isComputerTurn) return false;
        final d = details.data;
        return d is RackDragData || d is BoardDragData;
      },
      onAcceptWithDetails: (details) {
        final d = details.data;
        if (d is RackDragData) {
          onDropTile(d.rackIndex, row, col, d.tile);
        } else if (d is BoardDragData) {
          game.movePending(d.row, d.col, row, col);
        }
      },
      builder: (context, candidate, rejected) {
        final hovering = candidate.isNotEmpty;
        final base = hovering ? theme.hover : _cellColor(theme, cellType);
        // A subtle top-light → bottom-dark gradient gives each cell a little
        // depth so the board reads as tactile rather than flat.
        return Container(
          margin: const EdgeInsets.all(0.5),
          decoration: BoxDecoration(
            color: theme.richDecoration ? null : base,
            gradient: theme.richDecoration
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.lerp(base, Colors.white, 0.14)!,
                      base,
                      Color.lerp(base, Colors.black, 0.12)!,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  )
                : null,
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

/// Payload carried when dragging an already-placed pending tile on the board.
class BoardDragData {
  final int row;
  final int col;
  const BoardDragData(this.row, this.col);
}

/// Animates a freshly placed tile dropping onto the board. [order] staggers
/// tiles along the word so they land one after another.
class _DropInTile extends StatelessWidget {
  final int order;
  final bool flashy;
  final double size;
  final Widget child;

  const _DropInTile({
    super.key,
    required this.order,
    required this.flashy,
    required this.size,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final start = (order * 0.1).clamp(0.0, 0.6);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 460),
      curve: Interval(start, 1.0,
          curve: flashy ? Curves.elasticOut : Curves.easeOutBack),
      builder: (context, t, child) {
        final scale = 0.5 + 0.5 * t;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, -size * 0.45 * (1 - t)),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: child,
    );
  }
}
