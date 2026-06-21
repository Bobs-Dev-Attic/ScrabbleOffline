import 'dart:math';

import 'package:flutter/material.dart';

import '../models/tile.dart';
import '../state/game_state.dart';
import 'board_widget.dart';
import 'game_theme.dart';
import 'tile_widget.dart';

/// The current player's rack, rendered as animated, repositionable tiles.
/// Tiles can be dragged onto the board, dragged onto each other to reorder, or
/// tapped to select for exchange. Reordering (incl. from Suggest) slides tiles
/// to their new spots, and suggested tiles briefly enlarge.
class RackWidget extends StatelessWidget {
  final GameState game;
  final void Function(int rackIndex) onExchangeToggle;
  final Set<int> selectedForExchange;
  final bool exchangeMode;

  const RackWidget({
    super.key,
    required this.game,
    required this.onExchangeToggle,
    required this.selectedForExchange,
    this.exchangeMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final tiles = game.availableRackTiles;
    final theme = GameThemeScope.of(context);

    // Dropping a pending board tile onto the rack recalls it.
    return DragTarget<Object>(
      onWillAcceptWithDetails: (d) => d.data is BoardDragData,
      onAcceptWithDetails: (d) {
        final data = d.data;
        if (data is BoardDragData) game.recallTile(data.row, data.col);
      },
      builder: (context, candidate, rejected) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: theme.rack,
        borderRadius: BorderRadius.circular(8),
        boxShadow: theme.richDecoration
            ? const [
                BoxShadow(
                    color: Color(0x44000000), blurRadius: 4, offset: Offset(0, 2)),
              ]
            : null,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth;
          final slot = maxW / 7;
          final gap = (slot * 0.14).clamp(3.0, 7.0);
          final size = (slot - gap).clamp(20.0, 52.0);
          final n = tiles.length;
          final groupW = n * size + (n - 1) * gap;
          final startX = max(0.0, (maxW - groupW) / 2);

          return SizedBox(
            height: size,
            width: maxW,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (var i = 0; i < n; i++)
                  _positioned(theme, tiles[i], i, startX, size, gap),
              ],
            ),
          );
        },
      ),
      ),
    );
  }

  Widget _positioned(
    GameTheme theme,
    MapEntry<int, Tile> entry,
    int displayIndex,
    double startX,
    double size,
    double gap,
  ) {
    final rackIndex = entry.key;
    final id = game.currentPlayer.rackIds[rackIndex];
    final left = startX + displayIndex * (size + gap);

    return AnimatedPositioned(
      key: ValueKey('racktile-$id'),
      duration: theme.animated
          ? const Duration(milliseconds: 300)
          : Duration.zero,
      curve: Curves.easeOutCubic,
      left: left,
      top: 0,
      width: size,
      height: size,
      child: _slot(theme, rackIndex, id, entry.value, size),
    );
  }

  Widget _slot(
      GameTheme theme, int rackIndex, int id, Tile tile, double size) {
    final suggested = game.suggestedIds.contains(id);

    if (exchangeMode) {
      final selected = selectedForExchange.contains(rackIndex);
      return GestureDetector(
        onTap: () => onExchangeToggle(rackIndex),
        child: Opacity(
          opacity: selected ? 0.5 : 1.0,
          child: TileWidget(tile: tile, size: size, highlighted: selected),
        ),
      );
    }

    Widget tileWidget =
        TileWidget(tile: tile, size: size, highlighted: suggested);

    // Suggested tiles enlarge briefly (then settle) as they slide into place.
    if (theme.animated && suggested) {
      tileWidget = TweenAnimationBuilder<double>(
        key: ValueKey('pulse-$id-${game.suggestSerial}'),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 520),
        builder: (context, t, child) {
          final scale = 1 + 0.3 * sin(t * pi); // up then back to 1
          return Transform.scale(scale: scale, child: child);
        },
        child: tileWidget,
      );
    }

    final data = RackDragData(rackIndex, tile);
    return DragTarget<RackDragData>(
      onWillAcceptWithDetails: (d) => d.data.rackIndex != rackIndex,
      onAcceptWithDetails: (d) => game.reorderRack(d.data.rackIndex, rackIndex),
      builder: (context, candidate, rejected) {
        final hovering = candidate.isNotEmpty;
        return Draggable<RackDragData>(
          data: data,
          feedback: _DragFeedback(tile: tile, size: size, theme: theme),
          childWhenDragging: Opacity(
            opacity: 0.25,
            child: TileWidget(tile: tile, size: size),
          ),
          child: AnimatedScale(
            scale: hovering ? 1.08 : 1.0,
            duration: const Duration(milliseconds: 120),
            child: tileWidget,
          ),
        );
      },
    );
  }
}

/// The widget shown under the finger while dragging: it pops up larger with a
/// stronger shadow, so picking up a tile feels tactile.
class _DragFeedback extends StatelessWidget {
  final Tile tile;
  final double size;
  final GameTheme theme;

  const _DragFeedback(
      {required this.tile, required this.size, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1.0, end: 1.22),
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: Transform.rotate(angle: -0.04, child: child),
          );
        },
        child: GameThemeScope(
          theme: theme,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size * 0.14),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x77000000),
                    blurRadius: 10,
                    offset: Offset(0, 6)),
              ],
            ),
            child: TileWidget(tile: tile, size: size, highlighted: true),
          ),
        ),
      ),
    );
  }
}
