import 'package:flutter/material.dart';

import '../models/tile.dart';
import '../state/game_state.dart';
import 'board_widget.dart';
import 'tile_widget.dart';

/// The current player's rack of draggable tiles. Also acts as a drop target so
/// pending tiles can be dragged back off the board.
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
    const tileSize = 48.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF6D4C41),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Color(0x44000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          for (final entry in tiles)
            _buildRackTile(entry.key, entry.value, tileSize),
        ],
      ),
    );
  }

  Widget _buildRackTile(int rackIndex, Tile tile, double size) {
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
    return Draggable<RackDragData>(
      data: data,
      feedback: Material(
        color: Colors.transparent,
        child: TileWidget(tile: tile, size: size, highlighted: true),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: TileWidget(tile: tile, size: size),
      ),
      child: TileWidget(tile: tile, size: size),
    );
  }
}
