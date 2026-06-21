import 'package:flutter/material.dart';

import '../models/tile.dart';

/// Visual representation of a single Scrabble tile.
class TileWidget extends StatelessWidget {
  final Tile tile;
  final double size;
  final bool highlighted;

  const TileWidget({
    super.key,
    required this.tile,
    this.size = 40,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final display = tile.isUnassignedBlank ? '' : tile.letter;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF6E2B3), Color(0xFFE9C883)],
        ),
        borderRadius: BorderRadius.circular(size * 0.12),
        border: Border.all(
          color: highlighted ? Colors.orange.shade700 : const Color(0xFFB5965A),
          width: highlighted ? 2 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 2,
            offset: Offset(1, 1),
          ),
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              display,
              style: TextStyle(
                fontSize: size * 0.5,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF3A2E14),
              ),
            ),
          ),
          if (!tile.isBlank || tile.letter.isNotEmpty)
            Positioned(
              right: size * 0.08,
              bottom: size * 0.04,
              child: Text(
                '${tile.value}',
                style: TextStyle(
                  fontSize: size * 0.22,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF5A4A22),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
