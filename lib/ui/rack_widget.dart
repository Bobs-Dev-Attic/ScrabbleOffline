import 'package:flutter/material.dart';

import '../models/player.dart';
import '../models/tile.dart';
import '../state/game_state.dart';
import 'board_widget.dart';
import 'tile_widget.dart';

/// The current player's rack. Tiles can be dragged onto the board, dragged onto
/// each other to reorder, or tapped to select for exchange. All seven tiles are
/// sized to fit on a single row.
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF6D4C41),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Color(0x44000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Divide the row into 7 equal slots so all tiles always fit, with a
          // little spacing taken from each slot. Sizing for the full rack keeps
          // tiles a stable size as they are placed.
          final slot = constraints.maxWidth / kRackCapacity;
          final spacing = (slot * 0.12).clamp(2.0, 6.0);
          final size = (slot - spacing).clamp(20.0, 60.0);
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) SizedBox(width: spacing),
                _slot(tiles[i].key, tiles[i].value, size),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _slot(int rackIndex, Tile tile, double size) {
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

    final data = RackDragData(rackIndex, tile);
    return DragTarget<RackDragData>(
      onWillAcceptWithDetails: (d) => d.data.rackIndex != rackIndex,
      onAcceptWithDetails: (d) => game.reorderRack(d.data.rackIndex, rackIndex),
      builder: (context, candidate, rejected) {
        final hovering = candidate.isNotEmpty;
        return Draggable<RackDragData>(
          data: data,
          feedback: Material(
            color: Colors.transparent,
            child: TileWidget(tile: tile, size: size * 1.1, highlighted: true),
          ),
          childWhenDragging: Opacity(
            opacity: 0.3,
            child: TileWidget(tile: tile, size: size),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size * 0.14),
              border: Border.all(
                color: hovering ? Colors.amberAccent : Colors.transparent,
                width: 2,
              ),
            ),
            child: TileWidget(tile: tile, size: size),
          ),
        );
      },
    );
  }
}
